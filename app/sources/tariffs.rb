# frozen_string_literal: true

require "json"

module KitchenDashboard
  module Sources
    # Per-kWh tariffs and taxes from the DataHub price list (Energi Data Service `DatahubPricelist`):
    # the grid company's time-of-day tariff, Energinet's tariffs and elafgift (Config::TARIFFS).
    class Tariffs
      include Deps["http", "cache"]

      TTL = 24 * 3600

      def call = cache.fetch(:tariffs, TTL) { fetch }

      def stale? = (cache.age(:tariffs) || Float::INFINITY) > 2 * TTL

      # Sum of the tariffs for the hour starting at `t`, kr/kWh ex VAT.
      def at(t)
        local = t.strftime("%Y-%m-%dT%H:%M:%S")
        call.sum do |r|
          next 0 unless r["ValidFrom"] <= local && (r["ValidTo"].nil? || local < r["ValidTo"])

          r["Price#{t.hour + 1}"] || r["Price1"] # daily-resolution charges only have Price1
        end
      end

      private

      def fetch
        q = URI.encode_www_form(
          filter: JSON.generate(
            ChargeType: ["D03"],
            GLN_Number: Config::TARIFFS.map(&:first).uniq,
            ChargeTypeCode: Config::TARIFFS.map(&:last).uniq
          ),
          limit: 0
        )
        records = http.get_json("https://api.energidataservice.dk/dataset/DatahubPricelist?#{q}")["records"] || []
        records.select { Config::TARIFFS.include?([it["GLN_Number"], it["ChargeTypeCode"]]) }
      end
    end
  end
end
