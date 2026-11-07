# frozen_string_literal: true

bind "tcp://#{ENV.fetch("HOST", "0.0.0.0")}:#{ENV.fetch("PORT", 8080)}"
environment ENV.fetch("HANAMI_ENV", "development")
threads 1, Integer(ENV.fetch("HANAMI_MAX_THREADS", 5))
