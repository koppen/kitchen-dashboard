# auto_register: false
# frozen_string_literal: true

module KitchenDashboard
  module Display
    # The page is a fixed 48x80 rem canvas (scaled to the viewport), so the timeline height, and
    # with it the number of hour rows, is computed here. Keep in sync with the CSS in the layout.
    module Layout
      INNER = 80 - 2 * 1.4 # #app height minus padding
      GAP = 1.0
      WX_MIN = 14.0
      ALERT = 4.4
      ALERT_GAP = 0.6
      ALL_DAY = 3.6
      HEADS = 1.2

      def self.timeline_height(alerts:, all_day:)
        wx = [WX_MIN, alerts * ALERT + [alerts - 1, 0].max * ALERT_GAP].max
        height = INNER - wx - GAP - HEADS - GAP
        height -= ALL_DAY + GAP if all_day
        height
      end
    end
  end
end
