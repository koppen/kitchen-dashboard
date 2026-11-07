# frozen_string_literal: true

module KitchenDashboard
  class Routes < Hanami::Routes
    root to: "dashboard.show"

    get "/api/events", to: "api.events"
    get "/api/weather", to: "api.weather"
    get "/api/prices", to: "api.prices"
  end
end
