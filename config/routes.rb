ActionController::Routing::Routes.draw do |map|

  map.resources :generated_queries, :collection => {:add_association => :post, :preview_model_records => :get, :set_main_model => :post}

end