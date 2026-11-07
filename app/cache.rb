# frozen_string_literal: true
# memoize: true

module KitchenDashboard
  # In-memory cache shared by the data sources. On upstream failure the last good value is
  # served rather than blanking the display.
  class Cache
    Entry = Data.define(:value, :at)

    def initialize
      @entries = {}
    end

    def fetch(key, ttl)
      entry = @entries[key]
      return entry.value if entry && clock - entry.at < ttl

      begin
        value = yield
      rescue
        raise unless entry
        return entry.value
      end
      @entries[key] = Entry.new(value, clock)
      value
    end

    # Seconds since the last successful fetch, nil if there never was one.
    def age(key)
      entry = @entries[key]
      entry && clock - entry.at
    end

    private

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
