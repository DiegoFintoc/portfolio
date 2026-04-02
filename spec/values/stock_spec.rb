# typed: false

RSpec.describe Stock do
  let(:stock) { described_class.new(stock_id:) }
  let(:stock_id) { 'some id' }

  describe 'unit tests' do
    describe '#stock_id' do
      it 'returns the initial stock_id' do
        expect(stock.stock_id).to eq(stock_id)
      end
    end

    describe '#current_price' do
      it 'returns the current price' do
        expect(stock.current_price).to eq(50)
      end
    end
  end
end
