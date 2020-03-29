require "minitest/autorun"

require_relative "support/vcr_setup"
require_relative "../lib/robinhood_client"

class UnauthenticatedRobinhoodClientTest < Minitest::Test
  def setup
    @client = RobinhoodClient.new(unauthenticated: true)

    VCR.configure do |config|
      config.cassette_library_dir = "test/unauthenticated_vcr_cassettes"
    end

  end

  def test_quote
    VCR.use_cassette("quote", match_requests_on: [:method, :uri, :body]) do
      quote = @client.quote("fb")
      assert_equal "161.420000", quote["ask_price"]
      assert_equal 200, quote["ask_size"]
      assert_equal "161.330000", quote["bid_price"]
      assert_equal 10300, quote["bid_size"]
      assert_equal "161.360000", quote["last_trade_price"]
    end
  end

  def test_get_option_expirations_and_instruments
    VCR.use_cassette("get_option_expirations_and_instruments", match_requests_on: [:method, :uri, :body]) do
      chain_id, expirations = @client.get_chain_and_expirations("fb")
      valid_expirations = %w[2018-09-21 2018-09-28 2018-10-05 2018-10-12 2018-10-19 2018-10-26 2018-11-02 2018-11-16 2018-12-21 2019-01-18 2019-03-15 2019-06-21 2019-12-20 2020-01-17 2020-06-19]
      valid_expirations.each do |valid_expiration|
        assert expirations.include?(valid_expiration)
      end
      assert_equal chain_id, "c5a11b65-4c5b-4501-99ba-932f203effbf"

      instruments = @client.get_option_instruments("call", expirations.first, chain_id)
      assert_equal "138.0000", instruments.first["strike_price"]
      assert_equal "2018-09-21", instruments.first["expiration_date"]
      assert_equal "call", instruments.first["type"]
      assert_equal "https://api.robinhood.com/options/instruments/2bd001e1-cad0-4ef9-b711-15bc59f44230/", instruments.first["url"]
      assert_equal "80.0000", instruments.last["strike_price"]
      assert_equal "2018-09-21", instruments.last["expiration_date"]
      assert_equal "call", instruments.last["type"]
      assert_equal "https://api.robinhood.com/options/instruments/67334499-20ef-46d2-85fd-ff338050e6a1/", instruments.last["url"]
    end
  end

end
