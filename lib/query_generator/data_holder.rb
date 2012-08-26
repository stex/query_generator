module QueryGenerator

  # This class stores all information about the surrounding rails application the plugin needs
  # to work correctly.
  # It also holds functionality to make model/column/association access easier.
  #
  # In production environment, all models and associations are loaded on server start
  # and hold here for later use.
  #
  # While building the linkage graph between the existing models, it will also log possible erroneous associations
  # between the models (associations it could not resolve)

  require "singleton"

  class DataHolder
    include Singleton

    unloadable if Rails.env.development? #Don't cache this class in development environment, even if in gem

    # Forwards non-found methods to the instance. This saves us
    # some calls to .instance when accessing DataHolder methods
    #--------------------------------------------------------------
    def self.method_missing(m, *args, &block)
      self.instance.send(m, *args, &block)
    end

    def initialize
      load_app_data
    end

    def load_app_data
      load_models
      load_associations
      generate_linkage_graph
      log_erroneous_associations
    end

    def reload!
      @models = nil
      @associations = nil
      @linkages = nil
      @erroneous_associations = nil
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

    def graph
      @linkages
    end

    #Checks if the given column is the primary key for a belongs_to
    #association in the given model
    #--------------------------------------------------------------
    def column_is_belongs_to_key?(model, column_name)
      associations_for(model).each do |association_name, options|
        return options if options[:macro].to_s == "belongs_to" && column_name.to_s == options[:primary_key].to_s
      end
      nil
    end

    private

    # Getter for associations to make sure the hash key format
    # is always the same.
    #--------------------------------------------------------------
    def associations_for(model)
      @associations[model.to_s]
    end

    # Erroneous Connections found during structure analysis
    #--------------------------------------------------------------
    def erroneous_associations
      @erroneous_associations ||= {}
    end

    # Searches for an association with the given name for the given
    # model
    #--------------------------------------------------------------
    def association_by_name(model, association)
      associations_for(model)[association.to_s]
    end

    # Returns the selected model column object
    #--------------------------------------------------------------
    def model_column_by_name(model, column_name)
      model.columns.detect {|column| column.name == column_name}
    end

    # Setter for a new association to make sure, the hash key
    # format is always the same.
    # Format: {"model_name" => {"association_name" => {options/information}}}
    #--------------------------------------------------------------
    def add_association(association)
      model_name = association.active_record.to_s

      #The foreign key might not be resolved if the association itself is erroneous
      foreign_key = association.association_foreign_key rescue nil
      primary_key = association.primary_key_name rescue nil
      options = association.options.merge({:macro => association.macro, :name => association.name})
      options[:foreign_key] = foreign_key if foreign_key
      options[:primary_key] = primary_key if primary_key

      @associations ||= {}
      @associations[model_name] ||= {}

      @associations[model_name][association.name.to_s] = options
    end

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
      @models -= [GeneratedQuery]

      #Remove excluded modules
      @models.reject! {|m| exclusions[:modules].include?(get_first_module(m))}

      #Sort Models by name for later use
      @models.sort! {|x,y| x.to_s <=> y.to_s}
    end

    # Loads all associations for pre-fetched models
    # Expects the @models variable to be set.
    # Generates a hash with model names as keys and a association-hash as value.
    # Important: These assocations will still include associations to
    #            excluded classes. These will be removed when building the linkage graph
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
        @linkages << model_name

        associations.each do |name, options|
          #Find the end point class name for the current association
          class_name = get_end_point_class(model_name, name, options)

          #Add an error for the association if the class could not be resolved
          if class_name.blank?
            @erroneous_associations ||= {}
            @erroneous_associations[model_name] ||= []
            @erroneous_associations[model_name] << {:association => name, :options => options}
          end

          #If the (correct) class name was found and it's not in the exclude-list, add
          #an edge to the current node
          if class_name.present? && !excluded_class?(class_name)
            @linkages.add_edge(model_name, class_name, options)
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
    # TODO: Allow sub-modules, e.g. exclude Module1::Module2. At the moment only Module1 is possible
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

            #A custom association might have been set for the through association. If yes, use it.
            name_to_use = (options[:source] || name).to_s

            #Find correct association in model used by :through
            through_class_association = association_by_name(through_class, name_to_use.singularize)

            #Get model name from :through model
            if through_class_association
              class_name = get_end_point_class(through_class, name_to_use, through_class_association)
            end
          end
        else
          return nil
      end

      #Classify the class name unless a class name was given in the options (e.g.
      # naming without using the conventions)
      class_name = class_name.to_s.try(:classify) unless options[:class_name]

      if class_name.present? && existing_class?(class_name)
        class_name
      else
        get_end_point_class(model_name, name, options, try_no + 1)
      end
    end

    # Returns all modules for a given class.
    # Example: get_modules(QueryGenerator::Configuration)
    #          #=> [QueryGenerator]
    #--------------------------------------------------------------
    def get_modules(klass)
      klass = klass.class unless klass.is_a?(Class)
      parts = klass.to_s.split("::")
      parts.pop
      parts.map &:constantize
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

    # Logs erroneous model associations if any were found
    #--------------------------------------------------------------
    def log_erroneous_associations
      Rails.logger.warn "* QueryGenerator -- Erroneous associations:" if erroneous_associations.any?
      erroneous_associations.each do |model, eas|
        Rails.logger.warn "*  Model: #{model}"
        eas.each do |ea|
          Rails.logger.warn "*   Association: #{ea[:association]}"
        end
      end
    end
  end
end