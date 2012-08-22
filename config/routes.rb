Rails.application.routes.draw do

  resources :generated_queries do
    collection do
      post :add_association
      get  :preview_model_records
      post :set_main_model
      post :remove_model
      post :set_conditions
      get  :load_previous_wizard_step
      get  :choose_model_columns
      get  :choose_model_associations
      get  :toggle_table_column
      post :set_model_offset
    end
  end
end