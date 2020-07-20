module FormatHelpers

  # Formats a float to 2 decimal places and the color specified
  #
  # @param price [Float] The float to format
  # @param color [Symbol] The color
  # @return [String] The colored string rounded to 2 decimal places
  # @example
  #    FormatHelpers.format_float(123.4567, color: :green)
  def self.format_float(price, color: nil)
    rounded = '%.2f' % price
    if color
      rounded.send(color)
    else
      rounded
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
  def self.commarize(value)
    value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
