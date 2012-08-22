module QueryGenerator
  module Generators
    class AssetsGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      desc "Copy necessary assets to the application directory"
      def copy_assets
        directory "assets/images", "app/assets/images"
        directory "assets/javascripts", "app/assets/javascripts"
        directory "assets/stylesheets", "app/assets/stylesheets"
      end
    end
  end
end
