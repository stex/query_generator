ActionController::Routing::Routes.draw do |map|
  map.namespace :query_generator do |qg|
    qg.resources :generated_queries, :collection => {:add_association           => :post,
                                                      :preview_model_records     => :get,
                                                      :set_main_model            => :post,
                                                      :remove_model              => :post,
                                                      :set_conditions            => :get,
                                                      :load_previous_wizard_step => :get,
                                                      :choose_model_columns      => :get,
                                                      :choose_model_associations => :get,
                                                      :toggle_table_column       => :get,
                                                      :set_model_offset          => :post,
                                                      :choose_main_model         => :get,
                                                      :inc_column_position       => :post,
                                                      :decr_column_position      => :post,
                                                      :update_column_options     => :post}

    qg.generated_query_wizard 'generated_queries/wizard/:wizard_step', :controller => "generated_queries", :action => "wizard", :wizard_step => /main_model|associations|columns|conditions|query/
  end
end