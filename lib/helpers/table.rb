module Table

  def self.new(headers, rows)

    # Add 1 space padding to all values
    headers.map! do |header|
      header.prepend(" ")
      header += " "
      header
    end

    rows.map! do |row|
      row.map! do |value|
        # We don't want change the values of any variables passed in
        # We only prepend spaces for visual purposes, so let's modify a dup instead
        dupped_value = "" unless value
        dupped_value = value.dup if value
        dupped_value.prepend(" ")
        dupped_value += " "
        dupped_value
      end
    end

    column_length = {}
    headers.each_with_index do |value, index|
      column_length[index] = value.length unless column_length.key?(index)
      column_length[index] = value.length if value.length > column_length[index]
    end

    rows.each do |row|
      row.each_with_index do |value, index|
        column_length[index] = value.length unless column_length.key?(index)
        column_length[index] = value.length if value.length > column_length[index]
      end
    end

    table = "+"
    headers.each_with_index do |value, index|
      table += ("-" * column_length[index])
      table += "+"
    end
    table += "\n"

    table += "|"
    headers.each_with_index do |value, index|
      table += value + (" " * (column_length[index] - value.length))
      table += "|"
    end
    table += "\n"

    table += "+"
    headers.each_with_index do |value, index|
      table += "-" * column_length[index]
      table += "+"
    end
    table += "\n"

    rows.each do |row|
      table += "|"
      row.each_with_index do |value, index|
        # Remove color characters so they don't count towards string length
        value_for_length = value.gsub(/\e\[(\d+)m/, "")
        value_for_length = value_for_length.gsub(/\e\[(\d+);(\d+);(\d+)m/, "")
        num_spaces = (column_length[index] - value_for_length.length)
        table += value
        table += " " * num_spaces
        table += "|"
      end
      table += "\n"
    end

    table += "+"
    headers.each_with_index do |value, index|
      table += ("-" * column_length[index])
      table += "+"
    end
    table += "\n"

    table

  end

end
