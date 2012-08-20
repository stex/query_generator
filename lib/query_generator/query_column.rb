module QueryGenerator
  class QueryColumn

    #Column options:
    #
    # model       -- The model this column belongs to
    # column_name -- The column name in the model table
    # position    -- The position this column will be displayed in
    # name        -- The SQL "as" parameter. If not set, column_name will be used

    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    def initialize(serialized_values = {})
      #using self.send instead of instance_variable_set
      #is necessary here, as the setters contain additional
      #code
      serialized_values.each do |key, value|
        self.send("#{key}=", value)
      end
    end

    def model
      @model
    end

    def model=(model)
      @model = model.is_a?(String) ? model.constantize : model
    end

    def column_name
      @column_name
    end

    def column_name=(column_name)
      @column_name = column_name
    end

    def position
      @position
    end

    def position=(position)
      @position = position.to_i
    end

    def name
      @custom_name || column_name
    end

    def name=(custom_name)
      @custom_name = custom_name
    end

    # Returns the column values as basic ruby classes (hash, string, array)
    #--------------------------------------------------------------
    def serialized_options
      {
          "model" => model.to_s,
          "position" => position,
          "column_name" => column_name,
          "name" => @custom_name
      }
    end

  end
end