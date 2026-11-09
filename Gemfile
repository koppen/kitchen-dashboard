# frozen_string_literal: true

source "https://rubygems.org"

gem "hanami", "~> 3.0.0"
gem "hanami-action", "~> 3.0.0"
gem "hanami-router", "~> 3.0.0"
gem "hanami-view", "~> 3.0.0"

gem "dry-types", "~> 1.7"
gem "ferrum"
gem "puma", ">= 7.1"
gem "rake"

group :development do
  gem "hanami-webconsole", "~> 3.0.0"
end

group :development, :test do
  gem "dotenv"
end

group :cli, :development do
  gem "hanami-reloader", "~> 3.0.0"
end

group :cli, :development, :test do
  gem "hanami-rspec", "~> 3.0.0"
end

group :test do
  gem "rack-test"
end
