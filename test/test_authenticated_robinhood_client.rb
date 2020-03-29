require "minitest/autorun"

require_relative "support/vcr_setup"
require_relative "../lib/robinhood_client"

class AuthenticatedRobinhoodClientTest < Minitest::Test

  def setup
    skip "Skip over authenticated tests on CI because the VCRs aren't checked into source" unless ENV["RUN_AUTHENTICATED_TESTS"]

    @client = RobinhoodClient.new(jwt: ENV["RH_JWT"] || "")

    VCR.configure do |config|
      config.filter_sensitive_data('<JWT_TOKEN>') { @client.access_token }
      config.cassette_library_dir = "test/authenticated_vcr_cassettes"
    end

  end

  def test_place_buy_order_for_stock
    VCR.use_cassette("place_buy_order_for_stock", match_requests_on: [:method, :uri, :body]) do
      placed_order = @client.place_order("buy", "FB", "5", "161.50", dry_run: false)
      orders = @client.orders(last: "1")
      assert placed_order
      assert_equal "queued", orders.first["state"]
      assert_equal "limit", orders.first["type"]
      assert_equal "161.50000000", orders.first["price"]
      assert_equal "buy", orders.first["side"]
      assert_equal "5.00000", orders.first["quantity"]
    end
  end

  def test_cancel_single_stock_order
    VCR.use_cassette("cancel_single_stock_order", match_requests_on: [:method, :uri, :body]) do
      placed_order = @client.place_order("buy", "FB", "3", "76.50", dry_run: false)
      assert placed_order

      most_recent_order = @client.orders(last: "1").first

      cancelled = @client.cancel_stock_order(most_recent_order["id"])
      assert cancelled

      cancelled_order = @client.order(most_recent_order["id"])

      assert_equal "cancelled", cancelled_order["state"]
      assert_equal "limit", cancelled_order["type"]
      assert_equal "76.50000000", cancelled_order["price"]
      assert_equal "buy", cancelled_order["side"]
      assert_equal "3.00000", cancelled_order["quantity"]
    end
  end

  def test_cancel_all_stock_orders
    VCR.use_cassette("cancel_all_stock_orders", match_requests_on: [:method, :uri, :body]) do
      @client.place_order("buy", "FB", "5", "130.50", dry_run: false)
      @client.place_order("buy", "SNAP", "50", "8.50", dry_run: false)
      num_cancelled = @client.cancel_all_open_stock_orders
      assert_equal 2, num_cancelled
    end
  end

  def test_get_option_quote
    VCR.use_cassette("get_option_quote", match_requests_on: [:method, :uri, :body]) do
      chain_id, expirations = @client.get_chain_and_expirations("fb")
      valid_expirations = %w[2018-09-21 2018-09-28 2018-10-05 2018-10-12 2018-10-19 2018-10-26 2018-11-02 2018-11-16 2018-12-21 2019-01-18 2019-03-15 2019-06-21 2019-12-20 2020-01-17 2020-06-19]
      valid_expirations.each do |valid_expiration|
        assert expirations.include?(valid_expiration)
      end
      assert_equal "c5a11b65-4c5b-4501-99ba-932f203effbf", chain_id

      instruments = @client.get_option_instruments("call", expirations.first, chain_id)
      assert_equal "138.0000", instruments.first["strike_price"]
      assert_equal "2018-09-21", instruments.first["expiration_date"]
      assert_equal "call", instruments.first["type"]
      assert_equal "https://api.robinhood.com/options/instruments/2bd001e1-cad0-4ef9-b711-15bc59f44230/", instruments.first["url"]
      assert_equal "80.0000", instruments.last["strike_price"]
      assert_equal "2018-09-21", instruments.last["expiration_date"]
      assert_equal  "call", instruments.last["type"]
      assert_equal "https://api.robinhood.com/options/instruments/67334499-20ef-46d2-85fd-ff338050e6a1/", instruments.last["url"]

      option_quote = @client.get_option_quote_by_id(instruments.first["id"])
      assert_equal "24.700000", option_quote["ask_price"]
      assert_equal 39, option_quote["ask_size"]
      assert_equal "24.050000", option_quote["bid_price"]
      assert_equal 104, option_quote["bid_size"]
      assert_equal "https://api.robinhood.com/options/instruments/2bd001e1-cad0-4ef9-b711-15bc59f44230/", option_quote["instrument"]
      assert_equal "0.967615", option_quote["delta"]
    end
  end

  def test_cancel_all_option_orders
    VCR.use_cassette("cancel_all_option_orders", match_requests_on: [:method, :uri, :body]) do
      number_cancelled = @client.cancel_all_open_option_orders
      assert_equal number_cancelled, 2
    end
  end

  def test_cancel_single_option_order
    VCR.use_cassette("cancel_single_option_order", match_requests_on: [:method, :uri, :body_without_random_ref_id]) do
      chain_id, expirations = @client.get_chain_and_expirations("fb")

      instruments = @client.get_option_instruments("call", expirations.first, chain_id)
      instrument = instruments.first
      instrument_url = instrument["url"]

      order_placed = @client.place_option_order(instrument_url, "2", "1.25", dry_run: false)

      most_recent_order = @client.option_orders(last: "1").first

      cancelled = @client.cancel_option_order(most_recent_order["id"])
      assert cancelled
    end
  end

  def test_place_option_order
    VCR.use_cassette("place_option_order", match_requests_on: [:method, :uri, :body_without_random_ref_id]) do
      chain_id, expirations = @client.get_chain_and_expirations("fb")

      instruments = @client.get_option_instruments("call", expirations.first, chain_id)
      instrument = instruments.first
      instrument_url = instrument["url"]

      order_placed = @client.place_option_order(instrument_url, "2", "1.25", dry_run: false)
      assert order_placed
    end
  end

  def test_get_most_recent_option_order
    VCR.use_cassette("get_most_recent_option_order", match_requests_on: [:method, :uri, :body]) do
      orders = @client.option_orders(last: "1")
      assert_equal 1, orders.length
      assert_equal "long_call", orders.first["opening_strategy"]
      assert_equal  "FB", orders.first["chain_symbol"]
      assert_equal "2.00000", orders.first["quantity"]
      assert_equal "queued", orders.first["state"]
      assert_equal 1, orders.first["legs"].length
    end
  end

  def test_get_stock_orders
    VCR.use_cassette("get_stock_orders", match_requests_on: [:method, :uri, :body]) do

      orders_by_symbol = @client.orders(symbol: "SNAP")
      assert_equal 12, orders_by_symbol.length

      orders_by_symbol_and_last = @client.orders(symbol: "SNAP", last: "5")
      assert_equal 5, orders_by_symbol_and_last.length
    end
  end

end
