# frozen_string_literal: true

ENV["TZ"] ||= "Europe/Copenhagen"

require "hanami"
require_relative "dashboard"

module KitchenDashboard
  class App < Hanami::App
  end
end
