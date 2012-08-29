ActionController::Routing::Routes.draw do |map|
  map.namespace :query_generator do |qg|
    qg.resources :generated_queries,
        :collection => {
            :preview_model_records   => :get,
            :fetch_query_records     => :get,
            :edit_column_conditions  => :get,

            :add_association         => :post,
            :remove_association      => :post,
            :set_models              => :post,
            :remove_model            => :post,
            :toggle_table_column     => :post,
            :set_model_offset        => :post,
            :set_progress_view       => :post,
            :inc_column_position     => :post,
            :decr_column_position    => :post,
            :update_column_options   => :post,
            :add_column_condition    => :post,
            :update_column_condition => :post,
            :delete_column_condition => :post
        }

    #Add better readable route for the different wizard steps
    qg.generated_query_wizard 'generated_queries/wizard/:wizard_step', :controller => "generated_queries", :action => "wizard", :wizard_step => /main_model|associations|columns|conditions|query/
  end
end