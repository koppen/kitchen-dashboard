# frozen_string_literal: true

require "tmpdir"

RSpec.describe KitchenDashboard::Sources::Events do
  subject(:source) { described_class.new(http:, cache: KitchenDashboard::Cache.new, settings:) }

  let(:token_file) do
    File.join(Dir.mktmpdir, "google-token.json").tap do |path|
      File.write(path, JSON.generate(client_id: "cid", client_secret: "secret", refresh_token: "refresh"))
    end
  end
  let(:settings) { double(google_token_file: token_file, google_token: nil) }

  before do
    stub_const("KitchenDashboard::Config::PEOPLE", {
      "J" => {color: "#7FA4FF", emails: ["jakob@example.com"]},
      "M" => {color: "#FF9B63", emails: ["mette@example.com"]}
    })
    stub_const("KitchenDashboard::Config::CALENDARS", [
      {id: "jakob@example.com", who: %w[J]},
      {id: "mette@example.com", who: %w[M]},
      {id: "family@group.calendar.google.com", who: []}
    ])
  end

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
        expect(params).to eq(client_id: "cid", client_secret: "secret", refresh_token: "refresh", grant_type: "refresh_token")
        {"access_token" => "tok", "expires_in" => 3599}
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

  it "takes the token from the GOOGLE_TOKEN setting instead of the file when given" do
    allow(settings).to receive_messages(google_token: File.read(token_file), google_token_file: "/nonexistent")
    expect(source.call.size).to eq(3)
  end

  it "caches the token and the events" do
    2.times { source.call }
    expect(http.calls.count { it.include?("oauth2") }).to eq(1)
    expect(http.calls.count { it.include?("/calendar/") }).to eq(3)
  end
end
