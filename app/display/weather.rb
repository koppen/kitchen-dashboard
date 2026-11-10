# auto_register: false
# frozen_string_literal: true

module KitchenDashboard
  module Display
    # Current conditions, the next hours and alert cards from an Open-Meteo forecast.
    #
    # Open-Meteo hourly precipitation is the sum over the *preceding* hour, so rain during the
    # hour starting at time[i] is precipitation[i + 1]. Times are local to the forecast location.
    class Weather
      RAIN = {mm: 0.2, hours: 10}                              # rain of at least 0.2 mm/h this hour or the next 9
      UV_LIMIT = 3                                             # sunscreen at UV index >= 3
      SAIL = {min_wind: 3, max_wind: 9, max_gust: 12, hours: 3} # m/s, next 3 daylight hours, dry

      HOURS = 12 # rendered; as many as fit the width are visible

      Alert = Data.define(:kind, :title, :sub)
      Hour = Data.define(:time, :icon, :temp)

      attr_reader :temp, :condition, :feel, :hours, :alerts

      def initialize(forecast)
        c = forecast["current"]
        @temp = "#{c["temperature_2m"].round}°"
        @condition = self.class.condition(c["weather_code"])
        @feel = "Føles som #{c["apparent_temperature"].round}° · #{compass(c["wind_direction_10m"])} #{c["wind_speed_10m"].round} m/s"
        h = forecast["hourly"]
        i0 = h["time"].index("#{c["time"][0, 13]}:00")
        @hours = i0 ? build_hours(h, i0) : []
        @alerts = i0 ? build_alerts(c, h, i0) : []
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

      # icon name (Views::Helpers::ICONS) for a WMO weather code
      def self.icon(code, day)
        case code
        when 0 then day ? :clear_day : :clear_night
        when 1..2 then day ? :partly_day : :partly_night
        when 3 then :cloudy
        when ..48 then :fog
        when ..67, 80..82 then :rainy
        when ..77, 85..86 then :snowy
        else :thunder
        end
      end

      private

      # the next full hours after the current one
      def build_hours(h, i0)
        (i0 + 1..i0 + HOURS).filter_map do |i|
          next unless h["time"][i]
          Hour.new(h["time"][i][11, 2], self.class.icon(h["weather_code"][i], h["is_day"][i] == 1), "#{h["temperature_2m"][i].round}°")
        end
      end

      def build_alerts(c, h, i0)
        hour = ->(i) { h["time"][i][11, 2].to_i } # the forecast is per hour, so no minutes ("fra 9")
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
          alerts << Alert.new(:rain, m.zero? ? "Regn nu" : "Regn fra #{hour.(i0 + m)}", "#{decimal(mm, 1)} mm til #{hour.(i0 + e)}")
        end

        uv = ->(i) { h["uv_index"][i].to_f }
        if (k = (0...3).find { uv.(i0 + it) >= UV_LIMIT })
          e = k
          peak = 0
          while uv.(i0 + e) >= UV_LIMIT
            peak = [peak, uv.(i0 + e)].max
            e += 1
          end
          sub = k.zero? ? "UV #{peak.round} til #{hour.(i0 + e)}" : "UV #{peak.round} fra #{hour.(i0 + k)}"
          alerts << Alert.new(:sun, "Solcreme", sub)
        end

        window = ->(key) { h[key][i0, SAIL[:hours]] }
        wind = window.("wind_speed_10m")
        gust = window.("wind_gusts_10m").max
        avg = wind.sum / wind.size
        wet = (1..SAIL[:hours]).sum { precip.(i0 + it) }
        if window.("is_day").all?(1) && window.("weather_code").all? { it < 95 } &&
            avg.between?(SAIL[:min_wind], SAIL[:max_wind]) && gust <= SAIL[:max_gust] && wet < 1
          # wind (gusts), as DMI writes it
          alerts << Alert.new(:sail, "Godt sejlvejr", "#{compass(c["wind_direction_10m"])} #{avg.round} (#{gust.round}) m/s")
        end

        alerts
      end

      def compass(deg) = %w[N NØ Ø SØ S SV V NV][(deg / 45.0).round % 8]

      def decimal(x, digits) = format("%.#{digits}f", x).tr(".", ",")
    end
  end
end
