# frozen_string_literal: true

# Code reloading for `hanami server` / bin/dev.
group :server do
  guard "puma", port: ENV.fetch("PORT", 8080), environment: ENV.fetch("HANAMI_ENV", "development") do
    watch(%r{^(app|config|lib|slices)([\/][^\/]+)*.(rb|erb|haml|slim)$}i)
  end
end
