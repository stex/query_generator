module QueryGenerator
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      desc "Runs all necessary generators to install the gem"
      def gotta_run_them_all
        generate "query_generator:gems"
        generate "query_generator:migrations"
        generate "query_generator:assets"
        generate "query_generator:initializer"
      end
    end
  end
end
