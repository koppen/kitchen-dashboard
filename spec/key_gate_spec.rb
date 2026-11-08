# frozen_string_literal: true

require "rack/test"

RSpec.describe KitchenDashboard::KeyGate do
  include Rack::Test::Methods

  let(:app) { described_class.new(->(_) { [200, {}, ["dashboard"]] }, "s3cret") }

  it "hides everything without the key" do
    get "/"
    expect(last_response.status).to eq(404)
    get "/api/events", key: "wrong"
    expect(last_response.status).to eq(404)
  end

  it "sets a cookie for the key and redirects to the page without it" do
    get "/", key: "s3cret", x: "1"
    expect(last_response.status).to eq(302)
    expect(last_response.headers["location"]).to eq("/?x=1")
    expect(last_response.headers["set-cookie"]).to include("dashboard_key=s3cret", "httponly", "max-age=315360000")

    get "/"
    expect(last_response.body).to eq("dashboard")
  end
end
