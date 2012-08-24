Rails.application.routes.draw do
  namespace :query_generator do
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
        post :inc_column_position
        post :decr_column_position
        post :update_column_options
      end
    end
    #map.generated_query_wizard 'generated_queries/wizard/:wizard_step', :controller => "generated_queries", :action => "wizard", :wizard_step => /main_model|associations|columns|conditions/
  end
end