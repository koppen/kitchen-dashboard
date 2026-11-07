# frozen_string_literal: true

module KitchenDashboard
  class Settings < Hanami::Settings
    # Google service account key. Share each calendar with its client_email ("See all event details").
    setting :google_key_file, default: "./service-account.json"
  end
end
