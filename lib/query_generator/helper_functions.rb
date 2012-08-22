# This file contains helper functions for the plugin
module QueryGenerator
  module HelperFunctions
    # Forwards the query to CanCan's can? function if the usage of
    # CanCan is enabled in the configuration. Otherwise it will just return true
    #--------------------------------------------------------------
    def ccan?(action, subject, *extra_args)
      Configuration.get(:access_control)[:use_cancan] ? can?(action, subject, *extra_args) : true
    end

    # Rails2 compatibility function
    #--------------------------------------------------------------
    def human_model_name(model)
      return nil if model.nil?
      begin
        model.human_name
      rescue
        model.model_name.human
      end
    end

  end
end