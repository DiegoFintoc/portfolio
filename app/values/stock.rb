# typed: strict

class Stock
  extend T::Sig

  sig { returns(String) }
  attr_reader :stock_id

  MOCK_CURRENT_PRICE = 50

  sig { params(stock_id: String).void }
  def initialize(stock_id:)
    @stock_id = stock_id
  end

  sig { returns(Integer) }
  def current_price
    MOCK_CURRENT_PRICE
  end
end
