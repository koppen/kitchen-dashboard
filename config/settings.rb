# frozen_string_literal: true

module KitchenDashboard
  class Settings < Hanami::Settings
    # OAuth client + refresh token written by bin/google-auth.
    setting :google_token_file, default: "./google-token.json"
  end
end
