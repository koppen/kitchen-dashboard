# frozen_string_literal: true

require "rack/utils"

module KitchenDashboard
  # Keeps the dashboard private when it is reachable from the internet: with DASHBOARD_KEY set,
  # opening any page with ?key=<key> once sets a long-lived cookie and redirects to the page without
  # it; requests without the cookie get a 404. Static files (script, manifest, icons) stay public.
  class KeyGate
    COOKIE = "dashboard_key"
    MAX_AGE = 10 * 365 * 24 * 3600

    def initialize(app, key)
      @app = app
      @key = key
    end

    def call(env)
      req = Rack::Request.new(env)
      if match?(req.GET["key"])
        query = Rack::Utils.build_query(req.GET.except("key"))
        headers = {"location" => req.path + (query.empty? ? "" : "?#{query}")}
        Rack::Utils.set_cookie_header!(headers, COOKIE,
          {value: @key, max_age: MAX_AGE, path: "/", secure: req.ssl?, httponly: true, same_site: :lax})
        return [302, headers, []]
      end
      return @app.call(env) if match?(req.cookies[COOKIE])

      [404, {"content-type" => "text/plain"}, ["Not found"]]
    end

    private

    def match?(given) = given.is_a?(String) && Rack::Utils.secure_compare(given, @key)
  end
end
