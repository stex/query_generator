Rails.application.routes.draw do |map|

  map.resources :generated_queries, :collection => {:add_association           => :post,
                                                    :preview_model_records     => :get,
                                                    :set_main_model            => :post,
                                                    :remove_model              => :post,
                                                    :set_conditions            => :post,
                                                    :load_previous_wizard_step => :get,
                                                    :choose_model_columns      => :get,
                                                    :choose_model_associations => :get,
                                                    :toggle_table_column       => :get,
                                                    :set_model_offset          => :post}

end