# frozen_string_literal: true

ENV["TZ"] ||= "Europe/Copenhagen"

require "hanami"
require "rack/static"
require "rack/mime"
require_relative "../lib/kitchen_dashboard/key_gate"

# Household config: HOUSEHOLD (the contents of a household.rb, for hosts where only env vars are
# practical), else config/household.rb, else the example.
if ENV["HOUSEHOLD"]
  eval(ENV["HOUSEHOLD"], TOPLEVEL_BINDING, "HOUSEHOLD") # standard:disable Security/Eval
else
  require_relative File.exist?(File.join(__dir__, "household.rb")) ? "household" : "household.example"
end

module KitchenDashboard
  class App < Hanami::App
    # Changes on every server start; the page reloads itself fully when it sees a new one.
    BOOT_ID = Time.now.to_i.to_s

    Rack::Mime::MIME_TYPES[".webmanifest"] = "application/manifest+json"
    config.middleware.use Rack::Static, urls: ["/app.js", "/manifest.webmanifest", "/icons"], root: "public"
    config.middleware.use KeyGate, ENV["DASHBOARD_KEY"] if ENV["DASHBOARD_KEY"]

    # Hanami's default CSP blocks the manifest and Google Fonts; the client script is in public/app.js
    # because inline scripts are blocked too.
    config.actions.content_security_policy[:manifest_src] = "'self'"
    config.actions.content_security_policy[:font_src] = "'self' https://fonts.gstatic.com"
  end
end
