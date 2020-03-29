require "net/http"
require "json"

module HttpHelpers

  # Make a GET request
  #
  # @param url [String] URL to make the request to
  # @param headers [Hash] Headers to add to the request
  # @param params [Hash] Parameters to add to the request
  # @return [Net::HTTP] The response of the request
  def self.get(url, headers: {}, params: {})
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(params) unless params.empty?
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    headers.each do |key, value|
      request[key] = value
    end
    response = http.request(request)
    response
  end

  # Make a POST request
  #
  # @param url [String] URL to make the request to
  # @param headers [Hash] Headers to add to the request
  # @param body [Hash] Parameters to add to the request
  # @return [Net::HTTP] The response of the request
  def self.post(url, headers, body)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri)
    headers.each do |key, value|
      request[key] = value
    end
    request.body = body.to_json
    response = http.request(request)
    response
  end
end
