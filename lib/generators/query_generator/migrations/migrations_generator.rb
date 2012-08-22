module QueryGenerator
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)

      def self.next_migration_number(path)
        if @prev_migration_nr
          @prev_migration_nr += 1
        else
          @prev_migration_nr = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        end
        @prev_migration_nr.to_s
      end

      desc "Creates the necessary migrations"
      def create_migration
        migration_template "create_generated_queries.rb", "db/migrate/create_generated_queries.rb"
      end
    end
  end
end
