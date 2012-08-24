require "query_generator/version"
require "query_generator_core_ext"

require "sass/plugin" #Seems to be necessary for rails3 as ::Plugin is not available

plugin_directory        = File.expand_path('../..', __FILE__)
sass_directory          = File.join(plugin_directory, "app", "stylesheets")
coffee_script_directory = File.join(plugin_directory, "app", "coffeescripts")

#Make SASS parse the necessary stylesheet files.
#This will also create them in the main application's public/ directory
Sass::Plugin.add_template_location(sass_directory)

#Barista is a rails adapter for CoffeeScript
#The following line will register this plugin as a framework and make CoffeeScript parse all
#necessary javascript files
Barista::Framework.register('QueryGenerator', coffee_script_directory) if defined?(Barista::Framework)

module QueryGenerator
  WIZARD_STEPS = ["main_model", "associations", "columns", "conditions"]
end
