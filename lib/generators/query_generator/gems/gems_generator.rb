module QueryGenerator
  module Generators
    class GemsGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      desc "Adds dependencies to the needed gems"
      def add_gem_dependencies
        gem "haml"
        gem "will_paginate"
      end
    end
  end
end
