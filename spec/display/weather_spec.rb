# frozen_string_literal: true

RSpec.describe KitchenDashboard::Display::Weather do
  subject(:weather) { described_class.new(forecast) }

  let(:now) { Time.new(2026, 6, 10, 9, 20) }
  let(:forecast) { Fixtures.forecast(now) }

  it "shows current conditions" do
    expect([weather.temp, weather.condition, weather.feel]).to eq(["9°", "Overskyet", "Føles som 6° · NV 7 m/s"])
  end

  it "flags rain, sunscreen and sailing" do
    expect(weather.alerts.map(&:to_h)).to eq([
      {kind: :rain, title: "Regn fra 11:00", sub: "1,8 mm til 13:00"},
      {kind: :sun, title: "Solcreme", sub: "UV 5 til 11:00"},
      {kind: :sail, title: "Godt sejlvejr", sub: "NV 5 (8) m/s"} # only 0.9 mm in the next 3 h
    ])
  end

  it "does not flag sailing with 1 mm or more in the next 3 hours" do
    forecast["hourly"]["precipitation"][forecast["hourly"]["time"].index("2026-06-10T11:00")] = 0.2
    expect(weather.alerts.map(&:kind)).to eq([:rain, :sun])
  end

  it "shows nothing when nothing is worth flagging" do
    forecast["hourly"]["precipitation"].fill(0)
    forecast["hourly"]["uv_index"].fill(0)
    forecast["hourly"]["wind_gusts_10m"].fill(15)
    expect(weather.alerts).to be_empty
  end
end
