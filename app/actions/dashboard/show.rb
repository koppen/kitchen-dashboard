# frozen_string_literal: true

module KitchenDashboard
  module Actions
    module Dashboard
      class Show < KitchenDashboard::Action
        THEMES = %w[dark light].freeze # the first is the default
        THEME_MAX_AGE = 10 * 365 * 24 * 3600

        # ?theme=light switches to the light theme and remembers it in a cookie (an installed web app
        # starts at "/"), ?theme=dark switches back.
        def handle(request, response)
          theme = request.params[:theme]
          if THEMES.include?(theme)
            response.cookies["theme"] = {value: theme, max_age: THEME_MAX_AGE, path: "/"}
          else
            theme = request.cookies["theme"]
          end
          response.render(view, now: Time.now, theme: THEMES.include?(theme) ? theme : THEMES.first)
        end
      end
    end
  end
end
