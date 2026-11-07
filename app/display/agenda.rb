# auto_register: false
# frozen_string_literal: true

require "time"

module KitchenDashboard
  module Display
    # The next events as a compact list, one fixed-height row each and a divider per day after today,
    # as many as fit in the free height. Today's all-day events are chips above it instead.
    # Heights mirror the CSS in the layout.
    class Agenda
      ROW = 5.2     # rem per event row
      GAP = 0.6     # rem between rows
      DIVIDER = 2.0 # rem, day divider ("I MORGEN", "MANDAG 9. NOV")
      MORE = 2.0    # rem, "+ N flere" line

      WEEKDAYS = %w[SØNDAG MANDAG TIRSDAG ONSDAG TORSDAG FREDAG LØRDAG].freeze
      MONTHS = %w[JAN FEB MAR APR MAJ JUN JUL AUG SEP OKT NOV DEC].freeze

      # time: nil for all-day events (until then reads "hele dagen")
      Event = Data.define(:time, :until, :title, :sub, :who, :now, :tentative) do
        def day? = false
      end
      Day = Data.define(:label) do
        def day? = true
      end

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

      # Fills @items with Events and Days (dividers) while they fit; @more counts the rest.
      def layout(now, events)
        today = now.to_date
        list = events.reject { it[:all_day] && Date.parse(it[:start]) <= today } # today's are chips
          .map { [it, *times(it)] }
          .select { |_, _, e0| e0 > now }
          .sort_by { |_, s0, e0| [s0, e0] }

        used = 0.0
        last_day = today
        list.each_with_index do |(e, s0, e0), i|
          day = [s0.to_date, today].max
          divider = day > last_day
          need = (@items.empty? ? 0 : GAP) + ROW
          need += DIVIDER + GAP if divider
          need += GAP + MORE if i < list.size - 1 # room for "+ N flere" should the next one not fit
          if used + need > height + 1e-9 # float sums of rem sizes
            @more = list.size - i
            break
          end

          if divider
            used += (@items.empty? ? 0 : GAP) + DIVIDER
            @items << Day.new(day_label(day, today))
            last_day = day
          end
          used += (@items.empty? ? 0 : GAP) + ROW
          @items << Event.new(
            time: (s0.strftime("%H:%M") unless e[:all_day]),
            until: e[:all_day] ? "hele dagen" : "til #{e0.strftime("%H:%M")}",
            title: e[:title], sub: (e[:location] unless e[:location].empty?), who: e[:who],
            now: s0 <= now && now < e0, tentative: self.class.tentative?(e)
          )
        end
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
