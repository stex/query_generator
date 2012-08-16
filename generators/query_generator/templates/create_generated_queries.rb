class CreateGeneratedQueries < ActiveRecord::Migration
  def self.up
    create_table :generated_queries do |t|
      t.string :name

      t.string :main_model
      t.text   :associations
      t.text   :values

      t.timestamps
    end
  end

  def self.down
    drop_table :generated_queries
  end
end
