# frozen_string_literal: true

require "json"
require "openssl"
require "time"

module KitchenDashboard
  module Sources
    # Today's events from Google Calendar, read with a service account. The same event seen on
    # several calendars is merged; people are taken from the calendar and the attendee list.
    class Events
      include Deps["http", "cache", "settings"]

      TTL = 5 * 60
      TOKEN_URL = "https://oauth2.googleapis.com/token"
      SCOPE = "https://www.googleapis.com/auth/calendar.readonly"

      def call = cache.fetch(:events, TTL) { fetch }

      def stale? = (cache.age(:events) || Float::INFINITY) > 2 * TTL

      private

      def fetch
        bearer = "Bearer #{token}"
        from = Date.today.to_time
        to = Time.now + 16 * 3600
        seen = {}

        lists = Config::CALENDARS.map { |cal| Thread.new { [cal, items(cal, from, to, bearer)] } }.map(&:value)
        lists.each do |cal, items|
          items.each do |e|
            next if e["status"] == "cancelled"

            yes = Set.new(cal[:who].chars)
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
                title: e["summary"] || "(no title)",
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

      # Tokens are valid for an hour.
      def token
        cache.fetch(:google_token, 50 * 60) do
          key = JSON.parse(File.read(settings.google_key_file))
          now = Time.now.to_i
          claims = {iss: key["client_email"], scope: SCOPE, aud: TOKEN_URL, iat: now, exp: now + 3600}
          unsigned = "#{b64(JSON.generate(alg: "RS256", typ: "JWT"))}.#{b64(JSON.generate(claims))}"
          sig = OpenSSL::PKey::RSA.new(key["private_key"]).sign("SHA256", unsigned)
          http.post_form(TOKEN_URL, grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: "#{unsigned}.#{b64(sig)}")["access_token"]
        end
      end

      def b64(s) = [s].pack("m0").tr("+/", "-_").delete("=")
    end
  end
end
