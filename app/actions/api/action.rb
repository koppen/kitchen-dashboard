# auto_register: false
# frozen_string_literal: true

module KitchenDashboard
  module Actions
    module API
      # Serves a source as JSON; 502 if the upstream fails and nothing is cached.
      class Action < KitchenDashboard::Action
        def handle(request, response)
          response.format = :json
          response.body = JSON.generate(source.call)
        rescue => e
          logger.error("#{request.path}: #{e.message}")
          response.status = 502
          response.body = JSON.generate(error: e.message)
        end
      end
    end
  end
end
