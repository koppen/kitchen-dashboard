# frozen_string_literal: true

module KitchenDashboard
  module Actions
    module API
      class Weather < KitchenDashboard::Actions::API::Action
        include Deps[source: "sources.weather"]
      end
    end
  end
end
