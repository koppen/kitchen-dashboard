# frozen_string_literal: true

RSpec.describe KitchenDashboard::Display::Timeline do
  subject(:timeline) do
    described_class.new(now:, height: KitchenDashboard::Display::Layout.timeline_height(alerts: 2, all_day: true),
      events: Fixtures.events(now), prices: Fixtures.prices(now))
  end

  let(:now) { Time.new(2026, 11, 7, 14, 20) }

  it "fits whole hours into the free height" do
    expect(timeline.rows).to eq(13)
    expect(timeline.hours.first(3)).to eq(%w[14 15 16])
    expect(timeline.hours.last).to eq("02")
  end

  it "marks midnight" do
    expect(timeline.midnight).to be_within(1e-9).of(10 * 4.2)
  end

  it "lays out events in columns and inverts the current one" do
    events = timeline.events
    expect(events.map { [it.title, it.col, it.cols, it.now] }).to eq([
      ["Football", 0, 1, true],
      ["Dinner at Mormor", 0, 2, false],
      ["Book club", 1, 2, false]
    ])
    football = events.first
    expect(football.top).to be_within(1e-9).of(0.2) # clipped to the window start
    expect(football.sub).to be_nil                  # too short for a second line
    expect(events[1].sub).to eq("til 18:02")
  end

  it "colours the cheapest 4 consecutive hours and the expensive ones" do
    prices = timeline.prices
    expect(prices.size).to eq(13)
    cheap = prices.each_index.select { prices[it].kind == :cheap }
    expect(cheap.size).to eq(4)
    expect(cheap.each_cons(2).all? { |a, b| b == a + 1 }).to be(true)
    expect(prices.map(&:kind)).to include(:dear)
    expect(prices.first.value).to match(/\A\d+,\d\d\z/) # Danish decimal comma
    expect(prices.map(&:width).max).to be_within(1e-9).of(described_class::BAR_MAX)
    expect(prices.map { [it.width >= described_class::LABEL_MIN, it.inside] }).to all(satisfy { |fits, inside| fits == inside })
    expect(prices.map(&:inside)).to include(true, false) # the mock has bars too short for their label
  end

  it "marks events whose title starts with ? as tentative" do
    events = [Fixtures.event(now, 1, 2, "? Pigeaften", "T"), Fixtures.event(now, 3, 4, "Hvad nu?", "J")]
    timeline = described_class.new(now:, height: 50, events:, prices: [])
    expect(timeline.events.map { [it.title, it.tentative] }).to eq([["? Pigeaften", true], ["Hvad nu?", false]])
  end

  it "lists all-day events for today" do
    expect(described_class.all_day(Fixtures.events(now), now).map { it[:title] }).to eq(["School trip"])
  end
end
