# frozen_string_literal: true

RSpec.describe KitchenDashboard::Sources::Weather do
  it "passes the Open-Meteo forecast through" do
    http = FakeHttp.new { |_, url| {"url" => url} }
    url = described_class.new(http:, cache: KitchenDashboard::Cache.new).call["url"]
    expect(url).to start_with("https://api.open-meteo.com/v1/forecast?latitude=55.68&longitude=12.57")
    expect(url).to include("wind_speed_unit=ms", "hourly=precipitation%2Cuv_index")
  end
end
