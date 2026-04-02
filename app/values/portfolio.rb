# typed: strict

class Portfolio
  extend T::Sig

  class StockTarget < T::Struct
    const :stock, Stock
    const :percentage, Integer
  end

  class RebalanceResult < T::Struct
    const :to_sell, T::Hash[String, Integer]
    const :to_buy, T::Hash[String, Integer]
  end

  sig { void }
  def initialize
    @portfolio_stocks = T.let({}, T::Hash[String, StockShare])
    @allocated_stocks_target = T.let({}, T::Hash[String, StockTarget])
  end

  sig { returns(RebalanceResult) }
  def calculate_rebalance # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    result = RebalanceResult.new(to_sell: {}, to_buy: {})
    portfolio_snapshot = freeze_portfolio_values

    total_value_to_sell = 0
    total_value_to_buy = 0

    # sell owned stocks not present in the target
    (@portfolio_stocks.keys - @allocated_stocks_target.keys).each do |name|
      share = portfolio_snapshot.frozen_stock_shares.fetch(name)
      price = portfolio_snapshot.frozen_stock_prices.fetch(name)
      result.to_sell[name] = share
      total_value_to_sell += share * price
    end

    # calculate how many shares to buy or sell to reach the target
    @allocated_stocks_target.each do |name, stock_target|
      frozen_price = portfolio_snapshot.frozen_stock_prices.fetch(name)
      current_portfolio_share = portfolio_snapshot.frozen_stock_shares.fetch(name)
      target_value = (portfolio_snapshot.frozen_total_value * stock_target.percentage).to_f / 100
      share = (target_value / frozen_price).round
      diff = share - current_portfolio_share
      next if diff.zero?

      if diff.positive?
        result.to_buy[name] = diff
        total_value_to_buy += diff * frozen_price
      else
        result.to_sell[name] = -diff
        total_value_to_sell += -diff * frozen_price
      end
    end

    # changes should not require more capital than portfolio value
    if total_value_to_buy > total_value_to_sell
      result.to_buy.each_key do |name|
        result.to_buy[name] = result.to_buy.fetch(name) - 1
        total_value_to_buy -= portfolio_snapshot.frozen_stock_prices.fetch(name)
        break if total_value_to_buy <= total_value_to_sell
      end

      result.to_buy.delete_if { |_, share| share.zero? }
    end

    result
  end

  sig { params(target: T::Array[StockTarget]).void }
  def reallocate_stocks_target(target:) # rubocop:disable Metrics/CyclomaticComplexity
    if target.map { |stock_target| stock_target.stock.stock_id }.uniq.size != target.size
      raise 'duplicate targets for the same stock'
    end

    target.each do |stock_target|
      unless stock_target.percentage.positive?
        raise "stock #{stock_target.stock.stock_id} percentage must be positive"
      end
    end

    raise 'stock percentages do not sum 100' if target.sum(&:percentage) != 100

    @allocated_stocks_target =
      target.to_h { |stock_target| [stock_target.stock.stock_id, stock_target] }
  end

  sig { params(stock: Stock, share: Integer).void }
  def add_stock(stock:, share:)
    raise 'share must be positive' unless share.positive?

    if @portfolio_stocks.has_key?(stock.stock_id)
      @portfolio_stocks.fetch(stock.stock_id).share += share
    else
      @portfolio_stocks[stock.stock_id] = StockShare.new(stock:, share:)
    end
  end

  private

  class StockShare < T::Struct
    const :stock, Stock
    prop :share, Integer
  end
  private_constant :StockShare

  class PortfolioSnapshot < T::Struct
    const :frozen_stock_prices, T::Hash[String, Integer]
    const :frozen_stock_shares, T::Hash[String, Integer]
    const :frozen_total_value, Integer
  end
  private_constant :PortfolioSnapshot

  sig { returns(PortfolioSnapshot) }
  def freeze_portfolio_values # rubocop:disable Metrics/AbcSize
    frozen_stock_prices = T.let({}, T::Hash[String, Integer])
    frozen_stock_shares = T.let({}, T::Hash[String, Integer])
    frozen_total_value = 0

    @portfolio_stocks.each do |name, portfolio_stocks|
      current_price = portfolio_stocks.stock.current_price
      frozen_stock_prices[name] = current_price

      stock_share = portfolio_stocks.share
      frozen_stock_shares[name] = stock_share

      frozen_total_value += stock_share * current_price
    end

    (@allocated_stocks_target.keys - @portfolio_stocks.keys).each do |name|
      frozen_stock_prices[name] = @allocated_stocks_target.fetch(name).stock.current_price
      frozen_stock_shares[name] = 0
    end

    PortfolioSnapshot.new(frozen_stock_prices:, frozen_stock_shares:, frozen_total_value:)
  end
end
