# frozen_string_literal: true

RSpec.describe KitchenDashboard::Display::Agenda do
  let(:now) { Time.new(2026, 11, 7, 14, 20) }

  def agenda(events, height: 40) = described_class.new(now:, height:, events:)
  def rows(agenda) = agenda.items.flat_map { it.block? ? it.cells.map(&:item) : [it] }
  def name(item) = item.day? ? item.label : item.title
  # [title or label, row, rows, lane, lanes] per cell
  def grid(block) = block.cells.map { [name(it.item), it.row, it.rows, it.lane, it.lanes] }
  def titles(agenda) = rows(agenda).map { name(it) }

  it "lists upcoming and current events in start order, skipping finished and all-day ones" do
    list = agenda(Fixtures.events(now))
    expect(titles(list)).to eq(["Football", "Dinner at Mormor", "Book club"])
    football, dinner = rows(list)
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

  it "puts overlapping events next to each other" do
    football, block = agenda(Fixtures.events(now)).items
    expect(football.title).to eq("Football")
    expect([block.columns, block.heights]).to eq([2, [5.2]])
    expect(grid(block)).to eq([["Dinner at Mormor", 0, 1, 0, 1], ["Book club", 0, 1, 1, 1]])
  end

  it "shares a row only with events that are all still on, else starts a row in a free lane" do
    events = [Fixtures.event(now, 1, 4, "A", "J"), Fixtures.event(now, 1.5, 2, "B", "T"), Fixtures.event(now, 2.5, 3.5, "C", "M")]
    block = agenda(events).items.first
    expect(grid(block)).to eq([["A", 0, 2, 0, 1], ["B", 0, 1, 1, 1], ["C", 1, 1, 1, 1]])
  end

  it "uses as many lanes as events on at once" do
    events = [Fixtures.event(now, 1, 4, "A", "J"), Fixtures.event(now, 1.5, 3, "B", "T"), Fixtures.event(now, 2, 2.5, "C", "M")]
    expect(agenda(events).items.first.columns).to eq(3)
  end

  it "reaches an event running into the next day past the divider, which goes beside it" do
    events = [Fixtures.event(now, 1, 22, "Overnight", "T"), Fixtures.event(now, 4, 5, "Parkour", "Ma"),
      Fixtures.event(now, 19, 20, "Breakfast", "J"), Fixtures.event(now, 23, 24, "After", "J")]
    block, after = agenda(events).items
    expect(block.heights).to eq([5.2, 2.0, 5.2])
    expect(grid(block)).to eq([["Overnight", 0, 3, 0, 1], ["Parkour", 0, 1, 1, 1], ["I MORGEN", 1, 1, 1, 1], ["Breakfast", 2, 1, 1, 1]])
    expect(block.cells.first.item.until).to eq("til søn 12:20")
    expect(after.title).to eq("After")
  end

  it "makes room beside an event running into the next day for the divider, even with nothing else on" do
    block, after = agenda([Fixtures.event(now, 1, 22, "Overnight", "T"), Fixtures.event(now, 23, 24, "After", "J")]).items
    expect([block.columns, grid(block)]).to eq([2, [["Overnight", 0, 2, 0, 1], ["I MORGEN", 1, 1, 1, 1]]])
    expect(after.title).to eq("After")
  end

  it "puts overlapping multi-day events next to each other" do
    events = [Fixtures.event(now, 18, 45, "A", "T"), Fixtures.event(now, 20, 70, "B", "J")] # Sun 08:20, Sun 10:20
    _divider, block = agenda(events).items
    expect(grid(block)).to eq([["A", 0, 1, 0, 1], ["B", 0, 1, 1, 1]])
  end

  it "fits an event sharing a row in no extra height" do
    events = [Fixtures.event(now, 1, 3, "Long", "J"), Fixtures.event(now, 2, 2.5, "Short", "T")]
    # one row, plus room for "+ N flere" while placing the first
    expect(agenda(events, height: 5.2 + 2.6)).to have_attributes(more: 0, items: [an_instance_of(described_class::Block)])
  end

  it "shows only the end of an event that started before today" do
    event = Fixtures.event(now, -20, 40, "Trip", "J") # Fri 18:20 to Mon 06:20
    expect(agenda([event]).items.first).to have_attributes(time: nil, until: "til man 06:20")
  end

  it "does not treat events ending at midnight as multi-day" do
    event = Fixtures.event(Time.new(2026, 11, 7, 22), 0, 2, "Late", "J")
    expect(agenda([event]).items.first.until).to eq("til 00:00")
  end

  it "marks events whose title starts with ? as tentative" do
    events = [Fixtures.event(now, 1, 2, "? Pigeaften", "T"), Fixtures.event(now, 3, 4, "Hvad nu?", "J")]
    expect(rows(agenda(events)).map(&:tentative)).to eq([true, false])
  end

  it "lists all-day events for today" do
    expect(described_class.all_day(Fixtures.events(now), now).map { it[:title] }).to eq(["School trip"])
  end
end
