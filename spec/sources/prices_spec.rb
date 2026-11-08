# frozen_string_literal: true

RSpec.describe KitchenDashboard::Sources::Prices do
  subject(:source) { described_class.new(http:, cache:, tariffs:) }

  let(:cache) { KitchenDashboard::Cache.new }
  let(:tariffs) { double(at: 0.2) }
  let(:day) { Date.today.to_time }
  # 72 hours of quarter-hour records, UTC stamps without a trailing Z
  let(:records) do
    (0...72).flat_map do |h|
      (0...4).map do |q|
        t = (day + h * 3600 + q * 900).utc
        {"TimeUTC" => t.strftime("%Y-%m-%dT%H:%M:%S"), "PriceArea" => "DK2", "DayAheadPriceDKK" => 400 + h * 10 + q * 20}
      end
    end
  end
  let(:http) do
    FakeHttp.new do |_, url|
      expect(url).to include("start=#{Date.today.iso8601}", "end=#{(Date.today + 3).iso8601}", KitchenDashboard::Config::PRICE_AREA)
      {"records" => records}
    end
  end

  it "averages quarter hours to hourly kr/kWh and adds markup, tariffs and VAT" do
    stub_const("KitchenDashboard::Config::MARKUP", ->(t) { 0.064 })
    prices = source.call
    expect(prices.size).to eq(72)
    expect(prices.first[:t]).to eq(day.to_i)
    expect(prices.first[:p]).to be_within(1e-9).of(((400 + 30) / 1000.0 + 0.064 + 0.2) * 1.25)
    expect(prices[5][:p]).to be_within(1e-9).of(((450 + 30) / 1000.0 + 0.064 + 0.2) * 1.25)
    expect(tariffs).to have_received(:at).with(Time.at(day.to_i + 5 * 3600))
  end

  it "serves stale data when the upstream fails" do
    first = source.call
    allow(cache).to receive(:clock).and_return(1e12) # far in the future: cache expired
    failing = described_class.new(http: FakeHttp.new { raise "down" }, cache:, tariffs:)
    expect(failing.call).to eq(first)
    expect(failing.stale?).to be(true)
  end

  it "raises when the upstream fails and nothing is cached" do
    expect { described_class.new(http: FakeHttp.new { raise "down" }, cache:, tariffs:).call }.to raise_error("down")
  end
end
