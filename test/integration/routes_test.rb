require "#{File.dirname(__FILE__)}/../test_helper"

class RoutesTest < ActionController::IntegrationTest
  test "generated queries routes" do
    #index action
    assert_generates "/generated_queries", { :controller => "generated_queries", :action => "index"}
    assert_recognizes({:controller => "generated_queries", :action => "index"}, {:path => generated_queries_path, :method => :get})

    #new action
    assert_generates "/generated_queries/new", { :controller => "generated_queries", :action => "new"}
    assert_recognizes({:controller => "generated_queries", :action => "new"}, {:path => new_generated_query_path, :method => :get})

    #set_main_model action
    assert_generates "/generated_queries/set_main_model", { :controller => "generated_queries", :action => "set_main_model"}
    assert_recognizes({:controller => "generated_queries", :action => "set_main_model"}, {:path => set_main_model_generated_queries_path, :method => :post})

    #preview_model_records action
    assert_generates "/generated_queries/preview_model_records", { :controller => "generated_queries", :action => "preview_model_records"}
    assert_recognizes({:controller => "generated_queries", :action => "preview_model_records"}, {:path => preview_model_records_generated_queries_path, :method => :get})

    #add_associaton action
    assert_generates "/generated_queries/add_association", { :controller => "generated_queries", :action => "add_association"}
    assert_recognizes({:controller => "generated_queries", :action => "add_association"}, {:path => add_association_generated_queries_path, :method => :post})

    #remove_model action
    assert_generates "/generated_queries/remove_model", { :controller => "generated_queries", :action => "remove_model"}
    assert_recognizes({:controller => "generated_queries", :action => "remove_model"}, {:path => remove_model_generated_queries_path, :method => :post})

    #load_previous_wizard_step action
    assert_generates "/generated_queries/load_previous_wizard_step", { :controller => "generated_queries", :action => "load_previous_wizard_step"}
    assert_recognizes({:controller => "generated_queries", :action => "load_previous_wizard_step"}, {:path => load_previous_wizard_step_generated_queries_path, :method => :get})
  end
end
