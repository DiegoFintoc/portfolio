# typed: false

RSpec::Matchers.define_negated_matcher :avoid_changing, :change

RSpec.describe Portfolio do
  let(:portfolio) { described_class.new }
  let(:low_stock) { Stock.new(stock_id: 'low') }
  let(:high_stock) { Stock.new(stock_id: 'high') }

  describe 'unit tests' do
    describe '#calculate_' do
      def perform
        portfolio.calculate_rebalance
      end

      let(:target) do
        [
          Portfolio::StockTarget.new(stock: low_stock, percentage: low_percentage),
          Portfolio::StockTarget.new(stock: high_stock, percentage: high_percentage)
        ]
      end
      let(:low_percentage) { 40 }
      let(:high_percentage) { 60 }

      before do
        portfolio.reallocate_stocks_target(target:)
      end

      context 'when portfolio has no stocks' do
        # portfolio_value = $0
        # low => 40% => $0 => target: $0 / $50 = 0 => 0
        # high => 60% => $0 => target: $0 / $50 = 0 => 0

        it 'returns 0 stocks to buy and 0 stocks to sell' do
          result = perform
          expect(result.to_buy.size).to eq(0)
          expect(result.to_sell.size).to eq(0)
        end
      end

      context 'when portfolio has stocks but none of the requested ones' do
        let(:first_stock_share) { 3 }
        let(:second_stock_share) { 2 }
        let(:stock) { Stock.new(stock_id: 'stock') }

        let(:other_stock_share) { 4 }
        let(:other_stock) { Stock.new(stock_id: 'other_stock') }

        before do
          portfolio.add_stock(stock:, share: first_stock_share)
          portfolio.add_stock(stock:, share: second_stock_share)
          portfolio.add_stock(stock: other_stock, share: other_stock_share)
        end

        # portfolio_value = (3+2) * $50 + 4 * $50 = $450
        # low => 40% => $180 => target: $180 / $50 = 0 => 4
        # high => 60% => $270 => target: $270 / $50 = 0 => 5

        it 'returns all stocks to buy and all stocks to sell' do
          result = perform
          expect(result.to_sell.size).to eq(2)
          expect(result.to_sell['stock']).to eq(first_stock_share + second_stock_share)
          expect(result.to_sell['other_stock']).to eq(other_stock_share)

          expect(result.to_buy.size).to eq(2)
          expect(result.to_buy['low']).to eq(4)
          expect(result.to_buy['high']).to eq(5)
        end
      end

      context 'when portfolio has all requested stocks' do
        let(:first_low_stock_share) { 20 }
        let(:second_low_stock_share) { 30 }

        let(:high_stock_share) { 50 }

        before do
          allow(low_stock).to receive(:current_price).and_return(low_stock_current_price)
          allow(high_stock).to receive(:current_price).and_return(high_stock_current_price)

          portfolio.add_stock(stock: low_stock, share: first_low_stock_share)
          portfolio.add_stock(stock: low_stock, share: second_low_stock_share)
          portfolio.add_stock(stock: high_stock, share: high_stock_share)
        end

        context 'when the current price is the same' do
          let(:low_stock_current_price) { 50 }
          let(:high_stock_current_price) { 50 }

          # portfolio_value = (20+30) * $50 + 50 * $50 = $5000
          # low => 40% => $2000 => target: $2000 / $50 = 40 => -10
          # high => 60% => $3000 => target: $3000 / $50 = 60 => +10

          it 'returns all stocks to buy and all stocks to sell' do
            result = perform
            expect(result.to_sell.size).to eq(1)
            expect(result.to_sell['low']).to eq(10)

            expect(result.to_buy.size).to eq(1)
            expect(result.to_buy['high']).to eq(10)
          end
        end

        context 'when the current price is different' do
          let(:low_stock_current_price) { 50 }
          let(:high_stock_current_price) { 100 }

          # portfolio_value = (20+30) * $50 + 50 * $100 = $7500
          # low => 40% => $3000 => target: $3000 / $50 = 60 => +10
          # high => 60% => $4500 => target: $4500 / $100 = 45 => -5

          it 'returns all stocks to buy and all stocks to sell' do
            result = perform
            expect(result.to_sell.size).to eq(1)
            expect(result.to_sell['high']).to eq(5)

            expect(result.to_buy.size).to eq(1)
            expect(result.to_buy['low']).to eq(10)
          end
        end

        context 'when share to rebalance has floating values' do
          let(:first_low_stock_share) { 1 }
          let(:second_low_stock_share) { 1 }
          let(:low_stock_current_price) { 50 }

          let(:high_stock_share) { 1 }
          let(:high_stock_current_price) { 50 }

          # portfolio_value = (1+1) * $50 + 1 * $50 = $150
          # low => 40% => $60 => target: $60 / $50 = 1.2 ~ 1 => -1
          # high => 60% => $90 => target: $90 / $50 = 1.8 ~ 2 => +1

          it 'returns stocks to buy and to sell without increasing portfolio value' do
            result = perform
            expect(result.to_sell.size).to eq(1)
            expect(result.to_sell['low']).to eq(1)

            expect(result.to_buy.size).to eq(1)
            expect(result.to_buy['high']).to eq(1)
          end
        end

        context 'when share to rebalance exceeds the portfolio value' do
          let(:first_low_stock_share) { 1 }
          let(:second_low_stock_share) { 1 }
          let(:low_stock_current_price) { 10 }

          let(:high_stock_share) { 1 }
          let(:high_stock_current_price) { 5 }

          let(:low_percentage) { 25 }
          let(:high_percentage) { 75 }

          # portfolio_value = (1+1) * $10 + 1 * $5 = $25
          # low => 25% => $6.25 => target: $6.25 / $10 = 0.625 ~ 1 => -1
          # high => 70% => $18.75 => target: $18.75 / $5 = 3.75 ~ 4 => +3
          # however, new portfolio value would be (1+1-1) * $10 + (1+3) * $5 = $30 > $25
          # so buy orders should be reduced

          it 'returns stocks to buy and to sell without increasing portfolio value' do
            result = perform
            expect(result.to_sell.size).to eq(1)
            expect(result.to_sell['low']).to eq(1)

            expect(result.to_buy.size).to eq(1)
            expect(result.to_buy['high']).to eq(2)
          end
        end
      end

      context 'when portfolio has a mix of requested, missing, and unrequested stocks' do
        let(:first_low_stock_share) { 20 }
        let(:second_low_stock_share) { 30 }
        let(:low_stock_current_price) { 50 }

        let(:high_stock_share) { 60 }
        let(:high_stock_current_price) { 70 }

        let(:other_stock_share) { 15 }
        let(:other_stock_current_price) { 100 }
        let(:other_stock) { Stock.new(stock_id: 'other_stock') }

        before do
          allow(low_stock).to receive(:current_price).and_return(low_stock_current_price)
          allow(high_stock).to receive(:current_price).and_return(high_stock_current_price)
          allow(other_stock).to receive(:current_price).and_return(other_stock_current_price)

          portfolio.add_stock(stock: low_stock, share: first_low_stock_share)
          portfolio.add_stock(stock: low_stock, share: second_low_stock_share)
          portfolio.add_stock(stock: other_stock, share: other_stock_share)
        end

        # portfolio_value = (20+30) * $50 + 15 * $100 = $4000
        # low => 40% => $1600 => target: $1600 / $50 = 32 => -18
        # high => 60% => $2400 => target: $2400 / $70 = ~34 => +34

        it 'returns all stocks to buy and all stocks to sell' do
          result = perform
          expect(result.to_sell.size).to eq(2)
          expect(result.to_sell['low']).to eq(18)
          expect(result.to_sell['other_stock']).to eq(other_stock_share)

          expect(result.to_buy.size).to eq(1)
          expect(result.to_buy['high']).to eq(34)
        end
      end
    end

    describe '#reallocate_stocks_target' do
      def perform
        portfolio.reallocate_stocks_target(target:)
      end

      let(:low_percentage) { 40 }
      let(:high_percentage) { 60 }
      let(:target) do
        [
          Portfolio::StockTarget.new(stock: low_stock, percentage: low_percentage),
          Portfolio::StockTarget.new(stock: high_stock, percentage: high_percentage)
        ]
      end

      context 'when target is valid' do
        it 'reallocates stocks target' do
          perform
          low_stock_allocated = portfolio.instance_variable_get(:@allocated_stocks_target)['low']
          expect(low_stock_allocated.stock).to eq(low_stock)
          expect(low_stock_allocated.percentage).to eq(low_percentage)

          high_stock_allocated = portfolio.instance_variable_get(:@allocated_stocks_target)['high']
          expect(high_stock_allocated.stock).to eq(high_stock)
          expect(high_stock_allocated.percentage).to eq(high_percentage)
        end
      end

      context 'when target has duplicate stock names' do
        let(:target) do
          [
            Portfolio::StockTarget.new(stock: low_stock, percentage: 40),
            Portfolio::StockTarget.new(stock: low_stock, percentage: 60)
          ]
        end

        it 'raises an error' do
          expect { perform }.to raise_error('duplicate targets for the same stock')
        end
      end

      context 'when target has a zero percentage' do
        let(:low_percentage) { 0 }
        let(:high_percentage) { 100 }

        it 'raises an error' do
          expect { perform }.to raise_error('stock low percentage must be positive')
        end
      end

      context 'when target has a negative percentage' do
        let(:low_percentage) { -1 }
        let(:high_percentage) { 101 }

        it 'raises an error' do
          expect { perform }.to raise_error('stock low percentage must be positive')
        end
      end

      context 'when target sums to less than 100' do
        let(:low_percentage) { 10 }
        let(:high_percentage) { 20 }

        it 'raises an error' do
          expect { perform }.to raise_error('stock percentages do not sum 100')
        end
      end

      context 'when target sums to more than 100' do
        let(:low_percentage) { 60 }
        let(:high_percentage) { 80 }

        it 'raises an error' do
          expect { perform }.to raise_error('stock percentages do not sum 100')
        end
      end
    end

    describe '#add_stock' do
      def perform
        portfolio.add_stock(stock:, share:)
      end

      let(:stock) { Stock.new(stock_id: 'stock') }
      let(:share) { 5 }

      context 'when portfolio is empty' do
        it 'adds stock correctly' do
          expect { perform }
            .to change { portfolio.instance_variable_get(:@portfolio_stocks).size }
            .from(0).to(1)
            .and change { portfolio.instance_variable_get(:@portfolio_stocks)['stock']&.share }
            .from(nil).to(share)
        end
      end

      context 'when portfolio already has the stock' do
        before do
          perform
        end

        it 'adds stock correctly' do
          expect { perform }
            .to change { portfolio.instance_variable_get(:@portfolio_stocks)['stock'].share }
            .from(share).to(2 * share)
            .and (avoid_changing { portfolio.instance_variable_get(:@portfolio_stocks).size })
        end
      end

      context 'when portfolio has other stocks' do
        before do
          other_stock = Stock.new(stock_id: 'other_stock')
          portfolio.add_stock(stock: other_stock, share: 1)
        end

        it 'adds stock correctly' do
          expect { perform }
            .to change { portfolio.instance_variable_get(:@portfolio_stocks).size }
            .from(1).to(2)
            .and change { portfolio.instance_variable_get(:@portfolio_stocks)['stock']&.share }
            .from(nil).to(share)
            .and (avoid_changing do
              portfolio.instance_variable_get(:@portfolio_stocks)['other_stock'].share
            end)
        end
      end

      context 'when share is 0' do
        let(:share) { 0 }

        it 'raises an error' do
          expect { perform }.to raise_error('share must be positive')
        end
      end

      context 'when share is negative' do
        let(:share) { -1 }

        it 'raises an error' do
          expect { perform }.to raise_error('share must be positive')
        end
      end
    end
  end
end
