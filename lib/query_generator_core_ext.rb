module ActiveRecord
  class Base
    class << self
      def view_sql(*args)
        options = args.extract_options!
        validate_find_options(options)
        set_readonly_option!(options)
        construct_finder_sql(options)
      end
    end
  end
end
