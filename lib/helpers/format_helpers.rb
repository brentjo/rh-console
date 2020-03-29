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
end
