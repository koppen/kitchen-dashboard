# frozen_string_literal: true

require "json"
require "time"

module KitchenDashboard
  module Sources
    # Events from today and the next DAYS_AHEAD days from Google Calendar, read as the signed-in user (OAuth refresh token from
    # bin/google-auth). The same event seen on several calendars is merged; people are taken from
    # the calendar and the attendee list.
    class Events
      include Deps["http", "cache", "settings"]

      TTL = 5 * 60
      DAYS_AHEAD = 14 # the list shows the next events, however far off
      TOKEN_URL = "https://oauth2.googleapis.com/token"

      def call = cache.fetch(:events, TTL) { fetch }

      def stale? = (cache.age(:events) || Float::INFINITY) > 2 * TTL

      private

      def fetch
        bearer = "Bearer #{token}"
        from = Date.today.to_time
        to = (Date.today + DAYS_AHEAD).to_time
        seen = {}

        lists = Config::CALENDARS.map { |cal| Thread.new { [cal, items(cal, from, to, bearer)] } }.map(&:value)
        lists.each do |cal, items|
          items.each do |e|
            next if e["status"] == "cancelled"

            yes = Set.new(cal[:who])
            no = Set.new
            (e["attendees"] || []).each do |a|
              p = Config::PEOPLE.find { |_, person| person[:emails].include?(a["email"]) }&.first
              next unless p

              (a["responseStatus"] == "declined") ? no << p : yes << p
            end

            start = e["start"]["dateTime"] || e["start"]["date"]
            key = "#{e["iCalUID"] || e["id"]}|#{start}"
            if (prev = seen[key])
              prev[:yes].merge(yes)
              prev[:no].merge(no)
            else
              seen[key] = {
                title: e["summary"] || "(uden titel)",
                location: e["location"] || "",
                start:,
                end: e["end"]["dateTime"] || e["end"]["date"],
                all_day: e["start"].key?("date"),
                yes:, no:
              }
            end
          end
        end

        seen.values.filter_map do |e|
          yes, no = e.values_at(:yes, :no)
          who = Config::PEOPLE.filter_map do |initial, person|
            {initial:, color: person[:color]} if yes.include?(initial) && !no.include?(initial)
          end
          e.except(:yes, :no).merge(who:) if who.any?
        end
      end

      def items(cal, from, to, bearer)
        q = URI.encode_www_form(
          singleEvents: true, # expands recurring events
          orderBy: "startTime",
          maxResults: 100,
          timeMin: from.iso8601,
          timeMax: to.iso8601
        )
        url = "https://www.googleapis.com/calendar/v3/calendars/#{URI.encode_uri_component(cal[:id])}/events?#{q}"
        http.get_json(url, "authorization" => bearer)["items"] || []
      end

      # Access tokens are valid for an hour.
      def token
        cache.fetch(:google_token, 50 * 60) do
          creds = JSON.parse(settings.google_token || File.read(settings.google_token_file))
          http.post_form(TOKEN_URL, client_id: creds["client_id"], client_secret: creds["client_secret"],
            refresh_token: creds["refresh_token"], grant_type: "refresh_token")["access_token"]
        end
      end
    end
  end
end
