require "query_generator/version"
require "query_generator_core_ext"

plugin_directory        = File.join(Rails.root, "vendor", "plugins", "query_generator")
sass_directory          = File.join(plugin_directory, "app", "stylesheets")
coffee_script_directory = File.join(plugin_directory, "app", "coffeescripts")

#Make SASS parse the necessary stylesheet files.
#This will also create them in the main application's public/ directory
Sass::Plugin.add_template_location(sass_directory)

#Barista is a rails adapter for CoffeeScript
#The following line will register this plugin as a framework and make CoffeeScript parse all
#necessary javascript files
Barista::Framework.register('QueryGenerator',
                            :root => coffee_script_directory,
                            :bare => true) if defined?(Barista::Framework)

module QueryGenerator
end
