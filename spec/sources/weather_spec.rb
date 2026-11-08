# frozen_string_literal: true

RSpec.describe KitchenDashboard::Sources::Weather do
  it "uses DMI's model and takes the UV index from the default model" do
    http = FakeHttp.new do |_, url|
      if url.include?("dmi_seamless")
        {"current" => {}, "hourly" => {"time" => %w[a b], "precipitation" => [0, 1], "uv_index" => nil}}
      else
        {"hourly" => {"time" => %w[a b], "uv_index" => [2.5, 3.1]}}
      end
    end
    forecast = described_class.new(http:, cache: KitchenDashboard::Cache.new).call

    expect(forecast["hourly"]).to include("precipitation" => [0, 1], "uv_index" => [2.5, 3.1])
    stub = "https://api.open-meteo.com/v1/forecast?latitude=#{KitchenDashboard::Config::LAT}&longitude=#{KitchenDashboard::Config::LON}"
    expect(http.calls).to all(start_with(stub))
    expect(http.calls.first).to include("models=dmi_seamless", "wind_speed_unit=ms", "hourly=temperature_2m%2Cprecipitation%2Cwind_speed_10m")
    expect(http.calls.last).to include("hourly=uv_index")
    expect(http.calls.last).not_to include("models=")
  end
end
