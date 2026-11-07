# frozen_string_literal: true

module KitchenDashboard
  module Views
    module Dashboard
      class Show < KitchenDashboard::View
        include Deps[
          "logger",
          events_source: "sources.events",
          weather_source: "sources.weather",
          prices_source: "sources.prices"
        ]

        expose :weather do
          forecast = load(weather_source)
          Display::Weather.new(forecast) if forecast
        end

        private_expose :events do
          load(events_source) || []
        end

        expose :all_day do |events, now:|
          Display::Timeline.all_day(events, now)
        end

        expose :timeline do |weather, all_day, events, now:|
          height = Display::Layout.timeline_height(alerts: weather&.alerts&.size || 0, all_day: all_day.any?)
          Display::Timeline.new(now:, height:, events:, prices: load(prices_source) || [])
        end

        # depends on the others so it is evaluated after the sources were called
        expose :stale do |weather, timeline|
          {"kalender" => events_source, "vejr" => weather_source, "elpriser" => prices_source}.select { |_, s| s.stale? }.keys
        end

        private

        def load(source)
          source.call
        rescue => e
          logger.error("#{source.class}: #{e.message}")
          nil
        end
      end
    end
  end
end
