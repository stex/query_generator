ActionController::Routing::Routes.draw do |map|

  map.resources :generated_queries, :collection => {:add_model => :post, :preview_model_records => :get}

end