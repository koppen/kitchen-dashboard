# auto_register: false
# frozen_string_literal: true

require "hanami/action"

module KitchenDashboard
  class Action < Hanami::Action
    include Deps["logger"]
  end
end
