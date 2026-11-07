# auto_register: false
# frozen_string_literal: true

require "time"

module KitchenDashboard
  module Display
    # Hour rows from the current hour, positioned events, and price bars, on one hour axis.
    class Timeline
      ROW = 4.2        # rem per hour
      BAR_MAX = 9.0    # rem, length of the most expensive bar (the price column width)
      LABEL_MIN = 3.8  # rem, shortest bar that fits its price inside
      CHEAP_BELOW = 1.0 # kr/kWh: hours cheaper than this are highlighted
      HOUR = 3600

      Event = Data.define(:title, :sub, :who, :col, :cols, :top, :height, :now, :tentative)
      Price = Data.define(:value, :width, :cheap, :inside)

      attr_reader :rows, :start

      # The family marks tentative events by starting the title with "?".
      def self.tentative?(event) = event[:title].start_with?("?")

      def self.all_day(events, now)
        today = now.to_date.iso8601
        events.select { it[:all_day] && it[:start] <= today && today < it[:end] }.first(3)
      end

      def initialize(now:, height:, events:, prices:)
        @now = now
        @rows = [1, (height / ROW).floor].max
        @start = Time.at(now.to_i / HOUR * HOUR) # Danish offsets are whole hours
        @events = events
        @prices = prices
      end

      def height = rows * ROW

      def hours = Array.new(rows) { format("%02d", (start + it * HOUR).hour) }

      # rem offset of the midnight line, nil if midnight is outside the window
      def midnight
        row = ((@now.to_date + 1).to_time - start) / HOUR
        row * ROW if row < rows
      end

      def events
        win_start = start.to_i
        win_end = win_start + rows * HOUR
        now = @now.to_i
        list = @events.reject { it[:all_day] }.filter_map do |e|
          s0 = Time.iso8601(e[:start]).to_i
          e0 = Time.iso8601(e[:end]).to_i
          x = {e:, s: [s0, win_start].max, en: [e0, win_end].min, e0:, now: s0 <= now && now < e0}
          x if x[:en] > x[:s] && e0 > now
        end
        list.sort_by! { [it[:s], -it[:en]] }

        # overlapping events are split into columns
        clusters = []
        cluster = []
        cluster_end = 0
        list.each do |x|
          if cluster.any? && x[:s] >= cluster_end
            clusters << cluster
            cluster = []
            cluster_end = 0
          end
          col = 0
          col += 1 while cluster.any? { it[:col] == col && it[:en] > x[:s] }
          x[:col] = col
          cluster << x
          cluster_end = [cluster_end, x[:en]].max
        end
        clusters << cluster if cluster.any?
        clusters.each do |cl|
          cols = cl.map { it[:col] }.max + 1
          cl.each { it[:cols] = cols }
        end

        list.map do |x|
          e = x[:e]
          height = [(x[:en] - x[:s]).fdiv(HOUR) * ROW - 0.4, 3.4].max
          sub = e[:location].empty? ? "til #{Time.at(x[:e0]).strftime("%H:%M")}" : e[:location]
          Event.new(
            title: e[:title], sub: (sub if height >= 5.6), who: e[:who], col: x[:col], cols: x[:cols],
            top: (x[:s] - win_start).fdiv(HOUR) * ROW + 0.2, height:, now: x[:now], tentative: self.class.tentative?(e)
          )
        end
      end

      # One entry per row, nil where the price is unknown.
      def prices
        by_hour = @prices.to_h { [it[:t], it[:p]] }
        v = Array.new(rows) { by_hour[start.to_i + it * HOUR] }
        known = v.compact
        return [] if known.empty?

        max = known.max
        v.map do |p|
          next unless p

          width = max.positive? ? [p, 0].max / max * BAR_MAX : 0
          Price.new(value: format("%.2f", p).tr(".", ","), width:, cheap: p < CHEAP_BELOW, inside: width >= LABEL_MIN)
        end
      end
    end
  end
end
