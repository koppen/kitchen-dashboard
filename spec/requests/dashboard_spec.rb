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
    expect(body).to include('<div class="temp">9°</div>', "Overskyet", "Solcreme", "HELE DAGEN", "School trip", "Dinner at Mormor", "STRØMPRIS")
    expect(body).not_to include("Already over", "forældet:")
    expect(body.scan(/class="ev[ "]/).size).to eq(3) # "Already over" and the all-day event aren't rows
    expect(body).to include('class="ev now"')
    expect(body.scan('class="slot"').size).to eq(24)
    expect(body.scan('class="hour ').size).to eq(12)
  end

  it "renders what it has when a source fails" do
    container.stub("sources.weather", double(call: nil, stale?: true).tap { allow(it).to receive(:call).and_raise("down") })
    get "/"
    expect(last_response).to be_ok
    expect(last_response.body).to include("forældet: vejr", "Dinner at Mormor")
    expect(last_response.body).to include("STRØMPRIS")
  end

  it "includes the boot id so open pages reload after a restart" do
    get "/"
    expect(last_response.body).to include(%(<meta name="boot-id" content="#{KitchenDashboard::App::BOOT_ID}">))
  end

  it "keeps the client script out of the page, where the CSP would block it" do
    get "/"
    expect(last_response.body).not_to match(/<script>/)
    expect(last_response.body).to include(%(<script src="/app.js?v=#{KitchenDashboard::App::BOOT_ID}"></script>))
    expect(last_response.headers["content-security-policy"]).to include("script-src 'self'", "manifest-src 'self'", "font-src 'self' https://fonts.gstatic.com")

    get "/app.js"
    expect(last_response).to be_ok
    expect(last_response.body).to include("setInterval(refresh, 60e3)")
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
