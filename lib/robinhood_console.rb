require_relative "robinhood_client"
require_relative "helpers/format_helpers"

require "io/console"
require "optparse"

class RobinhoodConsole

  def initialize
    if ENV["RH_SAFEMODE_OFF"] == "1"
      @safe_mode = false
    else
      @safe_mode = true
    end
  end

  def print_help_text
    puts help()
  end

  # Help text for the console
  #
  # @return [String] The help text detailing all the commands available
  def help
    <<-HELP_TEXT

    --------------------Robinhood Console---------------------
    buy-stock --symbol SYMBOL --quantity QUANTITY --price PRICE
    sell-stock --symbol SYMBOL --quantity QUANTITY --price PRICE

    buy-option <SYMBOL>

    stock-orders --days DAYS --symbol SYMBOL --last LAST
    option-orders --last LAST

    stock-order <ID>
    option-order <ID>

    cancel-stock-order <ID || all>
    cancel-option-order <ID || all>

    stream-stock <SYMBOL> - stream equity quotes
    stream-option <SYMBOL> - stream option quotes
    quote <SYMBOL> - gets the current price of the symbol

    portfolio - print portfolio
    user - print the currently authenticated user
    account - fetch the currently authenticated user's accounts
    backup - store historical data for the past week for your watchlist

    get <URL> - makes an authenticated GET request and prints the output

    help - print this menu
    exit - exit the program
    -----------------------------------------------------------
    HELP_TEXT
  end

  # Prompt the user for credentials and initialize the Robinhood client
  #
  # @return [RobinhoodClient] Returns the RobinhoodClient instance if the credentials were valid
  def initialize_client
    @client = RobinhoodClient.interactively_create_client
  end

  # Begin input loop
  #
  # @return [nil] Loops infinitely until user exits
  def menu_loop

    begin
      loop do
        handle_menu_input()
      end
    rescue Interrupt
      puts "\nExiting..."
      exit 1
    rescue SocketError, Net::OpenTimeout
      puts "Error making request: Check your internet connection."
      menu_loop()
    rescue OptionParser::InvalidOption
      puts "Error: Invalid option used."
      menu_loop()
    end
  end

  def handle_menu_input
    print "$ "
    command = gets
    commands = command.gsub(/\s+/m, ' ').strip.split(" ")

    options = {}
    parser = OptionParser.new do|opts|

      opts.on('-s', '--symbol symbol') do |symbol|
        options[:symbol] = symbol
      end

      opts.on('-q', '--quantity quantity') do |quantity|
        options[:quantity] = quantity
      end

      opts.on('-p', '--price price') do |price|
        options[:price] = price
      end

      opts.on('-d', '--days days') do |days|
        options[:days] = days
      end

      opts.on('-l', '--last last') do |last|
        options[:last] = last
      end

    end

    parser.parse!(commands)

    # response = the return value from the 'when' block it falls into
    # keyword = the word that caused it to match the "when" block
    response = case keyword = commands.shift
    when "help"
      help()
    when "user"
      handle_user()
    when "account"
      handle_account()
    when "portfolio"
      handle_portfolio()
    when "stock-orders"
      handle_stock_orders(options)
    when "stock-order"
      handle_stock_order(commands)
    when "option-order"
      handle_option_order(commands)
    when "option-orders"
      handle_option_orders(options)
    when "buy-stock", "sell-stock"
      handle_buy_or_sell(keyword, options)
    when "buy-option"
      handle_buy_option(commands)
    when "cancel-stock-order"
      handle_cancel_stock_order(commands)
    when "cancel-option-order"
      handle_cancel_option_order(commands)
    when "stream-stock"
      handle_stream_stock(commands)
    when "quote"
      handle_quote(commands)
    when "stream-option"
      handle_stream_option(commands)
    when "backup"
      handle_backup()
    when "get"
      handle_get(commands)
    when "exit", "quit"
      exit 1
    else
      "Unknown command #{command}" unless command == "" || command == "\n"
    end

    puts response

  end

  def handle_buy_or_sell(keyword, options)
    unless options[:symbol] && options[:quantity] && options[:price]
      return "Error: Please supply a symbol, quantity, and price."
    else

      action = if keyword.downcase == "buy-stock"
        "buy"
      elsif keyword.downcase == "sell-stock"
        "sell"
      end

      if @safe_mode
        puts @client.place_order(action, options[:symbol], options[:quantity], options[:price], dry_run: true)
        print "\nPlace this trade? (Y/n): "
        confirmation = gets.chomp
        if confirmation.downcase == "y" || confirmation.downcase == "yes"
          if @client.place_order(action, options[:symbol], options[:quantity], options[:price], dry_run: false)
            "\nOrder successfully placed."
          else
            "\nError placing order."
          end
        end
      else
        if @client.place_order(action, options[:symbol], options[:quantity], options[:price], dry_run: false)
          "\nOrder successfully placed."
        else
          "\nError placing order."
        end
      end
    end
  end

  def handle_stream_stock(commands)
    return "Error: Must specify a symbol" unless commands.first
    symbol = commands.first
    Thread::abort_on_exception = true
    puts "Streaming live quotes. Press enter to stop...\n\n"
    stream_quote_thread = Thread.new do
      previous_last_trade_price = 0
      previous_bid_price = 0
      previous_ask_price = 0
      loop do
        quote = @client.quote(symbol)
        last_trade_price = quote["last_trade_price"].to_f
        bid_price = quote["bid_price"].to_f
        ask_price = quote["ask_price"].to_f

        last_trade_price_color = if last_trade_price > previous_last_trade_price
          :green
        elsif last_trade_price < previous_last_trade_price
          :red
        end

        bid_price_color = if bid_price > previous_bid_price
          :green
        elsif bid_price < previous_bid_price
          :red
        end

        ask_price_color = if ask_price > previous_ask_price
          :green
        elsif ask_price < previous_ask_price
          :red
        end

        last_trade_price_string = FormatHelpers.format_float(last_trade_price, color: last_trade_price_color)
        bid_price_string = FormatHelpers.format_float(bid_price, color: bid_price_color)
        ask_price_string = FormatHelpers.format_float(ask_price, color: ask_price_color)

        print "  #{symbol.upcase}\n"
        print "Last trade price: " + last_trade_price_string + "\n"
        print "Bid: #{bid_price_string} x #{quote["bid_size"]}     \n"
        print "Ask: #{ask_price_string} x #{quote["ask_size"]}     "
        print "\033[3A"
        print "\r"
        STDOUT.flush

        previous_last_trade_price = last_trade_price
        previous_bid_price = bid_price
        previous_ask_price = ask_price
        sleep 1
      end
    end
    # Wait for keyboard input then halt the tread
    gets
    stream_quote_thread.kill
    # Move the cursor back down so you don't type over the quote
    print "\033[3B"
    ""
  end

  def handle_quote(commands)
    return "Error: Must specify a symbol" unless commands.first
    symbol = commands.first

    quote = @client.quote(symbol)
    last_trade_price = quote["last_trade_price"].to_f
    bid_price = quote["bid_price"].to_f
    ask_price = quote["ask_price"].to_f

    last_trade_price_string = FormatHelpers.format_float(last_trade_price)
    bid_price_string = FormatHelpers.format_float(bid_price)
    ask_price_string = FormatHelpers.format_float(ask_price)

    quote_response = "  #{symbol.upcase}\n"
    quote_response += "Last trade price: " + last_trade_price_string + "\n"
    quote_response += "Bid: #{bid_price_string} x #{quote["bid_size"]}     \n"
    quote_response += "Ask: #{ask_price_string} x #{quote["ask_size"]}"
  end

  def handle_user
    user = @client.user
    JSON.pretty_generate(user)
  end

  def handle_account
    accounts = @client.accounts
    JSON.pretty_generate(accounts)
  end

  def handle_get(commands)
    return "Error: Must specify a URL" unless commands.first

    response = @client.get(commands.first)

    JSON.pretty_generate(JSON.parse(response.body))
  rescue JSON::ParserError
    "Unable to parse response as JSON: #{response.body}" + "\nCode: #{response.code}"
  rescue URI::InvalidURIError
    "Error parsing URI"
  end

  def handle_backup
    items = @client.default_watchlist
    directory_name = "historical_data"
    FileUtils.mkdir("historical_data") unless Dir.exists?(directory_name)
    items.each do |item|
      symbol = @client.instrument_to_symbol_lookup(item["instrument"])
      date = Time.new
      date = date.month.to_s + "-" + date.day.to_s + "-" + date.year.to_s
      file_name = File.join(directory_name, "#{symbol}_#{date}_WEEKLY.json")
      File.open(file_name, "w") do |f|
        f.write(@client.historical_quote(symbol, "5minute", "week").to_json)
      end
      puts "Wrote to #{file_name}"
    end
    "Finished writing #{items.length} items."
  end

  def handle_stream_option(commands)
    return "Error: Must specify a symbol" unless commands.first
    symbol = commands.first
    symbol.upcase!
    chain_id, expiration_dates = @client.get_chain_and_expirations(symbol)
    expiration_headings = ["Index", "Expiration"]
    expiration_rows = []
    expiration_dates.each_with_index do |expiration_date, index|
      expiration_rows << ["#{index + 1}", "#{expiration_date}"]
    end
    expiration_table = Table.new(expiration_headings, expiration_rows)
    puts expiration_table
    print "\nSelect an expiration date: "

    # Get expiration date
    expiration_index = gets.chomp
    expiration_date = expiration_dates[expiration_index.to_i - 1]

    #Get type
    type_headings = ["Index", "Type"]
    type_rows = []
    type_rows << ["1", "Call"]
    type_rows << ["2", "Put"]

    type_table = Table.new(type_headings, type_rows)

    puts type_table

    print "\nSelect a type: "

    type = gets.chomp
    type = if type == "1"
      "call"
    else
      "put"
    end

    instruments = @client.get_option_instruments(type, expiration_date, chain_id)

    # Prompt for which one
    instrument_headings = ["Index", "Strike"]
    instrument_rows = []
    instruments = instruments.sort {|a,b| a["strike_price"].to_f <=> b["strike_price"].to_f}
    instruments.each_with_index do |instrument, index|
      instrument_rows << ["#{index + 1}", "#{'%.2f' % instrument["strike_price"]}"]
    end

    instrument_table = Table.new(instrument_headings, instrument_rows)
    puts instrument_table

    print "\nSelect a strike: "

    instrument_index = gets.chomp
    formatted_strike_price = '%.2f' % instruments[instrument_index.to_i - 1]["strike_price"]
    instrument_id = instruments[instrument_index.to_i - 1]["id"]

    # Get the quote for it

    Thread::abort_on_exception = true
    puts "Streaming live quotes. Press enter to stop...\n\n"
    stream_quote_thread = Thread.new do
      previous_last_trade_price = 0
      previous_bid_price = 0
      previous_ask_price = 0
      loop do
        quote = @client.get_option_quote_by_id(instrument_id)
        last_trade_price = quote["last_trade_price"].to_f
        bid_price = quote["bid_price"].to_f
        ask_price = quote["ask_price"].to_f

        last_trade_price_color = if last_trade_price > previous_last_trade_price
          :green
        elsif last_trade_price < previous_last_trade_price
          :red
        end

        bid_price_color = if bid_price > previous_bid_price
          :green
        elsif bid_price < previous_bid_price
          :red
        end

        ask_price_color = if ask_price > previous_ask_price
          :green
        elsif ask_price < previous_ask_price
          :red
        end

        last_trade_price_string = FormatHelpers.format_float(last_trade_price, color: last_trade_price_color)
        bid_price_string = FormatHelpers.format_float(bid_price, color: bid_price_color)
        ask_price_string = FormatHelpers.format_float(ask_price, color: ask_price_color)

        print "  #{symbol} $#{formatted_strike_price} #{type.capitalize} #{expiration_date}\n"
        print "Last trade price: " + last_trade_price_string + "\n"
        print "Bid: #{bid_price_string} x #{quote["bid_size"]}     \n"
        print "Ask: #{ask_price_string} x #{quote["ask_size"]}     "
        print "\033[3A"
        print "\r"
        STDOUT.flush

        previous_last_trade_price = last_trade_price
        previous_bid_price = bid_price
        previous_ask_price = ask_price
        sleep 1
      end

    end
    # Wait for keyboard input then halt the tread
    gets
    stream_quote_thread.kill
    # Move the cursor back down so you don't type over the quote
    print "\033[3B"
    ""
  end

  def handle_cancel_stock_order(commands)
    return "Error: Must specify 'all' or an order ID" unless commands.first
    if commands.first.downcase == "all"
      number_cancelled = @client.cancel_all_open_stock_orders
      "Cancelled #{number_cancelled} orders."
    else
      if @client.cancel_stock_order(commands.first)
        "Successfully cancelled the order."
      else
        "Error cancelling the order."
      end
    end
  end

  def handle_stock_orders(options)
    orders = @client.orders(days: options[:days], symbol: options[:symbol], last: options[:last])
    rows = []
    orders.each do |order|
      state_color = if order["state"] == "filled"
        :green
      elsif order["state"] == "cancelled"
        :red
      end
      state = !state_color.nil? ? order["state"].send(state_color) : order["state"]
      price = order["price"] || order["stop_price"] || order["average_price"] || "NA"
      price_string = "#{'%.2f' % price.to_f}"

      rows << [@client.instrument_to_symbol_lookup(order["instrument"]), order["id"], "#{'%.2f' % order["quantity"].to_f}", price_string, order["side"], state]
    end
    order_headings = ["Symbol", "Order ID", "Quantity", "Price", "Side", "State"]
    Table.new(order_headings, rows)
  end

  def handle_option_orders(options)
    orders = @client.option_orders(last: options[:last])

    option_order_rows = []
    orders.each do |order|
      leg_count = order["legs"].length if order["legs"]

      state_color = if order["state"] == "filled"
        :green
      elsif order["state"] == "cancelled"
        :red
      end

      action = if order["opening_strategy"]
        "opened"
      elsif order["closing_strategy"]
        "closed"
      else
        ""
      end

      strategy = order["opening_strategy"] || order["closing_strategy"] || ""

      state = !state_color.nil? ? order["state"].send(state_color) : order["state"]
      option_order_rows << [action, strategy, order["chain_symbol"], order["id"], leg_count.to_s, order["premium"], "#{'%.2f' % order["price"]}", "#{'%.2f' % order["quantity"]}", state]
    end

    option_order_headers = ["Action", "Strategy", "Symbol", "ID", "Legs", "Premium", "Price", "Quantity", "State"]

    Table.new(option_order_headers, option_order_rows)
  end

  def handle_buy_option(commands)
    unless commands.first
      return "Error: Please supply a symbol"
    end

    symbol = commands.first.upcase
    chain_id, expiration_dates = @client.get_chain_and_expirations(symbol)
    expiration_headings = ["Index", "Expiration"]
    expiration_rows = []
    expiration_dates.each_with_index do |expiration_date, index|
      expiration_rows << ["#{index + 1}", "#{expiration_date}"]
    end
    expiration_table = Table.new(expiration_headings, expiration_rows)
    puts expiration_table
    print "\nSelect an expiration date: "

    # Get expiration date
    expiration_index = gets.chomp
    expiration_date = expiration_dates[expiration_index.to_i - 1]

    #Get type
    type_headings = ["Index", "Type"]
    type_rows = []
    type_rows << ["1", "Call"]
    type_rows << ["2", "Put"]

    type_table = Table.new(type_headings, type_rows)

    puts type_table

    print "\nSelect a type: "

    type = gets.chomp
    type = if type == "1"
      "call"
    else
      "put"
    end

    instruments = @client.get_option_instruments(type, expiration_date, chain_id)

    # Prompt for which one
    instrument_headings = ["Index", "Strike"]
    instrument_rows = []
    instruments = instruments.sort {|a,b| a["strike_price"].to_f <=> b["strike_price"].to_f}
    instruments.each_with_index do |instrument, index|
      instrument_rows << ["#{index + 1}", "#{'%.2f' % instrument["strike_price"]}"]
    end

    instrument_table = Table.new(instrument_headings, instrument_rows)
    puts instrument_table

    print "\nSelect a strike: "

    instrument_index = gets.chomp
    instrument = instruments[instrument_index.to_i - 1]["url"]

    print "\nLimit price per contract: "

    price = gets.chomp

    print "\nQuantity: "

    quantity = gets.chomp

    if @safe_mode
      puts @client.place_option_order(instrument, quantity, price, dry_run: true)
      print "\nPlace this trade? (Y/n): "
      confirmation = gets.chomp
      if confirmation.downcase == "y" || confirmation.downcase == "yes"
        if @client.place_option_order(instrument, quantity, price, dry_run: false)
          "\nOrder successfully placed."
        else
          "\nError placing order."
        end
      end
    else
      if @client.place_option_order(instrument, quantity, price, dry_run: false)
        "\nOrder successfully placed."
      else
        "\nError placing order."
      end
    end
  end

  def handle_cancel_option_order(commands)
    return "Error: Must specify 'all' or an order ID" unless commands.first
    if commands.first.downcase == "all"
      number_cancelled = @client.cancel_all_open_option_orders
      "Cancelled #{number_cancelled} orders."
    else
      if @client.cancel_option_order(commands.first)
        "Successfully cancelled the order."
      else
        "Error cancelling the order."
      end
    end
  end

  def handle_stock_order(commands)
    if commands.first
      order = @client.order(commands.first)
      JSON.pretty_generate(order)
    else
      "Error: Must specify an order ID"
    end
  end

  def handle_option_order(commands)
    if commands.first
      order = @client.option_order(commands.first)
      JSON.pretty_generate(order)
    else
      "Error: Must specify an order ID"
    end
  end

  def handle_portfolio
    account = @client.account
    portfolio = @client.portfolio
    stock_positions = @client.stock_positions
    options_positions = @client.option_positions

    stock_position_rows = []
    option_position_rows = []
    all_time_portfolio_change = 0

    stock_positions.each do |position|
      stock = @client.get(position["instrument"], return_as_json: true)
      quote = @client.get(stock["quote"], return_as_json: true)
      previous_close = quote["previous_close"].to_f
      latest_price = quote["last_trade_price"].to_f
      quantity = position["quantity"].to_f
      cost_basis = position["average_buy_price"].to_f

      day_percent_change = (latest_price - previous_close) / previous_close * 100.00
      day_dollar_change = (latest_price - previous_close) * quantity
      all_time_dollar_change = (latest_price - cost_basis) * quantity

      day_color = day_dollar_change >= 0 ? :green : :red
      all_time_color = all_time_dollar_change >= 0 ? :green : :red

      all_time_portfolio_change += all_time_dollar_change

      stock_position_rows << [stock["symbol"], "#{'%.2f' % quantity}", "$ #{'%.2f' % latest_price}", "$ #{'%.2f' % cost_basis}", "$ #{'%.2f' % day_dollar_change}".send(day_color), "#{'%.2f' % day_percent_change} %".send(day_color), "$ #{FormatHelpers.commarize('%.2f' % all_time_dollar_change)}".send(all_time_color)]
    end

    options_positions.each do |option_position|
      next unless option_position["quantity"].to_i > 0
      option = @client.get(option_position["option"], return_as_json: true)
      current_price = @client.quote(option_position["chain_symbol"])["last_trade_price"]
      distance_from_strike = current_price.to_f - option["strike_price"].to_f

      quote = @client.get_option_quote_by_id(option["id"])
      purchase_price = option_position["average_price"].to_f / 100.00
      current_price = quote["last_trade_price"].to_f

      if option_position["type"] == "short"
        purchase_price = purchase_price * -1
      end

      all_time_change = (current_price - purchase_price) / purchase_price * 100.0

      if option_position["type"] == "short"
        all_time_change = all_time_change * -1
      end

      all_time_color = all_time_change >= 0 ? :green : :red
      distance_from_strike_color = distance_from_strike >= 0 ? :green : :red

      option_position_rows << [option_position["chain_symbol"], option["type"], "#{'%.2f' % option["strike_price"]}", option["expiration_date"], "#{'%.2f' % option_position["quantity"]}", option_position["type"], "$ #{'%.2f' % purchase_price}", "$ #{'%.2f' % current_price}", ('%.2f' % distance_from_strike).send(distance_from_strike_color), "#{'%.2f' % all_time_change} % ".send(all_time_color)]
    end

    stock_headings = ["Symbol", "Quantity", "Latest price", "Avg price", "Day Change", "Day Change", "All time change"]
    stocks_table = Table.new(stock_headings, stock_position_rows)
    portfolio_text = stocks_table

    options_headings = ["Symbol", "Type", "Strike", "Exp", "Quantity", "Type", "Avg price", "Market value", "\u03B7 to strike", "All time change"]
    options_table = Table.new(options_headings, option_position_rows)
    portfolio_text += "\n" + options_table

    all_time_portfolio_color = all_time_portfolio_change >= 0 ? :green : :red

    portfolio_text += "\n\nHoldings: $ #{FormatHelpers.commarize('%.2f' % portfolio["market_value"].to_f)}\n"
    portfolio_text +=     "Cash:     $ #{FormatHelpers.commarize('%.2f' % (account["cash"].to_f + account["unsettled_funds"].to_f))}\n"
    portfolio_text +=     "Equity:   $ #{FormatHelpers.commarize('%.2f' % portfolio["equity"].to_f)}\n"
    portfolio_text += "\nAll time change on stock holdings: " + "$ #{FormatHelpers.commarize('%.2f' % all_time_portfolio_change)}\n".send(all_time_portfolio_color)
    portfolio_text

  end

end
