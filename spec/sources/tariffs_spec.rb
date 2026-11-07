# frozen_string_literal: true

RSpec.describe KitchenDashboard::Sources::Tariffs do
  subject(:tariffs) { described_class.new(http:, cache: KitchenDashboard::Cache.new) }

  def hourly(night, day, peak) = [night] * 6 + [day] * 11 + [peak] * 4 + [day] * 3

  def record(gln, code, from, to, prices)
    {"GLN_Number" => gln, "ChargeTypeCode" => code, "ChargeType" => "D03", "ValidFrom" => from, "ValidTo" => to}
      .merge(prices.each_with_index.to_h { |p, i| ["Price#{i + 1}", p] })
  end

  let(:records) do
    [
      record("5790000000001", "C", "2026-04-01T00:00:00", "2026-10-01T00:00:00", hourly(0.0429, 0.0644, 0.1674)),
      record("5790000000001", "C", "2026-10-01T00:00:00", "2027-01-01T00:00:00", hourly(0.0429, 0.1288, 0.3863)),
      record("5790000000001", "C", "2024-01-01T00:00:00", "2024-04-01T00:00:00", hourly(1, 1, 1)),
      record("5790000432752", "40000", "2026-01-01T00:00:00", "2027-01-01T00:00:00", [0.043] + [nil] * 23),
      record("5790000432752", "41000", "2026-01-01T00:00:00", "2027-01-01T00:00:00", [0.072] + [nil] * 23),
      record("5790000432752", "EA-001", "2026-01-01T00:00:00", nil, [0.008] + [nil] * 23),
      record("5790000432752", "C", "2026-01-01T00:00:00", nil, [5] + [nil] * 23) # right code, wrong owner
    ]
  end
  let(:http) do
    FakeHttp.new do |_, url|
      expect(URI.decode_www_form_component(url)).to include('"GLN_Number":["5790000000001","5790000432752"]')
      {"records" => records}
    end
  end

  it "sums the grid, Energinet and tax charges valid in that hour" do
    expect(tariffs.at(Time.new(2026, 9, 15, 3))).to be_within(1e-9).of(0.0429 + 0.123)
    expect(tariffs.at(Time.new(2026, 9, 30, 18))).to be_within(1e-9).of(0.1674 + 0.123)
    expect(tariffs.at(Time.new(2026, 10, 1, 0))).to be_within(1e-9).of(0.0429 + 0.123)
    expect(tariffs.at(Time.new(2026, 11, 7, 18))).to be_within(1e-9).of(0.3863 + 0.123)
    expect(tariffs.at(Time.new(2026, 11, 7, 12))).to be_within(1e-9).of(0.1288 + 0.123)
  end
end
