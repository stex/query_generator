module QueryGenerator
  module Generators
    class AssetsGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      desc "Copy necessary assets to the application directory"
      def copy_assets
        directory "assets/images", "public/images"
        directory "assets/javascripts", "public/javascripts"
      end
    end
  end
end
