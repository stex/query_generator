ActionController::Routing::Routes.draw do |map|

  map.resources :generated_queries
  map.query_generator_add_model "/generated_queries/add_model/:model", :controller => "generated_queries", :action => "add_model"

end