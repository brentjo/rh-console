Gem::Specification.new do |s|
  s.name = %q{rh-console}
  s.version = "1.0.6"
  s.authors = ["https://github.com/brentjo"]
  s.summary = "A command line interface to the Robinhood API"
  s.description = "A command line interface to the Robinhood API. View your portfolio, stream quotes, and place orders at the command line."
  s.homepage = "https://github.com/brentjo/rh-console"
  s.files = ["bin/rh-console", "README.md"] + Dir["lib/**/*"] + Dir["initializers/*"]
  s.executables = ["rh-console"]
end
