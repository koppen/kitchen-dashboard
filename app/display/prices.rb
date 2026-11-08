# auto_register: false
# frozen_string_literal: true

module KitchenDashboard
  module Display
    # Bar chart of the next 24 hours of electricity prices, along the bottom of the page.
    class Prices
      HOURS = 24
      SCALE_MAX = 3.0   # kr/kWh at the top of the chart; dearer hours are cut off
      LINES = [2.0, 1.0] # kr/kWh reference lines (1 kr is drawn green)
      CHEAP_BELOW = 1.0 # kr/kWh: hours cheaper than this are highlighted
      HOUR = 3600

      # height: 0..1 of the chart; label: hour label below the bar, if any
      Bar = Data.define(:height, :cheap, :now, :clipped, :label)

      def initialize(now:, prices:)
        @start = now.to_i / HOUR * HOUR
        @by_hour = prices.to_h { [it[:t], it[:p]] }
      end

      # Current price as text, nil if unknown.
      def current
        p = @by_hour[@start]
        format("%.2f", p).tr(".", ",") if p
      end

      # One entry per hour from the current one, nil where the price isn't published yet.
      def bars
        Array.new(HOURS) do |i|
          p = @by_hour[@start + i * HOUR] or next

          Bar.new(height: p.clamp(0, SCALE_MAX) / SCALE_MAX, cheap: p < CHEAP_BELOW, now: i.zero?,
            clipped: p > SCALE_MAX, label: label(i))
        end
      end

      # Labels under every slot (also empty ones): "Nu" for the current hour, then 00/06/12/18.
      def labels = Array.new(HOURS) { label(it) }

      def lines = LINES.map { {value: "#{format("%.2f", it).tr(".", ",")} kr", bottom: it / SCALE_MAX, good: it <= CHEAP_BELOW} }

      private

      def label(i)
        return "Nu" if i.zero?

        hour = Time.at(@start + i * HOUR).hour
        format("%02d", hour) if (hour % 6).zero? && i > 2 # keep clear of "Nu"
      end
    end
  end
end
