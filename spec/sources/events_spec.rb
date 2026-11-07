# frozen_string_literal: true

require "tmpdir"

RSpec.describe KitchenDashboard::Sources::Events do
  subject(:source) { described_class.new(http:, cache: KitchenDashboard::Cache.new, settings:) }

  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:key_file) do
    File.join(Dir.mktmpdir, "sa.json").tap do |path|
      File.write(path, JSON.generate(client_email: "sa@x.iam.gserviceaccount.com", private_key: rsa.private_to_pem))
    end
  end
  let(:settings) { double(google_key_file: key_file) }

  let(:day) { Date.today.to_time }
  let(:ymd) { Date.today.iso8601 }
  def at(h) = (day + h * 3600).iso8601

  let(:calendars) do
    {
      "jakob@example.com" => [
        {"id" => "1", "iCalUID" => "u1", "summary" => "Dinner", "start" => {"dateTime" => at(19)}, "end" => {"dateTime" => at(21)},
         "attendees" => [{"email" => "mette@example.com", "responseStatus" => "accepted"}]},
        {"id" => "2", "iCalUID" => "u2", "summary" => "Gone", "status" => "cancelled", "start" => {"dateTime" => at(9)}, "end" => {"dateTime" => at(10)}},
        {"id" => "3", "iCalUID" => "u3", "summary" => "Trip", "start" => {"date" => ymd}, "end" => {"date" => ymd}}
      ],
      "mette@example.com" => [
        {"id" => "1b", "iCalUID" => "u1", "summary" => "Dinner", "start" => {"dateTime" => at(19)}, "end" => {"dateTime" => at(21)}},
        {"id" => "4", "iCalUID" => "u4", "summary" => "Declined thing", "start" => {"dateTime" => at(12)}, "end" => {"dateTime" => at(13)},
         "attendees" => [{"email" => "mette@example.com", "responseStatus" => "declined"}]}
      ],
      "family@group.calendar.google.com" => [
        {"id" => "5", "iCalUID" => "u5", "summary" => "Nobody", "start" => {"dateTime" => at(15)}, "end" => {"dateTime" => at(16)}},
        {"id" => "6", "iCalUID" => "u6", "summary" => "Kids", "start" => {"dateTime" => at(16)}, "end" => {"dateTime" => at(17)},
         "attendees" => [{"email" => "jakob@example.com"}]}
      ]
    }
  end

  let(:http) do
    FakeHttp.new do |method, url, headers: {}, params: {}|
      case url
      when "https://oauth2.googleapis.com/token"
        header, claims, sig = params[:assertion].split(".")
        decode = ->(s) { (s + "=" * (-s.size % 4)).tr("-_", "+/").unpack1("m") }
        raise "bad signature" unless rsa.public_key.verify("SHA256", decode.(sig), "#{header}.#{claims}")
        expect(JSON.parse(decode.(claims))).to include("iss" => "sa@x.iam.gserviceaccount.com", "aud" => url)
        {"access_token" => "tok", "expires_in" => 3600}
      when %r{googleapis.com/calendar/v3/calendars/([^/]+)/events}
        raise "unauthorized" unless headers["authorization"] == "Bearer tok"
        {"items" => calendars.fetch(URI.decode_uri_component($1))}
      end
    end
  end

  it "merges events across calendars and maps people" do
    events = source.call
    summary = events.map { "#{it[:title]}#{" [all-day]" if it[:all_day]}: #{it[:who].map { |w| w[:initial] }.join}" }

    expect(summary).to contain_exactly("Dinner: JM", "Trip [all-day]: J", "Kids: J")
    expect(events.find { it[:title] == "Dinner" }).to include(start: at(19), end: at(21), location: "")
    expect(events.first[:who].first).to eq(initial: "J", color: "#7FA4FF")
  end

  it "caches the token and the events" do
    2.times { source.call }
    expect(http.calls.count { it.include?("oauth2") }).to eq(1)
    expect(http.calls.count { it.include?("/calendar/") }).to eq(3)
  end
end
