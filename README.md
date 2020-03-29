## Robinhood console

A Ruby command line interface to the Robinhood API:

<img height="440" alt="rh-console" src="https://user-images.githubusercontent.com/6415223/78421025-6afd7480-7609-11ea-852a-39280b3ef671.png">

### Installation

:warning: WARNING: This is no longer maintained and has not been thoroughly used in years. It is **not** recommended to use this to place trades or perform any sensitive actions, as this is **not** an official product of Robinhood and the APIs it's making use of may change at any time :warning:

Rh-console is hosted on RubyGems and can be installed via:

`gem install rh-console`

And you'll have access to a `rh-console` executable in your terminal.

Alternatively, clone the repository and run it:
```
git clone https://github.com/brentjo/rh-console
cd rh-console
bin/rh-console
```

Or run with Docker:

```
docker build -f Dockerfile -t rh-console .
docker run -it --rm rh-console
```

### Features

- Stream live equity and option quotes
- Place orders for equities and options
- View order history and cancel open orders
- Print a summary of your portfolio
- View information about your account
- Backup weekly historical data for your watchlist
- Manually make authenticated requests to the API using the `get` command
- The JWT authentication token auto-refreshes in the background.
- Supports accounts with multi-factor authentication enabled

### Development

There are no dependencies -- only the ruby standard library is used, so simply clone, start making edits, and run with `bin/rh-console`.

The few gems listed in the Gemfile are needed to run and record new tests, and can be installed with `bundle install`. Tests use [vcr](https://github.com/vcr/vcr) to record interactions with the Robinhood API. The initial recording hits the live API and your test cases make assertions based off it, but subsequent runs match against requests in the VCR recording.

After making changes, update the YARD documentation with `bundle exec rake yard`.

### Testing

Install the dependencies and run tests via rake:
```
bundle install
bundle exec rake test
```

Alternatively, build and run a Dockerfile:

```
docker build -f Dockerfile.ci -t rh-console-ci .
docker run --rm rh-console-ci
```

**Command line interactions**
Tests that assert that certain command line input should lead to certain library calls are within `test/test_robinhood_console.rb`.

**Robinhood client**
The actual client that interacts with the API to place orders, get quotes, etc, is tested within `test/test_unauthenticated_robinhood_client.rb` and `test/test_authenticated_robinhood_client.rb`. Unfortunately, because these VCR recordings are real API interactions, the cassettes for most tests are not checked into source control.

### Documentation
Full YARD documentation can be found at: https://brentjo.github.io/rh-console/top-level-namespace.html
- [RobinhoodClient](./lib/robinhood_client.rb) - Contains the bulk of the code that handles making requests to the Robinhood API.
- [RobinhoodConsole](./lib/robinhood_console.rb) - Contains all the code to handle taking in user input, parsing it, and sending it to the RobinhoodClient.
- [Table](./lib/helpers/table.rb) - A method that takes an array of headers, and an array or rows, and formats it into a pretty table in the style of [`tj/terminal-table`](https://github.com/tj/terminal-table).
- [HttpHelpers](./lib/helpers/http_helpers.rb) - Contains wrappers around `Net:HTTP`'s GET and POST methods to help craft the requests to the API.
- [String](./initializers/string.rb) - String is monkey-patched to add some color helper methods so you're able to do `"text".red` and the text will be output red in the terminal.
