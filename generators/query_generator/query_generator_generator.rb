class QueryGeneratorGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      #begin
        send("generate_#{name}", m)
      #rescue
      #  puts "*************************************\n*          YOU GET NOTHING!         *\n*************************************"
      #end
    end
  end

  protected

  def banner
    "Usage: #{$0} query_generator [all|migrations|initializer|javascripts]"
  end

  private

  # Generates all necessary data for the plugin
  #--------------------------------------------------------------
  def generate_all(m)
    generate_migration(m)
    generate_initializer(m)
    generate_assets(m)
  end

  # Generates the migration for the generated_queries-table
  #--------------------------------------------------------------
  def generate_migration(m)
    m.migration_template "create_generated_queries.rb", "db/migrate", :migration_file_name => "create_generated_queries"
  end

  # Generates the initializer to set up the plugin configuration
  #--------------------------------------------------------------
  def generate_initializer(m)
    m.file 'query_generator_configuration.rb', 'config/initializers/query_generator_configuration.rb'
  end

  # Copies all necessary assets (javascripts, css, images)
  # to the app's public directory
  #--------------------------------------------------------------
  def generate_assets(m)
    files = {}
    files[:javascripts] = ["query_generator.js", File.join("query_generator", "jquery.jsPlumb-1.3.9-all-min.js")]
    files[:stylesheets] = ["query_generator.css"]

    m.directory "public/javascripts/query_generator"
    m.directory "public/images/query_generator"

    files.each do |directory, paths|
      paths.each do |path|
        m.file File.join("assets", directory.to_s, path), File.join("public", directory.to_s, path)
      end
    end
  end


end
