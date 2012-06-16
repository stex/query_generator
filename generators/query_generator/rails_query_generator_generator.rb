class QueryGeneratorGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      case name
        when "all", "migrations"
          m.migration_template "create_generated_queries.rb", "db/migrate", :migration_file_name => "create_generated_queries"
        else
          puts "YOU GET NOTHING!"
      end
    end
  end

  protected

  def banner
    "Usage: #{$0} rails_query_generator [migrations|javascripts]"
  end
end
