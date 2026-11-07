# frozen_string_literal: true

require "json"
require "time"

module KitchenDashboard
  module Sources
    # What a kWh costs, per hour: day-ahead spot price from Energi Data Service (15-minute resolution
    # since 2025-10-01, averaged to hours) + supplier markup + tariffs and taxes, incl. VAT.
    # Returns [{t: unix seconds of the hour start, p: kr/kWh}].
    class Prices
      include Deps["http", "cache", "sources.tariffs"]

      TTL = 30 * 60

      def call = cache.fetch(:prices, TTL) { fetch }

      def stale? = (cache.age(:prices) || Float::INFINITY) > 2 * TTL

      private

      def fetch
        today = Date.today
        q = URI.encode_www_form(
          start: today.iso8601, end: (today + 3).iso8601, # end is exclusive
          filter: JSON.generate(PriceArea: [Config::PRICE_AREA]),
          sort: "TimeUTC asc",
          limit: 400
        )
        records = http.get_json("https://api.energidataservice.dk/dataset/DayAheadPrices?#{q}")["records"] || []

        hours = Hash.new { |h, k| h[k] = [] }
        records.each do |r|
          next if r["DayAheadPriceDKK"].nil?

          utc = r["TimeUTC"].end_with?("Z") ? r["TimeUTC"] : "#{r["TimeUTC"]}Z"
          hours[Time.iso8601(utc).to_i / 3600 * 3600] << r["DayAheadPriceDKK"] / 1000.0 # DKK/MWh -> kr/kWh
        end
        hours.map do |t, ps|
          time = Time.at(t)
          {t:, p: (ps.sum / ps.size + Config::MARKUP.(time) + tariffs.at(time)) * Config::VAT}
        end
      end
    end
  end
end
