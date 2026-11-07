# frozen_string_literal: true

require "json"
require "net/http"

module KitchenDashboard
  class HTTP
    Error = Class.new(StandardError)

    def get_json(url, headers = {})
      uri = URI(url)
      request(uri, Net::HTTP::Get.new(uri, headers))
    end

    def post_form(url, params)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(params)
      request(uri, req)
    end

    private

    def request(uri, req)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) do
        it.request(req)
      end
      raise Error, "#{uri.host}#{uri.path} -> #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end
  end
end
