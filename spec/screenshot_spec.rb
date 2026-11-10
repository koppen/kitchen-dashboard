# frozen_string_literal: true

RSpec.describe KitchenDashboard::Screenshot do
  subject(:screenshot) { described_class.new }

  it "thresholds to a 1-bit black and white PNG" do
    grey = ->(v) { ChunkyPNG::Color.rgb(v, v, v) }
    image = ChunkyPNG::Image.new(3, 1, [grey.(20), grey.(127), ChunkyPNG::Color.rgb(250, 210, 80)])
    allow(screenshot).to receive(:render).and_return(image.to_blob)

    png = screenshot.call("<html>", one_bit: true)
    expect(png.byteslice(24, 2).bytes).to eq([1, 0]) # IHDR: bit depth 1, greyscale
    expect(ChunkyPNG::Image.from_blob(png).pixels).to eq([ChunkyPNG::Color::BLACK, ChunkyPNG::Color::BLACK, ChunkyPNG::Color::WHITE])
  end
end
