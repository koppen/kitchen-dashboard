# frozen_string_literal: true

module KitchenDashboard
  module Actions
    module Dashboard
      class Show < KitchenDashboard::Action
        include Deps["screenshot"]

        THEMES = %w[dark light eink].freeze # the first is the default
        THEME_MAX_AGE = 10 * 365 * 24 * 3600

        # ?theme=light or ?theme=eink (black and white only) switches theme and remembers it in a cookie
        # (an installed web app starts at "/"); ?theme=dark switches back. ?format=png renders the page as an image instead.
        def handle(request, response)
          theme = request.params[:theme]
          if THEMES.include?(theme)
            response.cookies["theme"] = {value: theme, max_age: THEME_MAX_AGE, path: "/"}
          else
            theme = request.cookies["theme"]
          end
          response.render(view, now: Time.now, theme: THEMES.include?(theme) ? theme : THEMES.first)
          return unless request.params[:format] == "png"

          response.body = screenshot.call(response.body.join, one_bit: theme == "eink")
          response.headers["Content-Type"] = "image/png"
        end
      end
    end
  end
end
