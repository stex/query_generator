module QueryGenerator
  class QueryColumnCondition
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    COMPARATORS = ["=", "<>", "<", "<=", ">", ">="].freeze

    def initialize(query_column, serialized_options = {})
      @query_column = query_column
      update_options(serialized_options)
    end

    def update_options(options = {})
      options.each do |key, value|
        self.send("#{key}=", value)
      end
    end

    # Checks if the condition is valid
    # This means, that all necessary fields are present
    #--------------------------------------------------------------
    def valid?
      if ["value", "column"].include? type
        return false if value.blank?
      end

      if type == "variable"
        return false if @variable_value.blank?
      end

      if type == "column"
        columns = @query_column.generated_query.used_columns.map(&:full_column_name)
        return false unless columns.include?(value)
      end

      true
    end

    # The condition type. Available options here are:
    #   "value"       -- A simple value to be matched
    #   "column"      -- One of the other columns
    #   "variable"    -- A variable to be asked for when the query is executed
    #   "is_null"     -- Generates simply IS NULL
    #   "is_not_null" -- Generates simply IS NOT NULL
    #--------------------------------------------------------------
    def type
      @type || "value"
    end

    def type=(type)
      @type = type
    end

    # The connector between the condition before and this one
    # Available options here:
    #   "AND"
    #   "OR"
    #--------------------------------------------------------------
    def connector
      @connector || "AND"
    end

    def connector=(connector)
      @connector = connector
    end

    # If comparing to a value or another column, this property
    # contains the compare operator to be used. Possible values here are:
    #   "="
    #   "<>"
    #   "<"
    #   "<="
    #   ">"
    #   ">="
    #--------------------------------------------------------------
    def comparator
      @comparator || COMPARATORS.first
    end

    def comparator=(comparator)
      @comparator = comparator
    end

    # The level this condition is in the conditions array
    # Example: If we have conditions like
    #   column1 AND (column2 OR column3)
    # the brackets are quite important (AND has a higher priority than OR)
    # The levels for the conditions would be as follows:
    #   column1      -- level1
    #     column2    -- level2
    #     column3    -- level2
    # Each level will be surrounded by brackets in the generated SQL
    #--------------------------------------------------------------
    def level
      @level || 1
    end

    def level=(level)
      @level = level.to_i
    end

    # If the type is "value", this property contains the value,
    # if it's "variable", it will contain the variable name,
    # for "column" it's the full column name (table.column)
    #--------------------------------------------------------------
    def value
      @value
    end

    def value=(value)
      @value = value.to_s
    end

    # Sets the variable value for this condition
    # This is necessary to check if the current condition is valid
    #--------------------------------------------------------------
    def set_variable(value)
      @variable_value = value
    end

    # Returns a string usable with ActiveRecord's find()
    #--------------------------------------------------------------
    def to_s(options = {})
      options[:connector] = true if options[:connector].nil?

      result = []
      result << ")" if options[:initial_closing_bracket]
      result << connector if options[:connector]
      result << "(" if options[:opening_bracket]
      result << "#{@query_column.full_column_name}"

      if ["is_null", "is_not_null"].include?(type)
        result << "IS NULL" if type == "is_null"
        result << "IS NOT NULL" if type == "is_not_null"
      else
        result << "#{comparator}"
        if type == "column"
          result << "#{value}"
        else
          result << "?"
        end
      end

      result << ")" if options[:closing_bracket]

      result.join(" ")
    end

    # Returns the details in a serialized form
    #--------------------------------------------------------------
    def to_hash
      {
          "type"       => type,
          "connector"  => connector,
          "level"      => level,
          "comparator" => comparator,
          "value"      => value,
      }
    end
  end
end