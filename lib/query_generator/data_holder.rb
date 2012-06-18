module QueryGenerator

  require "singleton"

  class DataHolder
    include Singleton
    include HelperFunctions

    def initialize
      load_app_data
    end

    def load_app_data
      load_models
      load_associations
      generate_linkage_graph
    end

    def reload!
      @models = nil
      @associations = nil
      @linkages = nil
      load_app_data
    end

    # Returns all models used in the application
    #--------------------------------------------------------------
    def models
      @models
    end

    # Returns a hash representing all associations between models
    # in the application
    #--------------------------------------------------------------
    def associations
      @associations
    end

    # Returns linkages between all found models
    #--------------------------------------------------------------
    def linkage_graph
      @linkages
    end

    # Getter for associations to make sure the hash key format
    # is always the same.
    #--------------------------------------------------------------
    def associations_for(model)
      @associations[model.to_s.classify]
    end

    # Searches for an association with the given name for the given
    # model
    #--------------------------------------------------------------
    def association_by_name(model, association)
      associations_for(model)[association.to_s]
    end

    # Setter for a new association to make sure, the hash key
    # format is always the same.
    #--------------------------------------------------------------
    def add_association(association)
      model_name = association.active_record.to_s
      options = association.options.merge({:macro => association.macro, :name => association.name})

      @associations ||= {}
      @associations[model_name] ||= {}

      @associations[model_name][association.name.to_s] = options
    end

    private

    # Loads all models in the application. This is done once as the
    # models usually don't change once the application was
    # loaded.
    # The code can be simplified, the detailed calls are just for
    # making the function as obvious as possible.
    #--------------------------------------------------------------
    def load_models
      @models = []

      #Load all tables from default application database
      tables = ActiveRecord::Base.connection.tables

      #try to constantize them. If tables exist which do not match a known class, they will be removed
      constantized_tables = tables.collect {|t| t.classify.constantize rescue nil }.compact

      #Filter out classes which do not inherit from ActiveRecord::Base.
      #This is not a common case, but who knows.
      #We might not have all models yet, e.g. single table inheritances are not covered
      #when we only take models which have own tables in the database. This also
      #happens for models which use tables in different databases or just custom table names.
      models_from_tables = constantized_tables.select {|c| c < ActiveRecord::Base}

      #Get all files which are inside a "models" directory throughout the application.
      #This will fetch app/models as well as /models inside a plugin
      #Sometimes these classes are inside of modules, so a simple File.basename wouldn't work.
      #Instead, a regular expression for /models/** is done to get the whole constant name.
      class_names_from_files = Dir['**/models/**/*.rb'].collect {|m| (m.scan /models\/(.*)\.rb/).first.first }

      #Constantize these files. In this step the array might still contain non-ActiveRecord classes
      classes_from_files = class_names_from_files.collect {|cn| cn.camelize.constantize rescue nil }.compact

      #Filter out classes which do not inherit from ActiveRecord::Base.
      #These might be mailer classes or simply classes which were put into app/models instead
      #of /lib to be auto-loaded.
      models_from_files = classes_from_files.select {|c| c < ActiveRecord::Base}

      #Use found models from tables + files to get all available ones
      #Also delete duplicates
      @models = (models_from_tables + models_from_files).uniq.sort {|x,y| x.to_s <=> y.to_s}

      exclusions = Configuration.get(:exclusions)

      #Remove excluded classes
      @models -= exclusions[:classes]

      #Remove excluded modules
      @models.reject! {|m| exclusions[:modules].include?(get_first_module(m))}
    end

    # Loads all associations for pre-fetched models
    # Expects the @models variable to be set.
    # Generates a hash with model names as keys and a association-hash as value.
    #--------------------------------------------------------------
    def load_associations
      @associations = {}

      @models.each do |model|
        #Get all associations of the given type from model
        model.reflect_on_all_associations.each do |association|
          #Don't add polymorphic associations, as we cannot use them to determine actual end classes
          unless association.options[:polymorphic]
            #Add all associations with their options to have access to custom class names later.
            #This is especially important for modular classes
            add_association(association)
          end
        end
      end
    end

    # Generates a graph-like structure to get linkages
    # between classes - based on the found @associations
    #--------------------------------------------------------------
    def generate_linkage_graph
      @linkages = QueryGenerator::ClassLinkageGraph.new

      @associations.each do |model_name, associations|
        node = @linkages.add_node(model_name)

        associations.each do |name, options|
          #Find the end point class name for the current association
          class_name = get_end_point_class(model_name, name, options)

          #If the (correct) class name was found and it's not in the exclude-list, add
          #an edge to the current node
          puts class_name.class if class_name.to_s == "Audit" && !excluded_class?(class_name)
          if class_name && !excluded_class?(class_name)
            node.is_connected_to! class_name, options
          end
        end
      end
    end


    # Checks if the given class name actually belongs to an existing class
    #--------------------------------------------------------------
    def existing_class?(class_name)
      class_name.constantize
      true
    rescue
      false
    end

    # Checks if the given class should be excluded from the linkage graph
    #--------------------------------------------------------------
    def excluded_class?(klass)
      klass = klass.constantize unless klass.is_a?(Class)
      exclusions = Configuration.get(:exclusions)
      exclusions[:classes].include?(klass) || exclusions[:modules].include?(get_first_module(klass))
    end

    
    # Searches for an end point class for an association
    #
    # Steps:
    #   1. Normal naming, either custom class_name or singular association name
    #   2. has_many :through chain.
    #      TODO: Does not support longer chains at the moment - or does it?
    #--------------------------------------------------------------
    def get_end_point_class(model_name, name, options, try_no = 1)
      class_name = nil
      name = name.to_s

      case try_no
        when 1
          class_name = options.keys.include?(:class_name) ? options[:class_name] : name.singularize
        when 2
          if options[:through]
            #Get model end point for :through association
            through_association = association_by_name(model_name, options[:through])

            through_class = get_end_point_class(model_name, through_association[:name], through_association)

            #A custom association might have been set for the through association.
            #If yes, use it.
            name_to_use = options[:source].to_s || name

            #Find correct association in model used by :through
            through_class_association = association_by_name(through_class, name_to_use.singularize)

            #Get model name from :through model
            if through_class_association
              class_name = get_end_point_class(through_class, name, through_class_association)
            end
          end
        else
          return nil
      end

      class_name = class_name.try(:classify)

      if class_name && existing_class?(class_name)
        class_name
      else
        get_end_point_class(model_name, name, options, try_no + 1)
      end
    end
  end
end