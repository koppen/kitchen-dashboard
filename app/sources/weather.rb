# frozen_string_literal: true

module KitchenDashboard
  module Sources
    # Open-Meteo forecast with DMI's HARMONIE model (dmi_seamless), passed through as-is.
    # DMI has no UV index, so that comes from Open-Meteo's default model.
    class Weather
      include Deps["http", "cache"]

      TTL = 10 * 60

      def call = cache.fetch(:weather, TTL) { fetch }

      def stale? = (cache.age(:weather) || Float::INFINITY) > 2 * TTL

      private

      def fetch
        forecast = get(
          models: "dmi_seamless",
          current: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m",
          hourly: "precipitation,wind_speed_10m,wind_gusts_10m,is_day,weather_code"
        )
        forecast["hourly"]["uv_index"] = get(hourly: "uv_index")["hourly"]["uv_index"]
        forecast
      end

      def get(**params)
        q = URI.encode_www_form(latitude: Config::LAT, longitude: Config::LON, timezone: "auto", wind_speed_unit: "ms",
          forecast_days: 2, **params)
        http.get_json("https://api.open-meteo.com/v1/forecast?#{q}")
      end
    end
  end
end
