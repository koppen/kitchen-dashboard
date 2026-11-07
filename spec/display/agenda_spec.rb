# frozen_string_literal: true

RSpec.describe KitchenDashboard::Display::Agenda do
  let(:now) { Time.new(2026, 11, 7, 14, 20) }

  def agenda(events, height: 40) = described_class.new(now:, height:, events:)
  def titles(agenda) = agenda.items.map { it.day? ? it.label : it.title }

  it "lists upcoming and current events in start order, skipping finished and all-day ones" do
    list = agenda(Fixtures.events(now))
    expect(titles(list)).to eq(["Football", "Dinner at Mormor", "Book club"])
    football, dinner = list.items
    expect(football).to have_attributes(time: "13:50", until: "til 15:20", sub: "Hallen", now: true)
    expect(dinner).to have_attributes(time: "15:32", until: "til 18:02", sub: nil, now: false)
    expect(list.more).to eq(0)
  end

  it "puts a divider before each later day" do
    events = [Fixtures.event(now, 1, 2, "Late", "J"), Fixtures.event(now, 11, 12, "Early", "T"),
      Fixtures.event(now, 13, 14, "Also tomorrow", "T"), Fixtures.event(now, 50, 51, "Monday", "Ma")]
    expect(titles(agenda(events))).to eq(["Late", "I MORGEN", "Early", "Also tomorrow", "MANDAG 9. NOV", "Monday"])
  end

  it "lists future all-day events as rows, today's not" do
    events = [Fixtures.events(now).last, # School trip, today: a chip
      {title: "Bowling", location: "", start: "2026-11-10", end: "2026-11-11", all_day: true, who: []}]
    list = agenda(events)
    expect(titles(list)).to eq(["TIRSDAG 10. NOV", "Bowling"])
    expect(list.items.last).to have_attributes(time: nil, until: "hele dagen", now: false)
  end

  it "shows as many as fit and counts the rest" do
    events = Array.new(10) { Fixtures.event(now, it + 1, it + 2, "E#{it}", "J") }
    # 5.2 per row + 0.6 gaps, keeping 2.6 for "+ N flere": 4 rows need 4 * 5.2 + 3 * 0.6 + 2.6 = 25.2
    list = agenda(events, height: 25.2)
    expect(titles(list)).to eq(%w[E0 E1 E2 E3])
    expect(list.more).to eq(6)
  end

  it "needs no room for the more-line after the last event" do
    events = Array.new(2) { Fixtures.event(now, it + 1, it + 2, "E#{it}", "J") }
    expect(agenda(events, height: 2 * 5.2 + 0.6).more).to eq(0)
  end

  it "marks events whose title starts with ? as tentative" do
    events = [Fixtures.event(now, 1, 2, "? Pigeaften", "T"), Fixtures.event(now, 3, 4, "Hvad nu?", "J")]
    expect(agenda(events).items.map(&:tentative)).to eq([true, false])
  end

  it "lists all-day events for today" do
    expect(described_class.all_day(Fixtures.events(now), now).map { it[:title] }).to eq(["School trip"])
  end
end
