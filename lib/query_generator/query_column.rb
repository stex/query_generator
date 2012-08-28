module QueryGenerator
  class QueryColumn
    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    #Column options:
    #
    # model       -- The model this column belongs to
    # column_name -- The column name in the model table
    # position    -- The position this column will be displayed in
    # name        -- The SQL "as" parameter. If not set, column_name will be used
    # output      -- If set to +true+, the column will be shown in the output table
    # order       -- ASC, DESC or nil (if not to be used for order_by)
    # conditions  -- an array including all set conditions for this column

    def initialize(*args)
      @generated_query = args.first unless args.first.is_a?(Hash)
      serialized_values = args.last if args.last.is_a?(Hash)
      update_options(serialized_values)
    end

    def update_options(options = {})
      #Delete conditions from the hash as they
      #have to be created differently
      if options["conditions"]
        options["conditions"].each do |condition|
          add_condition(condition)
        end
      end

      #using self.send instead of instance_variable_set
      #is necessary here, as the setters contain additional
      #code
      options.each do |key, value|
        next if key == "conditions"
        self.send("#{key}=", value)
      end
    end

    def model
      @model
    end

    def model=(model)
      @model = model.is_a?(String) ? model.constantize : model
    end

    def model_name
      model.to_s
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

    def output
      @output
    end

    def output=(output)
      @output = output
      @output ||= false
    end

    def order
      @order
    end

    def order=(order)
      @order = order
      @order = nil if order.blank?
    end

    def conditions
      @conditions ||= []
    end

    def add_condition(options = {})
      @conditions ||= []
      @conditions << QueryColumnCondition.new(self, options)
    end

    # Returns "table_name.column_name"
    #--------------------------------------------------------------
    def full_column_name(delimiter = ".", accents = false)
      if accents
        "`#{model.table_name}`#{delimiter}`#{column_name}`"
      else
        "#{model.table_name}#{delimiter}#{column_name}"
      end
    end

    # Returns the full order_by string for this column
    #--------------------------------------------------------------
    def order_by_string
      return nil unless order
      "#{full_column_name} #{order.upcase}"
    end

    def to_hash
      serialized_options
    end

    def generated_query
      @generated_query
    end

    # Returns the column values as basic ruby classes (hash, string, array, numeric)
    #--------------------------------------------------------------
    def serialized_options
      {
          "model"       => model.to_s,
          "position"    => position,
          "column_name" => column_name,
          "name"        => @custom_name,
          "output"      => output,
          "order"       => order,
          "conditions"  => conditions.map(&:to_hash)
      }
    end

  end
end