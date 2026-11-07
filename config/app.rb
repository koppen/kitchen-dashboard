# frozen_string_literal: true

ENV["TZ"] ||= "Europe/Copenhagen"

require "hanami"
require "rack/static"
require "rack/mime"
require_relative "dashboard"

module KitchenDashboard
  class App < Hanami::App
    Rack::Mime::MIME_TYPES[".webmanifest"] = "application/manifest+json"
    config.middleware.use Rack::Static, urls: ["/manifest.webmanifest", "/icons"], root: "public"
  end
end
