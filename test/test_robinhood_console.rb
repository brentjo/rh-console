require "minitest/autorun"
require "stringio"

require_relative "../lib/robinhood_console"

class RobinhoodConsoleTest < Minitest::Test

  VALID_JSON_HASH_FOR_MOCKS = { hello: "world" }
  VALID_JSON_STRING_FOR_MOCKS = '{ "hello": "world" }'

  def setup
    @console = RobinhoodConsole.new
    @client = RobinhoodClient.new(unauthenticated: true)

    @console.instance_variable_set(:@client, @client)
  end

  def test_user
    # Set up the mock IO
    io = StringIO.new
    io.puts "user"
    io.rewind
    $stdin = io

    # Mock the user method
    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, VALID_JSON_HASH_FOR_MOCKS

    @client.stub(:user, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_account
    # Set up the mock IO
    io = StringIO.new
    io.puts "account"
    io.rewind
    $stdin = io

    # Mock the accounts method
    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, VALID_JSON_HASH_FOR_MOCKS

    @client.stub(:accounts, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_get_url
    # Set up the mock IO
    io = StringIO.new
    io.puts "get https://api.robinhood.com/"
    io.rewind
    $stdin = io

    mock_http_response = MiniTest::Mock.new
    mock_http_response.expect :body, VALID_JSON_STRING_FOR_MOCKS

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, mock_http_response, ["https://api.robinhood.com/"]

    @client.stub(:get, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify
    mock_http_response.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_buy_order
    # Set up the mock IO
    io = StringIO.new
    io.puts "buy-stock --symbol snap --quantity 100 --price 8.67"
    io.puts "y"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, "Some confirmation text", ["buy", "snap", "100", "8.67", {:dry_run=>true}]
    mocked_method.expect :call, true, ["buy", "snap", "100", "8.67", {:dry_run=>false}]

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_buy_order_with_shortened_options
    # Set up the mock IO
    io = StringIO.new
    io.puts "buy-stock -s snap --q 100 -p 8.67"
    io.puts "y"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, "Some confiration text", ["buy", "snap", "100", "8.67", {:dry_run=>true}]
    mocked_method.expect :call, true, ["buy", "snap", "100", "8.67", {:dry_run=>false}]

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_buy_order_with_options_in_random_order
    # Set up the mock IO
    io = StringIO.new
    io.puts "buy-stock --q 100 -s snap -p 8.67"
    io.puts "y"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, "Some confiration text", ["buy", "snap", "100", "8.67", {:dry_run=>true}]
    mocked_method.expect :call, true, ["buy", "snap", "100", "8.67", {:dry_run=>false}]

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_buy_order_but_dont_confirm
    # Set up the mock IO
    io = StringIO.new
    io.puts "buy-stock --symbol snap --quantity 100 --price 8.67"
    io.puts "n"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, "Some confirmation text", ["buy", "snap", "100", "8.67", {:dry_run=>true}]

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_buy_order_with_safemode_off
    # Set up the mock IO
    io = StringIO.new
    io.puts "buy-stock --symbol snap --quantity 100 --price 8.67"
    io.rewind
    $stdin = io

    # Mock the place_order method
    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, true, ["buy", "snap", "100", "8.67", {:dry_run=>false}]

    @console.instance_variable_set(:@safe_mode, false)

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the 'place_order' method was called correctly
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_sell_order
    # Set up the mock IO
    io = StringIO.new
    io.puts "sell-stock --symbol snap --quantity 100 --price 8.67"
    io.puts "y"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, "Some confiration text", ["sell", "snap", "100", "8.67", {:dry_run=>true}]
    mocked_method.expect :call, true, ["sell", "snap", "100", "8.67", {:dry_run=>false}]

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_sell_order_but_dont_confirm
    # Set up the mock IO
    io = StringIO.new
    io.puts "sell-stock --symbol snap --quantity 100 --price 8.67"
    io.puts "n"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, "Some confirmation text", ["sell", "snap", "100", "8.67", {:dry_run=>true}]

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the method was called with the correct parameters
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_place_sell_order_with_safemode_off
    # Set up the mock IO
    io = StringIO.new
    io.puts "sell-stock --symbol snap --quantity 100 --price 8.67"
    io.rewind
    $stdin = io

    # Mock the place_order method
    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, true, ["sell", "snap", "100", "8.67", {:dry_run=>false}]

    @console.instance_variable_set(:@safe_mode, false)

    @client.stub(:place_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    # Verify that the 'place_order' method was called correctly
    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_cancel_stock_order
    # Set up the mock IO
    io = StringIO.new
    io.puts "cancel-stock-order 30c265b6-d60a-43f8-a5fd-1405db099cd4"
    io.rewind
    $stdin = io

    # Mock the place_order method
    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, true, ["30c265b6-d60a-43f8-a5fd-1405db099cd4"]

    @client.stub(:cancel_stock_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_cancel_all_stock_orders
    # Set up the mock IO
    io = StringIO.new
    io.puts "cancel-stock-order all"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, 10

    @client.stub(:cancel_all_open_stock_orders, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_cancel_option_order
    # Set up the mock IO
    io = StringIO.new
    io.puts "cancel-option-order 30c265b6-d60a-43f8-a5fd-1405db099cd4"
    io.rewind
    $stdin = io

    # Mock the place_order method
    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, true, ["30c265b6-d60a-43f8-a5fd-1405db099cd4"]

    @client.stub(:cancel_option_order, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_cancel_all_option_orders
    # Set up the mock IO
    io = StringIO.new
    io.puts "cancel-option-order all"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, 10

    @client.stub(:cancel_all_open_option_orders, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_stock_quote
    # Set up the mock IO
    io = StringIO.new
    io.puts "quote snap"
    io.rewind
    $stdin = io

    mocked_method = Minitest::Mock.new
    mocked_method.expect :call, VALID_JSON_HASH_FOR_MOCKS, ["snap"]

    @client.stub(:quote, mocked_method) do
      silence_output do
        @console.handle_menu_input
      end
    end

    mocked_method.verify

    # Reset $stdin
    $stdin = STDIN
  end

  def test_safe_mode_on_by_default
    console = RobinhoodConsole.new
    assert_equal true, console.instance_variable_get(:@safe_mode)
  end

  def test_safe_mode_off_if_correct_env_set
    cached_env = ENV["RH_SAFEMODE_OFF"]
    ENV["RH_SAFEMODE_OFF"] = "1"
    console = RobinhoodConsole.new
    assert_equal false, console.instance_variable_get(:@safe_mode)
    ENV["RH_SAFEMODE_OFF"] = cached_env
  end

  def test_safe_still_on_if_incorrect_env_set
    cached_env = ENV["RH_SAFEMODE_OFF"]
    ENV["RH_SAFEMODE_OFF"] = "some_other_value"
    console = RobinhoodConsole.new
    assert_equal true, console.instance_variable_get(:@safe_mode)
    ENV["RH_SAFEMODE_OFF"] = cached_env
  end

  private

  def silence_output
    original_stdout, original_stderr = $stdout.clone, $stderr.clone
    $stderr.reopen File.new('/dev/null', 'w')
    $stdout.reopen File.new('/dev/null', 'w')
    yield
  ensure
    $stdout.reopen original_stdout
    $stderr.reopen original_stderr
  end

end
