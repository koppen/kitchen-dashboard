# frozen_string_literal: true

# Stands in for KitchenDashboard::HTTP: routes requests to a block by URL.
class FakeHttp
  attr_reader :calls

  def initialize(&handler)
    @handler = handler
    @calls = []
  end

  def get_json(url, headers = {}) = call(:get, url, headers:)

  def post_form(url, params) = call(:post, url, params:)

  private

  def call(method, url, **opts)
    @calls << url
    @handler.(method, url, **opts)
  end
end
