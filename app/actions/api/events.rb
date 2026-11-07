# frozen_string_literal: true

module KitchenDashboard
  module Actions
    module API
      class Events < KitchenDashboard::Actions::API::Action
        include Deps[source: "sources.events"]
      end
    end
  end
end
