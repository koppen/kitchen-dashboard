# auto_register: false
# frozen_string_literal: true

module KitchenDashboard
  module Views
    module Helpers
      ICONS = {
        rain: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3C12 3 5 11 5 15a7 7 0 0 0 14 0C19 11 12 3 12 3z"/></svg>',
        sail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v14M12 4l7 11h-7M3 18h18l-3 3H6z"/></svg>',
        sun: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>'
      }.freeze

      def icon(kind) = raw(ICONS.fetch(kind))

      def avatar(person) = tag.div(person[:initial], class: "av", style: "background:#{person[:color]}")

      def rem(x) = "#{x.round(2)}rem"
    end
  end
end
