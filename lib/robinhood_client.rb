require_relative "helpers/http_helpers"
require_relative "helpers/table"
require_relative "../initializers/string"

require "time"
require "fileutils"
require "cgi"
require "securerandom"
require "io/console"

class RobinhoodClient

  # Route that takes credentials and returns a JWT and refresh token
  ROBINHOOD_OAUTH_TOKEN_ROUTE           = "https://api.robinhood.com/oauth2/token/".freeze
  # Route to refresh a JWT
  ROBINHOOD_TOKEN_REFRESH_ROUTE         = "https://api.robinhood.com/oauth2/token/"
  # Route that returns info about the authenticated user
  ROBINHOOD_USER_ROUTE                  = "https://api.robinhood.com/user/".freeze
  # Route that returns info about the authenticated user's account
  ROBINHOOD_ACCOUNTS_ROUTE              = "https://api.robinhood.com/accounts/".freeze
  # Route that returns authenticated user's order history
  ROBINHOOD_ORDERS_ROUTE                = "https://api.robinhood.com/orders/".freeze
  # Route to fetch the authenticated user's default watchlist
  ROBINHOOD_DEFAULT_WATCHLIST           = "https://api.robinhood.com/watchlists/Default/".freeze
  # Route to fetch the authenticated user's option positions
  ROBINHOOD_OPTIONS_POSITIONS_ROUTE     = "https://api.robinhood.com/options/positions/".freeze
  # Route to get a quote for an option ID
  ROBINHOOD_OPTION_QUOTE_ROUTE          = "https://api.robinhood.com/marketdata/options/".freeze
  # Route to place option orders
  ROBINHOOD_OPTION_ORDER_ROUTE          = "https://api.robinhood.com/options/orders/".freeze

  # Route to get a quote for a given symbol
  ROBINHOOD_QUOTE_ROUTE             = "https://api.robinhood.com/quotes/".freeze
  # Route to get fundamentals for a given symbol
  ROBINHOOD_FUNDAMENTALS_ROUTE      = "https://api.robinhood.com/fundamentals/".freeze
  # Route to get historical data for a given symbol
  ROBINHOOD_HISTORICAL_QUOTE_ROUTE  = "https://api.robinhood.com/quotes/historicals/".freeze
  # Route to get top moving symbols for the day
  ROBINHOOD_TOP_MOVERS_ROUTE        = "https://api.robinhood.com/midlands/movers/sp500/".freeze
  # Route to get news related to a given symbol
  ROBINHOOD_NEWS_ROUTE              = "https://api.robinhood.com/midlands/news/".freeze
  # Route to get past and future earnings for a symbol
  ROBINHOOD_EARNINGS_ROUTE          = "https://api.robinhood.com/marketdata/earnings/".freeze
  # Route to get an instrument
  ROBINHOOD_INSTRUMENTS_ROUTE       = "https://api.robinhood.com/instruments/".freeze
  # Route to get option instruments
  ROBINHOOD_OPTION_INSTRUMENT_ROUTE = "https://api.robinhood.com/options/instruments/".freeze
  # Route to get an option chain by ID
  ROBINHOOD_OPTION_CHAIN_ROUTE      = "https://api.robinhood.com/options/chains/".freeze

  # Status signifying credentials were invalid
  INVALID         = "INVALID".freeze
  # Status signifying the credentials were correct but an MFA code is required
  MFA_REQUIRED    = "MFA_REQUIRED".freeze
  # Status signifying valid
  SUCCESS         = "SUCCESS".freeze

  # Constant signifying how long the JWT should last before expiring
  DEFAULT_EXPIRES_IN  = 3600.freeze
  # The OAuth client ID to use. (the same one the Web client uses)
  DEFAULT_CLIENT_ID   = "c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS".freeze
  # The scope of the JWT
  DEFAULT_SCOPE       = "internal".freeze

  # Create a new RobinhoodClient instance
  #
  # @param username [String] Username of the account
  # @param password [String] Password of the account
  # @param mfa_code [String] MFA code (if applicable)
  # @return [RobinhoodClient] New instance of the RobinhoodClient class
  # @example
  #   RobinhoodClient.new(username: "username", password: "password", mfa_code: "mfa_code")
  def initialize(username: nil, password: nil, mfa_code: nil, unauthenticated: false, jwt: nil)

    return if unauthenticated

    @access_token = jwt
    return if jwt

    body = {}
    body["username"] = username
    body["password"] = password
    body["mfa_code"] = mfa_code if mfa_code
    body["grant_type"] = "password"
    body["scope"] = DEFAULT_SCOPE
    body["client_id"] = DEFAULT_CLIENT_ID
    body["expires_in"] = DEFAULT_EXPIRES_IN
    body["device_token"] = SecureRandom.uuid

    response = post(ROBINHOOD_OAUTH_TOKEN_ROUTE, body)
    json_response = JSON.parse(response.body)

    if response.code == "400"
      @authentication_status = INVALID
    elsif response.code == "200" && json_response["mfa_required"]
      @authentication_status = MFA_REQUIRED
    elsif response.code == "200"
      @authentication_status = SUCCESS
      @access_token = json_response["access_token"]
      @refresh_token = json_response["refresh_token"]
      @expires_in = json_response["expires_in"]
      @last_refreshed_at = Time.now.to_i
      Thread.abort_on_exception = true
      Thread.new { token_refresh() }
    else
      raise "Received an unexpected response when logging in: #{response.code} - #{response.body}"
    end

  end

  # Create a new RobinhoodClient instance by prompting for user input
  #
  # @return [RobinhoodClient] New instance of the RobinhoodClient class
  # @example
  #   my_new_client = RobinhoodClient.interactively_create_client
  def self.interactively_create_client
    print "Enter your username: "
    username = gets.chomp
    print "Password: "
    password = STDIN.noecho(&:gets).chomp

    client = RobinhoodClient.new(username: username, password: password)
    if client.authentication_status == RobinhoodClient::SUCCESS
      return client
    elsif client.authentication_status == RobinhoodClient::MFA_REQUIRED
      print "\nMFA code: "
      mfa_code = STDIN.noecho(&:gets).chomp
      client = RobinhoodClient.new(username: username, password: password, mfa_code: mfa_code)
      if client.authentication_status == RobinhoodClient::SUCCESS
        return client
      else
        puts "\nInvalid credentials."
        exit 1
      end
    else
      puts "\nInvalid credentials."
      exit 1
    end
  rescue Interrupt
    puts "\nExiting..."
    exit 1
  end

  # Checks if the JWT currently stored is close to expiring (< 30 seconds TTL) and fetches a new one with the refresh token if so
  #
  # @note This is spawned in its own thread whenever a new instance of RobinhoodClient is created.
  #   You shouldn't have to manually call this method.
  #
  # @example
  #    Thread.abort_on_exception = true
  #    Thread.new { token_refresh() }
  def token_refresh
    begin
      loop do

        # Sleep unless there's less than 60 seconds until expiration
        time_left = (@last_refreshed_at + @expires_in) - Time.now.to_i
        if time_left > 60
          sleep 10
        else
          params = {}
          params["grant_type"] = "refresh_token"
          params["scope"] = DEFAULT_SCOPE
          params["expires_in"] = DEFAULT_EXPIRES_IN
          params["client_id"] = DEFAULT_CLIENT_ID
          params["device_token"] = "caec6972-daf7-4d41-a1d7-56cc6b293bfb"
          params["refresh_token"] = @refresh_token

          response = post(ROBINHOOD_TOKEN_REFRESH_ROUTE, params)

          if response.code == "200"
            json_response = JSON.parse(response.body)
            @access_token = json_response["access_token"]
            @refresh_token = json_response["refresh_token"]
            @expires_in = json_response["expires_in"]
            @last_refreshed_at = Time.now.to_i
          else
            # This should never happen, let's raise an error
            raise "Error refreshing JWT."
          end
        end
      end
    rescue SocketError
      raise "Error refreshing token: Check your internet connection."
    end
  end

  # Checks if the user is signed in with a valid auth token
  #
  # @return [Boolean] Whether or not the token was valid
  #
  # @example
  #   if @client.logged_in?
  #     // do something authenticated
  def logged_in?
    get(ROBINHOOD_USER_ROUTE).code == "200"
  end

  # Returns information about the currently authenticated user
  #
  # @return [String] User info in pretty JSON form
  #
  # @example
  #   @client.user
  def user
    get(ROBINHOOD_USER_ROUTE, return_as_json: true)
  end

  # Returns information about the currently authenticated user's account
  #
  # @return [String] Account info in pretty JSON form
  #
  # @example
  #   @client.accounts
  def accounts
    get(ROBINHOOD_ACCOUNTS_ROUTE, return_as_json: true)
  end

  # Get an order by ID
  #
  # @param id [String] The ID of the order to get
  # @return [Hash] The order
  def order(id)
    get("#{ROBINHOOD_ORDERS_ROUTE}#{id}/", return_as_json: true)
  end

  # Get an option order by ID
  #
  # @param id [String] The ID of the option order to get
  # @return [Hash] The order
  def option_order(id)
    get("#{ROBINHOOD_OPTION_ORDER_ROUTE}#{id}/", return_as_json: true)
  end

  # View past orders
  #
  # @param days [String] Limit to orders within the last N days
  # @param symbol [String] Limit to orders for a certain symbol
  # @param last [String] Limit to last N orders
  # @return [String] Past orders in table form.
  # @example
  #   @client.orders(days: "5", symbol: "FB")
  def orders(days: nil, symbol: nil, last: nil)
    params = {}
    if days
      days_ago = (Time.now - (days.to_i*24*60*60)).utc.iso8601
      params["updated_at[gte]"] = days_ago
    end
    if symbol
      params["instrument"] = quote(symbol)["instrument"]
    end

    orders = []
    orders_response = get(ROBINHOOD_ORDERS_ROUTE, return_as_json: true, params: params)
    orders.concat(orders_response["results"]) if orders_response["results"]

    next_url = orders_response["next"]
    while next_url
      # No need to keep paginating if we're looking for the last N orders, and already have them
      break if last && orders.length >= last.to_i
      orders_response = get(next_url, return_as_json: true)
      orders.concat(orders_response["results"])
      next_url = orders_response["next"]
    end

    orders = orders.shift(last.to_i) if last
    orders
  end

  # Get the option chain for a symbol
  #
  # @param symbol [String] The symbol to get the option chain for
  # @return [String, Array<String>] Returns two values, the chain ID, and an array of valid expiration dates for this symbol
  # @example
  #   chain_id, expirations = @client.get_chain_and_expirations("FB")
  def get_chain_and_expirations(symbol)
    instrument_id = get(quote(symbol)["instrument"], return_as_json: true)["id"]
    params = {}
    params["ids"] = instrument_id
    instruments_response = get(ROBINHOOD_INSTRUMENTS_ROUTE, params: params, return_as_json: true)
    chain_id = instruments_response["results"].first["tradable_chain_id"]

    # Get valid expirations for the chain
    expiration_dates = get("#{ROBINHOOD_OPTION_CHAIN_ROUTE}#{chain_id}/", return_as_json: true)["expiration_dates"]

    return chain_id, expiration_dates
  end

  # Get all option instruments given an option type, expiration date, and chain_id
  #
  # @param type [String] The type to limit results by ("call" or "put")
  # @param expiration_date [String] The expiration date to limit results by
  # @param chain_id [String] The option chain ID for the symbol

  # @return [String, Array<String>] Returns the instruments corresponding to the options passed in
  def get_option_instruments(type, expiration_date, chain_id)
    # Get all option instruments with the desired type and expiration
    params = {}
    params["chain_id"] = chain_id
    params["expiration_dates"] = expiration_date
    params["state"] = "active"
    params["tradability"] = "tradable"
    params["type"] = type
    option_instruments = get(ROBINHOOD_OPTION_INSTRUMENT_ROUTE, params: params, return_as_json: true)
    option_instruments["results"]
  end

  # Get an option quote by instrument URL
  #
  # @param instrument_url [String] The instrument URL
  #
  # @return [Hash] Returns quotes for the instrument passed in
  def get_option_quote_by_instrument_url(instrument_url)
    params = {}
    params["instruments"] = instrument_url
    quote = get(ROBINHOOD_OPTION_QUOTE_ROUTE, params: params, return_as_json: true)
    quote["results"].first
  end

  # Get an option quote by instrument URLs
  #
  # @param instrument_url [Array] An array of instrument URLs
  #
  # @return [Array] Returns an array of quotes for the instruments passed in
  def get_batch_option_quote_by_instrument_urls(instrument_urls)
    params = {}
    instruments_string = ""
    instrument_urls.each do |instrument|
      instruments_string += "#{instrument},"
    end
    params["instruments"] = instruments_string
    quote = get(ROBINHOOD_OPTION_QUOTE_ROUTE, params: params, return_as_json: true)
    quote["results"]
  end

  # Get multiple option quotes
  #
  # @param instrument_urls [Array<String>] The option instrument URLs
  #
  # @return [Hash] Returns quotes for the instruments passed in
  def get_multiple_option_quotes(instrument_urls)
    params = {}
    instruments_string = ""
    instrument_urls.each do |instrument|
      instruments_string += "#{instrument},"
    end
    instruments_string.chop!
    params["instruments"] = instruments_string
    get(ROBINHOOD_OPTION_QUOTE_ROUTE, params: params, return_as_json: true)["results"]
  end

  # Get an option quote by instrument ID
  #
  # @param instrument_id [String] The instrument ID
  #
  # @return [Hash] Returns quotes for the instrument passed in
  def get_option_quote_by_id(instrument_id)
    get("#{ROBINHOOD_OPTION_QUOTE_ROUTE}#{instrument_id}/", return_as_json: true)
  end

  # Place an order
  #
  # @note Only limit orders are supported for now.
  # @param side [String] "buy" or "sell"
  # @param symbol [String] The symbol you want to place an order for
  # @param quantity [String] The number of shares
  # @param price [String] The (limit) price per share
  # @param dry_run [Boolean] Whether or not this order should be executed, or if we should just return a summary of the order wanting to be placed
  # @return [Boolean, String] Whether or not the trade was successfully placed. Or if it was a dry run, a string containing a summary of the order wanting to be placed
  # @example
  #   @client.place_order("buy", "FB", "100", "167.55")
  def place_order(side, symbol, quantity, price, dry_run: true)
    return false unless side == "buy" || side == "sell"
    return false unless symbol && quantity.to_i > 0 && price.to_f > 0
    if dry_run
      company_name = get(quote(symbol)["instrument"], return_as_json: true)["name"]
      return "You are placing an order to #{side} #{quantity} shares of #{company_name} (#{symbol}) with a limit price of #{price}"
    else
      accounts = get(ROBINHOOD_ACCOUNTS_ROUTE, return_as_json: true)
      raise "Error: Unexpected number of accounts" unless accounts && accounts["results"].length == 1
      account = accounts["results"].first["url"]

      instrument = quote(symbol)["instrument"]

      params = {}
      params["time_in_force"] = "gfd"
      params["side"]          = side
      params["price"]         = price.to_f.to_s
      params["type"]          = "limit"
      params["trigger"]       = "immediate"
      params["quantity"]      = quantity
      params["account"]       = account
      params["instrument"]    = instrument
      params["symbol"]        = symbol.upcase

      response = post(ROBINHOOD_ORDERS_ROUTE, params)
      response.code == "201"
    end
  end

  # Place an option order
  #
  # @note Only limit orders are supported for now.
  # @param instrument [String] The instrument URL of the option
  # @param quantity [String] The number of contracts
  # @param price [String] The (limit) price per share
  # @param dry_run [Boolean] Whether or not this order should be executed, or if we should just return a summary of the order wanting to be placed
  # @return [Boolean, String] Whether or not the trade was successfully placed. Or if it was a dry run, a string containing a summary of the order wanting to be placed
  def place_option_order(instrument, quantity, price, dry_run: true)

    if dry_run
      instrument_response = get(instrument, return_as_json: true)
      symbol = instrument_response["chain_symbol"]
      type = instrument_response["type"]
      strike_price = instrument_response["strike_price"]
      expiration = instrument_response["expiration_date"]
      company_name = get(quote(symbol)["instrument"], return_as_json: true)["name"]
      response = "You are placing an order to buy #{quantity} contracts of the $#{strike_price} #{expiration} #{type} for #{company_name} (#{symbol}) with a limit price of #{price}"
      response += "\nTotal cost: $#{quantity.to_i * price.to_f * 100.00}"
      return response
    else
      accounts = get(ROBINHOOD_ACCOUNTS_ROUTE, return_as_json: true)
      raise "Error: Unexpected number of accounts" unless accounts && accounts["results"].length == 1
      account = accounts["results"].first["url"]

      params = {}
      params["quantity"] = quantity
      params["direction"] = "debit"
      params["price"] = price
      params["type"] = "limit"
      params["account"] = account
      params["time_in_force"] = "gfd"
      params["trigger"] = "immediate"
      params["legs"] = []
      params["legs"] <<
      leg = {}
      leg["side"] = "buy"
      leg["option"] = instrument
      leg["position_effect"] = "open"
      leg["ratio_quantity"] = "1"
      params["override_day_trade_checks"] = false
      params["override_dtbp_checks"] = false
      params["ref_id"] = SecureRandom.uuid

      response = post(ROBINHOOD_OPTION_ORDER_ROUTE, params)
      response.code == "201"
    end
  end

  def option_orders(last: nil)

    orders = []
    orders_response = get(ROBINHOOD_OPTION_ORDER_ROUTE, return_as_json: true)
    orders.concat(orders_response["results"])

    next_url = orders_response["next"]
    while next_url
      # No need to keep paginating if we're looking for the last N orders, and already have them
      break if last && orders.length >= last.to_i
      orders_response = get(next_url, return_as_json: true)
      orders.concat(orders_response["results"])
      next_url = orders_response["next"]
    end

    orders = orders.shift(last.to_i) if last
    orders
  end

  # Cancel an order
  #
  # @param id [String] the ID of the order to cancel
  # @return [Boolean] Whether or not it was successfully cancelled
  def cancel_stock_order(id)
    response = post("#{ROBINHOOD_ORDERS_ROUTE}#{id}/cancel/", {})
    response.code == "200"
  end

  # Cancel all open orders
  #
  # @return [String] A string specifying how many orders were cancelled
  # @example
  #   @client.cancel_all_open_stock_orders
  def cancel_all_open_stock_orders
    number_cancelled = 0
    self.orders.each do |order|
      if order["cancel"]
        cancelled = cancel_stock_order(order["id"])
        number_cancelled += 1 if cancelled
      end
    end

    number_cancelled
  end

  # Cancel an order
  #
  # @param id [String] the ID of the order to cancel
  # @return [Boolean] Whether or not it was successfully cancelled
  def cancel_option_order(id)
    response = post("#{ROBINHOOD_OPTION_ORDER_ROUTE}#{id}/cancel/", {})
    response.code == "200"
  end

  # Cancel all open option orders
  #
  # @return [String] A string specifying how many orders were cancelled
  # @example
  #   @client.cancel_all_open_option_orders
  def cancel_all_open_option_orders
    number_cancelled = 0
    self.option_orders.each do |order|
      if order["cancel_url"]
        cancelled = cancel_option_order(order["id"])
        number_cancelled += 1 if cancelled
      end
    end

    number_cancelled
  end

  def option_positions
    position_params = {}
    position_params["nonzero"] = true
    get(ROBINHOOD_OPTIONS_POSITIONS_ROUTE, params: position_params, return_as_json: true)["results"]
  end

  def stock_positions
    position_params = {}
    position_params["nonzero"] = true
    get(self.account["positions"], params: position_params, return_as_json: true)["results"]
  end

  def portfolio
    get(self.account["portfolio"], return_as_json: true)
  end

  def account
    user_accounts = self.accounts()
    raise "Error: Unexpected number of accounts" unless user_accounts["results"].length == 1
    user_accounts["results"].first
  end

  # Get the authentication status to see if the credentials passed in when creating the client were valid
  #
  # @return [RobinhoodClient::INVALID, RobinhoodClient::MFA_REQUIRED, RobinhoodClient::SUCCESS] The authentication status of the client
  # @example
  #   @client.authentication_status
  def authentication_status
    @authentication_status
  end

  # Get the latest quote for a symbol
  #
  # @param symbol [String] The symbol to get a quote for
  # @return [Hash] The stock quote
  # @example
  #   @client.quote("FB")
  def quote(symbol)
    symbol.upcase!
    get("#{ROBINHOOD_QUOTE_ROUTE}#{symbol}/", return_as_json: true)
  end

  # Get the fundamentals for a symbol
  #
  # @param symbol [String] The symbol to get the fundamentals for
  # @return [Hash] The fundamentals
  # @example
  #   @client.fundamentals("FB")
  def fundamentals(symbol)
    symbol.upcase!
    get("#{ROBINHOOD_FUNDAMENTALS_ROUTE}#{symbol.upcase}/", return_as_json: true)
  end

  # Get historical data
  #
  # @param symbol [String] The symbol to get historical data for
  # @param interval [String] "week" | "day" | "10minute" | "5minute"
  # @param span [String] "day" | "week" | "year" | "5year" | "all"
  # @param bounds [String] "extended" | "regular" | "trading"
  #
  # @return [Hash] The historical data
  # @example
  #   @client.historical_quote("FB")
  def historical_quote(symbol, interval = "day", span = "year", bounds = "regular")
    params = {}
    params["interval"] = interval
    params["span"] = span
    params["bounds"] = bounds

    symbol.upcase!
    get("#{ROBINHOOD_HISTORICAL_QUOTE_ROUTE}#{symbol}/", params: params, return_as_json: true)
  end

  # Finds the highest moving tickers for the
  #
  # @param direction [String] "up" | "down"
  #
  # @return [Hash] The top moving companies
  # @example
  #   @client.top_movers("up")
  def top_movers(direction)
    params = {}
    params["direction"] = direction
    get(ROBINHOOD_TOP_MOVERS_ROUTE, params: params, return_as_json: true)
  end

  # Get recent news for a symbol
  #
  # @param symbol [String] The symbol to get news for
  # @return [Hash] The news
  # @example
  #   @client.news("FB")
  def news(symbol)
    symbol.upcase!
    get("#{ROBINHOOD_NEWS_ROUTE}#{symbol}/")
  end

  # Get recent quarterly earnings
  #
  # @param symbol [String] The symbol to get news for
  # @return [Hash] Earnings by quarter
  # @example
  #   @client.earnings("FB")
  def earnings(symbol)
    symbol.upcase!
    params = {}
    params["symbol"] = symbol
    get(ROBINHOOD_EARNINGS_ROUTE, params: params, return_as_json: true)
  end

  # Get upcoming earnings
  #
  # @param days [String, Integer] Limit to earnings within the next N days (1-21)
  # @return [Hash] Upcoming companies releasing earnings
  # @example
  #   @client.upcoming_earnings("FB")
  def upcoming_earnings(days)
    params = {}
    params["range"] = "#{days}day"
    get(ROBINHOOD_EARNINGS_ROUTE, params: params, return_as_json: true)
  end

  # Gets the default watchlist
  #
  # @return [Hash] Stocks on the default watchlist
  def default_watchlist

    watchlist_items = []
    watchlist_response = get(ROBINHOOD_DEFAULT_WATCHLIST, return_as_json: true)
    watchlist_items.concat(watchlist_response["results"])

    next_url = watchlist_response["next"]
    while next_url
      watchlist_response = get(next_url, return_as_json: true)
      watchlist_items.concat(watchlist_response["results"])
      next_url = watchlist_response["next"]
    end

    watchlist_items
  end

  # Used to map an "instrument" to a stock symbol
  #
  # @note Internally on the API, stocks are represented by an instrument ID. Many APIs (e.g the recent orders API) don't return the symbol, only the instrument ID.
  #   These mappings don't change so we use a cache to quickly map an instrument ID to a symbol so that we don't have to make a separate API call each time.
  # @param instrument [String] The API instrument URL
  # @return [String] The symbol the insrument corresponds to
  # @example
  #   instrument_to_symbol_lookup("https://api.robinhood.com/instruments/ebab2398-028d-4939-9f1d-13bf38f81c50/")
  def instrument_to_symbol_lookup(instrument)
    @instrument_to_symbol_cache ||= {}
    return @instrument_to_symbol_cache[instrument] if @instrument_to_symbol_cache.key?(instrument)
    stock = get(instrument, return_as_json: true)
    @instrument_to_symbol_cache[instrument] = stock["symbol"]
    return stock["symbol"]
  end

  def access_token
    @access_token
  end

  # Make a GET request to the designated URL using the authentication token if one is stored
  #
  # @param url [String] The API route to hit
  # @param params [Hash] Parameters to add to the request
  # @param return_as_json [Boolean] Whether or not we should return a JSON Hash or the Net::HTTP response.
  # @param authenticated [Boolean] Whether or not we should send the authentication token stored for the client
  #
  # @return [Hash, Net::HTTP] Either the response as a Hash, or a Net::HTTP object depending on the input of `return_as_json`
  def get(url, params: {}, return_as_json: false, authenticated: true)

    # If the URL already has query parameters in it, prefer those
    params_from_url = URI.parse(url).query
    parsed_params_from_url = CGI.parse(params_from_url) if params_from_url
    params = parsed_params_from_url.merge(params) if parsed_params_from_url

    unless url.start_with?("https://api.robinhood.com/")
      raise "Error: Requests must be to the Robinhood API."
    end

    headers = {}
    headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:68.0) Gecko/20100101 Firefox/68.0"
    headers["Accept"] = "*/*"
    headers["Accept-Language"] = "en-US,en;q=0.5"
    headers["Accept-Encoding"] = "gzip, deflate"
    headers["Referer"] = "https://robinhood.com/"
    headers["X-Robinhood-API-Version"] = "1.280.0"
    headers["Origin"] = "https://robinhood.com"


    if @access_token && authenticated
      headers["Authorization"] = "Bearer #{@access_token}"
    end

    response = HttpHelpers.get(url, headers: headers, params: params)

    body = if response.header['content-encoding'] == 'gzip'
      sio = StringIO.new( response.body )
      gz = Zlib::GzipReader.new( sio )
      gz.read()
    else
      response.body
    end

    if return_as_json
      JSON.parse(body)
    else
      response_struct = OpenStruct.new
      response_struct.code = response.code
      response_struct.body = body
      response_struct
    end
  end

  # Make a POST request to the designated URL using the authentication token if one is stored
  #
  # @param url [String] The API route to hit
  # @param body [Hash] Parameters to add to the request
  # @param return_as_json [Boolean] Whether or not we should return a JSON Hash or the Net::HTTP response.
  # @param authenticated [Boolean] Whether or not we should send the authentication token stored for the client
  #
  # @return [Hash, Net::HTTP] Either the response as a Hash, or a Net::HTTP object depending on the input of `return_as_json`
  def post(url, body, return_as_json: false, authenticated: true)

    unless url.start_with?("https://api.robinhood.com/")
      raise "Error: Requests must be to the Robinhood API."
    end

    headers = {}
    headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:68.0) Gecko/20100101 Firefox/68.0"
    headers["Accept"] = "*/*"
    headers["Accept-Language"] = "en-US,en;q=0.5"
    headers["Accept-Encoding"] = "gzip, deflate"
    headers["Referer"] = "https://robinhood.com/"
    headers["X-Robinhood-API-Version"] = "1.280.0"
    headers["Origin"] = "https://robinhood.com"
    headers["Content-Type"] = "application/json"

    if @access_token && authenticated
      headers["Authorization"] = "Bearer #{@access_token}"
    end

    response = HttpHelpers.post(url, headers, body)

    if return_as_json
      JSON.parse(response.body)
    else
      response
    end

  end

  # Add commas to a dollar amount
  #
  # @param value [String] a float dollar value
  #
  # @return [String] A string with commas added appropriately
  #
  # @example
  #   commarize(3901.5) => "3,901.5"
  def commarize(value)
    value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

end
