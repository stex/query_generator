class QueryGeneratorGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      case name
        when "all", "migrations"
          m.migration_template "create_generated_queries.rb", "db/migrate", :migration_file_name => "create_generated_queries"
        when "all", "initializer"
          m.file 'query_generator_configuration.rb', 'config/initializers/query_generator_configuration.rb', :collision => :skip
        else
          puts "YOU GET NOTHING!"
      end
    end
  end

  protected

  def banner
    "Usage: #{$0} query_generator [all|migrations|initializer|javascripts]"
  end
end
