module QueryGenerator
  module Generators
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      desc "Creates the configuration initializer"
      def create_initializer
        copy_file "query_generator_configuration.rb", "config/initializers/query_generator_configuration.rb"
      end
    end
  end
end
