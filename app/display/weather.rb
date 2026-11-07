# auto_register: false
# frozen_string_literal: true

module KitchenDashboard
  module Display
    # Current conditions and alert cards from an Open-Meteo forecast.
    #
    # Open-Meteo hourly precipitation is the sum over the *preceding* hour, so rain during the
    # hour starting at time[i] is precipitation[i + 1]. Times are local to the forecast location.
    class Weather
      RAIN = {mm: 0.2, hours: 4}                               # rain of at least 0.2 mm/h in the next 4 h
      UV_LIMIT = 3                                             # sunscreen at UV index >= 3
      SAIL = {min_wind: 3, max_wind: 9, max_gust: 12, hours: 3} # m/s, next 3 daylight hours, dry

      Alert = Data.define(:kind, :title, :sub)

      attr_reader :temp, :condition, :feel, :alerts

      def initialize(forecast)
        c = forecast["current"]
        @temp = "#{c["temperature_2m"].round}°"
        @condition = self.class.condition(c["weather_code"])
        @feel = "Føles som #{c["apparent_temperature"].round}° · #{compass(c["wind_direction_10m"])} #{c["wind_speed_10m"].round} m/s"
        @alerts = build_alerts(c, forecast["hourly"])
      end

      # WMO weather codes
      def self.condition(code)
        case code
        when 0 then "Klart"
        when 1..2 then "Delvis skyet"
        when 3 then "Overskyet"
        when ..48 then "Tåge"
        when ..57 then "Støvregn"
        when ..67 then "Regn"
        when ..77 then "Sne"
        when ..82 then "Byger"
        when ..86 then "Snebyger"
        else "Torden"
        end
      end

      private

      def build_alerts(c, h)
        i0 = h["time"].index("#{c["time"][0, 13]}:00") or return []
        at = ->(i) { h["time"][i][11, 5] }
        precip = ->(i) { h["precipitation"][i].to_f }
        alerts = []

        rain_in = ->(m) { precip.(i0 + 1 + m) >= RAIN[:mm] } # rain during hour i0 + m
        if (m = (0...RAIN[:hours]).find(&rain_in))
          e = m
          mm = 0.0
          while rain_in.(e)
            mm += precip.(i0 + 1 + e)
            e += 1
          end
          alerts << Alert.new(:rain, m.zero? ? "Regn nu" : "Regn fra #{at.(i0 + m)}", "#{decimal(mm, 1)} mm indtil #{at.(i0 + e)}")
        end

        uv = ->(i) { h["uv_index"][i].to_f }
        if (k = (0...3).find { uv.(i0 + it) >= UV_LIMIT })
          e = k
          peak = 0
          while uv.(i0 + e) >= UV_LIMIT
            peak = [peak, uv.(i0 + e)].max
            e += 1
          end
          sub = k.zero? ? "UV #{peak.round} indtil #{at.(i0 + e)}" : "UV #{peak.round} fra #{at.(i0 + k)}"
          alerts << Alert.new(:sun, "Solcreme", sub)
        end

        window = ->(key) { h[key][i0, SAIL[:hours]] }
        wind = window.("wind_speed_10m")
        gust = window.("wind_gusts_10m").max
        avg = wind.sum / wind.size
        wet = (1..SAIL[:hours]).sum { precip.(i0 + it) }
        if window.("is_day").all?(1) && window.("weather_code").all? { it < 95 } &&
            avg.between?(SAIL[:min_wind], SAIL[:max_wind]) && gust <= SAIL[:max_gust] && wet < 1
          alerts << Alert.new(:sail, "Godt sejlvejr", "#{compass(c["wind_direction_10m"])} #{avg.round} m/s, vindstød #{gust.round}")
        end

        alerts
      end

      def compass(deg) = %w[N NØ Ø SØ S SV V NV][(deg / 45.0).round % 8]

      def decimal(x, digits) = format("%.#{digits}f", x).tr(".", ",")
    end
  end
end
