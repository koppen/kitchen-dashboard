# frozen_string_literal: true

# Example household configuration. Copy to config/household.rb (gitignored) and fill in your own;
# without it the app boots with these placeholders (as the specs do).
module KitchenDashboard
  module Config
    # Home, used for the weather.
    LAT = 55.68
    LON = 12.57

    # DK1 = west of Storebælt, DK2 = east.
    PRICE_AREA = "DK2"

    # Supplier markup on the spot price, kr/kWh ex VAT, for the hour starting at t.
    MARKUP = ->(t) { 0.05 }
    VAT = 1.25

    # Per-kWh charges from the DataHub price list (Energi Data Service DatahubPricelist), as
    # [GLN, charge type code]. The grid company's GLN and tariff code are on your invoice or in
    # the price list; the Energinet ones are the same for everyone.
    TARIFFS = [
      ["<grid company GLN>", "<tariff code>"], # grid company: time-of-day tariff
      ["5790000432752", "40000"],  # Energinet: transmission nettarif
      ["5790000432752", "41000"],  # Energinet: systemtarif
      ["5790000432752", "EA-001"]  # elafgift
    ].freeze

    # One entry per family member. The key is the initial(s) shown in the avatar.
    PEOPLE = {
      "A" => {color: "#7FA4FF", emails: ["alex@example.com"]},
      "B" => {color: "#FF8CC6", emails: ["bo@example.com"]},
      "C" => {color: "#9ADB6B", emails: []}
    }.freeze

    # Calendars to read. `who` = people an event on that calendar belongs to by default.
    # Invitees found in an event's attendee list (matched by PEOPLE emails) are added, and
    # anyone who declined is removed.
    CALENDARS = [
      {id: "alex@example.com", who: %w[A]},
      {id: "bo@example.com", who: %w[B]},
      {id: "<id>@group.calendar.google.com", who: %w[C]},
      {id: "<family id>@group.calendar.google.com", who: %w[A B C]}
    ].freeze
  end
end
