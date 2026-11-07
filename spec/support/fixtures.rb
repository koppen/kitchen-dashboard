# frozen_string_literal: true

# Mock API data relative to `now`, matching what the sources return.
module Fixtures
  HOUR = 3600

  module_function

  def local(t) = t.strftime("%Y-%m-%dT%H:%M")

  # Rain during hours now+2 and now+3, UV 5.2 this hour and the next, 5 m/s wind.
  def forecast(now)
    day0 = now.to_date.to_time
    times = Array.new(48) { local(day0 + it * HOUR) }
    i0 = times.index(local(Time.at(now.to_i / HOUR * HOUR)))
    arr = ->(&f) { Array.new(48, &f) }
    {
      "current" => {"time" => local(now), "temperature_2m" => 9.2, "apparent_temperature" => 6.4, "weather_code" => 3,
                    "wind_speed_10m" => 6.8, "wind_direction_10m" => 320},
      "hourly" => {
        "time" => times,
        "temperature_2m" => arr.() { 8 + it % 4 },
        "precipitation" => arr.() { [i0 + 3, i0 + 4].include?(it) ? 0.9 : 0 },
        "uv_index" => arr.() { [i0, i0 + 1].include?(it) ? 5.2 : 0 },
        "wind_speed_10m" => arr.() { 5 }, "wind_gusts_10m" => arr.() { 8 },
        "is_day" => arr.() { 1 }, "weather_code" => arr.() { 3 }
      }
    }
  end

  def event(now, from, to, title, who, **extra)
    {title:, location: "", start: Time.at(now + from * HOUR).iso8601, end: Time.at(now + to * HOUR).iso8601, all_day: false,
     who: who.chars.map { {initial: it, color: "#888"} }, **extra}
  end

  def events(now)
    [
      event(now, -0.5, 1, "Football", "A", location: "Hallen"),
      event(now, 1.2, 3.7, "Dinner at Mormor", "JAI"),
      event(now, 2.2, 4, "Book club", "M"),
      event(now, -3, -2, "Already over", "J"),
      {title: "School trip", location: "", start: now.to_date.iso8601, end: (now.to_date + 1).iso8601, all_day: true,
       who: [{initial: "I", color: "#c79bff"}]}
    ]
  end

  def prices(now)
    start = now.to_i / HOUR * HOUR
    Array.new(48) { {t: start - HOUR + it * HOUR, p: 0.5 + Math.sin(it / 3.0).abs * 1.5} }
  end
end
