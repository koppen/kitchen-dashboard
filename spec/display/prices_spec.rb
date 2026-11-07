# frozen_string_literal: true

RSpec.describe KitchenDashboard::Display::Prices do
  subject(:chart) { described_class.new(now:, prices:) }

  let(:now) { Time.new(2026, 11, 7, 14, 20) }
  let(:start) { Time.new(2026, 11, 7, 14).to_i }
  # 14:00 2,46 kr, then 0,80 / 1,50 / 3,60 / -0,10, published until 23:00
  let(:prices) do
    values = [2.46, 0.8, 1.5, 3.6, -0.1] + [2.0] * 5
    values.each_with_index.map { |p, i| {t: start + i * 3600, p:} } + [{t: start - 3600, p: 9.0}]
  end

  it "shows the current price" do
    expect(chart.current).to eq("2,46")
    expect(described_class.new(now:, prices: []).current).to be_nil
  end

  it "scales 0..3 kr to the chart height, cutting off dearer hours" do
    bars = chart.bars
    expect(bars.size).to eq(24)
    expect(bars.first(5).map(&:height)).to eq([2.46 / 3, 0.8 / 3, 0.5, 1.0, 0.0])
    expect(bars.first(5).map(&:clipped)).to eq([false, false, false, true, false])
  end

  it "highlights hours below 1 kr and marks the current hour" do
    expect(chart.bars.first(5).map(&:cheap)).to eq([false, true, false, false, true])
    expect(chart.bars.compact.map(&:now)).to eq([true] + [false] * 9)
  end

  it "leaves slots empty where prices aren't published yet" do
    expect(chart.bars.compact.size).to eq(10)
    expect(chart.bars.last).to be_nil
  end

  it "labels the current hour and every sixth clock hour" do
    labels = chart.labels
    expect(labels.size).to eq(24)
    expect(labels.each_with_index.select { |l, _| l }).to eq([["Nu", 0], ["18", 4], ["00", 10], ["06", 16], ["12", 22]])
  end

  it "has reference lines at 2 kr and, green, at 1 kr" do
    expect(chart.lines).to eq([{value: "2", bottom: 2 / 3.0, good: false}, {value: "1", bottom: 1 / 3.0, good: true}])
  end
end
