# This file contains helper functions for the plugin
module QueryGenerator
  module HelperFunctions

    # Returns all modules for a given class.
    # Example: get_modules(QueryGenerator::Configuration)
    #          #=> [QueryGenerator]
    #--------------------------------------------------------------
    def get_modules(klass)
      klass = klass.class unless klass.is_a?(Class)
      parts = klass.to_s.split("::")
      parts.pop
      parts.map {|p| p.constantize}
    end

    # Returns the topmost module for the given class
    #--------------------------------------------------------------
    def get_first_module(klass)
      get_modules(klass).first
    end
    
    # Tests if the first array includes any elements of the second array
    # .any? is not used as it's not supported by older rails versions
    #--------------------------------------------------------------
    def array_include?(array1, array2)
      !(array1 & array2).empty?
    end

    # Forwards the query to CanCan's can? function if the plugin
    # is installed. Otherwise it simply returns true
    #--------------------------------------------------------------
    def try_can?(action, subject, *extra_args)
      defined?(CanCan) ? can?(action, subject, *extra_args) : true
    end

  end
end