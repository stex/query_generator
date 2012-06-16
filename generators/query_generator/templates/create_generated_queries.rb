class CreateGeneratedQueries < ActiveRecord::Migration
  def self.up
    create_table :generated_queries do |t|
      t.string :name
      t.text   :query

      t.timestamps
    end
  end

  def self.down
    drop_table :generated_queries
  end
end
