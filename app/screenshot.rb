# frozen_string_literal: true

require "chunky_png"
require "ferrum"

module KitchenDashboard
  # Renders a page's HTML to a PNG with headless Chrome (for e-ink displays like TRMNL, which show images).
  # Chrome is found on the PATH or in its usual install locations; BROWSER_PATH points Ferrum elsewhere.
  # A fresh browser per call: slow (about a second) but nothing to keep alive between the display's polls.
  class Screenshot
    SIZE = [480, 800].freeze
    THRESHOLD = 128 # one_bit: grey levels below this become black

    def call(html, one_bit: false)
      png = render(html)
      one_bit ? threshold(png) : png
    end

    private

    def render(html)
      browser = Ferrum::Browser.new(window_size: SIZE, timeout: 15)
      browser.resize(width: SIZE[0], height: SIZE[1]) # the window size includes browser chrome
      browser.content = html
      browser.network.wait_for_idle(timeout: 5) # web font
      browser.screenshot(encoding: :binary, format: "png")
    ensure
      browser&.quit
    end

    # Black and white only, as a 1-bit greyscale PNG (antialiased edges and emoji are thresholded).
    def threshold(png)
      image = ChunkyPNG::Image.from_blob(png)
      black, white = ChunkyPNG::Color::BLACK, ChunkyPNG::Color::WHITE
      image.pixels.map! { ChunkyPNG::Color.grayscale_teint(it) < THRESHOLD ? black : white }
      image.to_blob(color_mode: ChunkyPNG::COLOR_GRAYSCALE, bit_depth: 1)
    end
  end
end
