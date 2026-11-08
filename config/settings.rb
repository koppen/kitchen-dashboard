# frozen_string_literal: true

module KitchenDashboard
  class Settings < Hanami::Settings
    # OAuth client + refresh token written by bin/google-auth.
    setting :google_token_file, default: "./google-token.json"
    # Or the contents of that file (JSON), for hosts where only env vars are practical.
    setting :google_token, default: nil
  end
end
