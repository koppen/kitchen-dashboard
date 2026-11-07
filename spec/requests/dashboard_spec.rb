# frozen_string_literal: true

require "dry/system/stubs"

RSpec.describe "Dashboard", type: :request do
  let(:now) { Time.now }
  let(:container) { Hanami.app.container }

  def source(data) = double(call: data, stale?: false)

  before do
    container.enable_stubs!
    container.stub("sources.weather", source(Fixtures.forecast(now)))
    container.stub("sources.events", source(Fixtures.events(now)))
    container.stub("sources.prices", source(Fixtures.prices(now)))
  end

  after { container.unstub }

  it "renders the dashboard" do
    get "/"
    expect(last_response).to be_ok
    body = last_response.body
    expect(body).to include('<div class="temp">9°</div>', "Overskyet", "Solcreme", "HELE DAGEN", "I MORGEN", "School trip", "Dinner at Mormor")
    expect(body).not_to include("Already over", "forældet:")
    expect(body.scan('class="hr"').size).to eq(13) # all-day row; 3 alerts are 14.4rem
    expect(body.scan('class="pr cheap"').size).to eq(4)
  end

  it "renders what it has when a source fails" do
    container.stub("sources.weather", double(call: nil, stale?: true).tap { allow(it).to receive(:call).and_raise("down") })
    get "/"
    expect(last_response).to be_ok
    expect(last_response.body).to include("forældet: vejr", "Dinner at Mormor")
    expect(last_response.body.scan('class="hr"').size).to eq(13)
  end

  it "includes the boot id so open pages reload after a restart" do
    get "/"
    expect(last_response.body).to include(%(<meta name="boot-id" content="#{KitchenDashboard::App::BOOT_ID}">))
  end

  it "is installable as a web app" do
    get "/"
    expect(last_response.body).to include('<link rel="manifest" href="/manifest.webmanifest">', 'name="apple-mobile-web-app-capable"')

    get "/manifest.webmanifest"
    expect(last_response.headers["content-type"]).to eq("application/manifest+json")
    manifest = JSON.parse(last_response.body)
    expect(manifest).to include("display" => "fullscreen", "start_url" => "/")
    manifest["icons"].each do |icon|
      get icon["src"]
      expect(last_response).to be_ok
    end
  end

  it "serves the sources as JSON" do
    get "/api/prices"
    expect(last_response.headers["content-type"]).to start_with("application/json")
    expect(JSON.parse(last_response.body).size).to eq(48)
  end

  it "returns 502 when a source fails" do
    container.stub("sources.events", double.tap { allow(it).to receive(:call).and_raise("google down") })
    get "/api/events"
    expect(last_response.status).to eq(502)
    expect(JSON.parse(last_response.body)).to eq("error" => "google down")
  end
end
