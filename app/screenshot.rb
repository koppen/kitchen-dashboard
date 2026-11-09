# frozen_string_literal: true

require "ferrum"

module KitchenDashboard
  # Renders a page's HTML to a PNG with headless Chrome (for e-ink displays like TRMNL, which show images).
  # Chrome is found on the PATH or in its usual install locations; BROWSER_PATH points Ferrum elsewhere.
  # A fresh browser per call: slow (about a second) but nothing to keep alive between the display's polls.
  class Screenshot
    SIZE = [480, 800].freeze

    def call(html)
      browser = Ferrum::Browser.new(window_size: SIZE, timeout: 15)
      browser.resize(width: SIZE[0], height: SIZE[1]) # the window size includes browser chrome
      browser.content = html
      browser.network.wait_for_idle(timeout: 5) # web font
      browser.screenshot(encoding: :binary, format: "png")
    ensure
      browser&.quit
    end
  end
end
