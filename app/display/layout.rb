# auto_register: false
# frozen_string_literal: true

module KitchenDashboard
  module Display
    # The page is 80 rem tall (scaled to the viewport), so the height left for the events list, and
    # with it how many events fit, is computed here. Keep in sync with the CSS in the layout.
    module Layout
      INNER = 80 - 2 * 1.4 # #app height minus padding
      GAP = 1.0
      WX = 8.0       # temperature + condition
      ALERTS = 4.4   # one row of alert tiles, only when there are any
      ALL_DAY = 3.6
      PRICES = 14.0  # price chart along the bottom

      def self.agenda_height(alerts:, all_day:)
        height = INNER - WX - GAP - PRICES - GAP
        height -= ALERTS + GAP if alerts.positive?
        height -= ALL_DAY + GAP if all_day
        height
      end
    end
  end
end
