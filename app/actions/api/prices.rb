# frozen_string_literal: true

module KitchenDashboard
  module Actions
    module API
      class Prices < KitchenDashboard::Actions::API::Action
        include Deps[source: "sources.prices"]
      end
    end
  end
end
