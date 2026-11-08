# auto_register: false
# frozen_string_literal: true

require "time"

module KitchenDashboard
  module Display
    # The next events as a compact list, one fixed-height row each and a divider per day after today,
    # as many as fit in the free height. Today's all-day events are chips above it instead.
    # Heights mirror the CSS in the layout.
    #
    # Overlapping timed events sit next to each other, like columns in a calendar: they go in a Block,
    # a grid of rows (event rows and day dividers) and columns (lanes). An event starting while all
    # events in the row above are still on shares that row; otherwise it gets a new row, in the first
    # lane free of events still on. Each event's card reaches down to the last row starting before it
    # ends, so an event running into a later day reaches past that day's divider, which then only uses
    # the lanes beside it. An event ending on a later day shows its end day ("til tor 11:00").
    class Agenda
      ROW = 5.2     # rem per event row
      GAP = 0.6     # rem between rows
      DIVIDER = 2.0 # rem, day divider ("I MORGEN", "MANDAG 9. NOV")
      MORE = 2.0    # rem, "+ N flere" line

      WEEKDAYS = %w[SØNDAG MANDAG TIRSDAG ONSDAG TORSDAG FREDAG LØRDAG].freeze
      MONTHS = %w[JAN FEB MAR APR MAJ JUN JUL AUG SEP OKT NOV DEC].freeze
      SHORT_WEEKDAYS = %w[søn man tir ons tor fre lør].freeze

      # time: nil for all-day events (until then reads "hele dagen") and ones that started before today
      Event = Data.define(:time, :until, :title, :sub, :who, :now, :tentative) do
        def day? = false
        def block? = false
      end
      Day = Data.define(:label) do
        def day? = true
        def block? = false
      end
      # heights: rem per grid row. Cells: item (Event or Day) at row/lane, spanning rows and lanes.
      Block = Data.define(:columns, :heights, :cells) do
        def day? = false
        def block? = true
      end
      Cell = Data.define(:item, :row, :rows, :lane, :lanes)

      attr_reader :height, :items, :more

      # The family marks tentative events by starting the title with "?".
      def self.tentative?(event) = event[:title].start_with?("?")

      def self.all_day(events, now)
        today = now.to_date.iso8601
        events.select { it[:all_day] && it[:start] <= today && today < it[:end] }.first(3)
      end

      def initialize(now:, height:, events:)
        @height = height
        @items = []
        @more = 0
        layout(now, events)
      end

      private

      # A block being built. Cells are hashes until flushed; :end is nil for all-day events (they overlap nothing).
      Building = Struct.new(:heights, :cells, :last_row) do
        def on_at(t) = cells.select { it[:end] && it[:end] > t }
      end

      # Fills @items with Events, Days and Blocks while they fit; @more counts the rest.
      def layout(now, events)
        today = now.to_date
        list = events.reject { it[:all_day] && Date.parse(it[:start]) <= today } # today's are chips
          .map { [it, *times(it)] }
          .select { |_, _, e0| e0 > now }
          .sort_by { |_, s0, e0| [s0, e0] }

        used = 0.0
        last_day = today
        block = nil
        list.each_with_index do |(e, s0, e0), i|
          day = [s0.to_date, today].max
          divider = day > last_day
          on = block&.on_at(s0) || []
          spanning = divider ? block&.on_at(day.to_time) || [] : [] # reaching past the divider
          share = !divider && !e[:all_day] && block && block.last_row.any? && block.last_row.all? { it[:end] && it[:end] > s0 }

          heights = []
          heights << DIVIDER if divider
          heights << ROW unless share
          need = heights.each_with_index.sum { |h, j| ((used.zero? && j.zero?) ? 0 : GAP) + h }
          more_line = (i < list.size - 1) ? GAP + MORE : 0 # room for "+ N flere" should the next one not fit
          if used + need + more_line > height + 1e-9 # float sums of rem sizes
            @more = list.size - i
            break
          end
          used += need

          if divider
            if spanning.any?
              add_row(block, DIVIDER, spanning)
              covered = spanning.map { it[:lane] }
              lane, lanes = covered.min.positive? ? [0, covered.min] : [covered.max + 1, nil] # nil: to the last lane
              block.cells << {item: Day.new(day_label(day, today)), row: block.heights.size - 1, last: block.heights.size - 1, lane:, lanes:}
              block.last_row = []
            else
              flush(block)
              block = nil
              @items << Day.new(day_label(day, today))
            end
            last_day = day
          end

          if on.empty?
            flush(block)
            block = Building.new([], [], [])
          end
          lane = (0..).find { |l| (on + (share ? block.last_row : [])).none? { it[:lane] == l } }
          add_row(block, ROW, on) unless share
          cell = {item: event(e, s0, e0, now, today), row: block.heights.size - 1, last: block.heights.size - 1, lane:,
                  lanes: 1, end: (e0 unless e[:all_day])}
          block.cells << cell
          block.last_row = share ? block.last_row + [cell] : [cell]
        end
        flush(block)
      end

      def add_row(block, height, extend)
        block.heights << height
        extend.each { it[:last] = block.heights.size - 1 }
      end

      def flush(block)
        return unless block
        return @items << block.cells.first[:item] if block.cells.size == 1 && block.heights.size == 1

        columns = block.cells.map { it[:lanes] ? it[:lane] + it[:lanes] : it[:lane] + 1 }.max
        cells = block.cells.map do |c|
          Cell.new(c[:item], c[:row], c[:last] - c[:row] + 1, c[:lane], c[:lanes] || columns - c[:lane])
        end
        @items << Block.new(columns, block.heights, cells)
      end

      def event(e, s0, e0, now, today)
        all_day = e[:all_day]
        Event.new(
          time: (s0.strftime("%H:%M") unless all_day || s0.to_date < today),
          until: if all_day
                   "hele dagen"
                 else
                   "til #{"#{SHORT_WEEKDAYS[e0.wday]} " if (e0 - 1).to_date > [s0.to_date, today].max}#{e0.strftime("%H:%M")}"
                 end,
          title: e[:title], sub: (e[:location] unless e[:location].empty?), who: e[:who],
          now: s0 <= now && now < e0, tentative: self.class.tentative?(e)
        )
      end

      # All-day events have dates (end exclusive), timed ones ISO 8601 times.
      def times(e)
        return [Date.parse(e[:start]).to_time, Date.parse(e[:end]).to_time] if e[:all_day]

        [Time.iso8601(e[:start]), Time.iso8601(e[:end])]
      end

      def day_label(day, today)
        return "I MORGEN" if day == today + 1

        "#{WEEKDAYS[day.wday]} #{day.day}. #{MONTHS[day.month - 1]}"
      end
    end
  end
end
