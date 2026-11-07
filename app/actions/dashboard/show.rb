# frozen_string_literal: true

module KitchenDashboard
  module Actions
    module Dashboard
      class Show < KitchenDashboard::Action
        def handle(request, response)
          response.render(view, now: Time.now)
        end
      end
    end
  end
end
