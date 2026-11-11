# frozen_string_literal: true

RSpec.describe KitchenDashboard::Display::Weather do
  subject(:weather) { described_class.new(forecast) }

  let(:now) { Time.new(2026, 6, 10, 9, 20) }
  let(:forecast) { Fixtures.forecast(now) }

  it "shows current conditions" do
    expect([weather.temp, weather.condition, weather.feel]).to eq(["9°", "Overskyet", "Føles som 6° · NV 7 m/s"])
  end

  it "shows the next hours" do
    expect(weather.hours.size).to eq(12)
    expect(weather.hours.first.to_h).to eq(time: "10", icon: :cloudy, temp: "10°")
    expect(weather.hours.map(&:time).first(3)).to eq(%w[10 12 14]) # 2 hours each
  end

  it "shows the worst weather of a slot's hours" do
    forecast["hourly"]["weather_code"][forecast["hourly"]["time"].index("2026-06-10T11:00")] = 61
    expect(weather.hours.first.icon).to eq(:rainy)
  end

  it "picks icons by weather code and daylight" do
    expect([[0, true], [0, false], [2, false], [61, true], [81, true], [85, true], [95, true]].map { described_class.icon(*it) })
      .to eq([:clear_day, :clear_night, :partly_night, :rainy, :rainy, :snowy, :thunder])
  end

  it "flags rain, sunscreen and sailing" do
    expect(weather.alerts.map(&:to_h)).to eq([
      {kind: :rain, title: "Regn fra 11", sub: "1,8 mm til 13"},
      {kind: :sun, title: "Solcreme", sub: "UV 5 til 11"},
      {kind: :sail, title: "Godt sejlvejr", sub: "NV 5 (8) m/s"} # only 0.9 mm in the next 3 h
    ])
  end

  it "does not flag sailing with 1 mm or more in the next 3 hours" do
    forecast["hourly"]["precipitation"][forecast["hourly"]["time"].index("2026-06-10T11:00")] = 0.2
    expect(weather.alerts.map(&:kind)).to eq([:rain, :sun])
  end

  it "flags rain up to 9 hours after the current one" do
    precip = forecast["hourly"]["precipitation"].fill(0)
    precip[forecast["hourly"]["time"].index("2026-06-10T19:00")] = 0.5 # 18–19
    expect(weather.alerts.first.to_h).to eq(kind: :rain, title: "Regn fra 18", sub: "0,5 mm til 19")

    precip.fill(0)[forecast["hourly"]["time"].index("2026-06-10T20:00")] = 0.5 # 19–20
    expect(described_class.new(forecast).alerts.map(&:kind)).not_to include(:rain)
  end

  it "shows nothing when nothing is worth flagging" do
    forecast["hourly"]["precipitation"].fill(0)
    forecast["hourly"]["uv_index"].fill(0)
    forecast["hourly"]["wind_gusts_10m"].fill(15)
    expect(weather.alerts).to be_empty
  end
end
