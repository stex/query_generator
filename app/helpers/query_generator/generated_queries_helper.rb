module QueryGenerator::GeneratedQueriesHelper

  def model_node(model, partial = wizard_file(2, "model_node"))
    render :partial => partial, :locals => {:model => model}
  end

  # Creates a <th> element for a given sql table column
  #--------------------------------------------------------------
  def column_header(column)
    title = t("query_generator.misc.column_header_title", :type => column.type, :default_value => column.default)
    content_tag(:th, column.name, :title => title, :class => column.type)
  end

  # Generates a string in the format
  # "this, that, ... and X more"
  #--------------------------------------------------------------
  def array_preview(array, element_count)
    if array.size <= element_count
      array.to_sentence
    else
      array.take(element_count).join(", ") + " and #{array.size - element_count} more"
    end
  end

  # Displays the attribute localized / in a nice readable form
  #--------------------------------------------------------------
  def attribute_string(attribute, options = {})
    title = nil
    case attribute.class.to_s
      when "String"
        title = attribute
        content = options[:truncate_strings] ? truncate(attribute, :length => 30, :separator => " ") : attribute
      when "Date", "DateTime", "Time"
        content = l(attribute, :format => conf(:localization)[attribute.class.to_s.downcase])
      when "TrueClass", "FalseClass"
        content = check_box_tag("tmp", "1", attribute, :id => nil, :onclick => "return false")
      else
        content = attribute
    end
    result = content_tag(:span, content, :title => title)
  end

  # Generates a dom_id for a model and an association
  # This is in a helper function to keep it constant through
  # the application
  #--------------------------------------------------------------
  def association_dom_id(model, association, options = {})
    handle_dom_id_options("model_#{model.to_s.underscore}_association_#{association}", options)
  end

  # builds a dom ID based on the model object and the column object
  #--------------------------------------------------------------
  def column_dom_id(model, column, options = {})
    column_name = column.is_a?(String) ? column : column.name
    handle_dom_id_options("model_#{model.to_s.underscore}_column_#{column_name}", options)
  end

  # Generates a symbol for certain table columns, e.g. primary keys
  #--------------------------------------------------------------
  def column_symbol(model, column)
    image_path = nil
    options = {}

    if column.primary
      image_path = "query_generator/key.png"
      options[:title] = t("query_generator.misc.primary_key")
    end

    association = dh.column_is_belongs_to_key?(model, column.name)
    if association
      image_path = "query_generator/foreign-key.png"
      options[:title] = t("query_generator.misc.belongs_to_key", :model => dh.graph.associations_for(model)[association[:name].to_s])
    end

    image_path ? image_tag(image_path, options) : ""
  end

  # Updates the query progress in the wizard
  #--------------------------------------------------------------
  def render_current_progress
    options = {}
    options[:joins] = query_generator_session.current_step > 1
    options[:order] = query_generator_session.current_step > 3

    render :partial => "progress", :locals => {:options => options}
  end

  # Creates divs for each flash message type
  #--------------------------------------------------------------
  def flash_messages
    elements = [:notice, :warning, :error].map do |flash_type|
      render(:partial => "query_generator/generated_queries/flash/#{flash_type}.html.haml", :locals => {:message => flash[flash_type]}) if flash[flash_type].present?
    end
    elements.compact.join
  end

  # Renders the given wizard step and partial
  #--------------------------------------------------------------
  def render_wizard_partial(step, partial, locals = {})
    render :partial => wizard_file(step, partial), :locals => locals
  end

  # Generates the remote function to update a column option
  # in the third wizard step
  #--------------------------------------------------------------
  def update_column_option(query_column, option, options = {})
    options.merge!({:model => query_column.model.to_s, :column => query_column.column_name, :option => option})
    remote_function(:url => update_column_options_query_generator_generated_queries_path(options), :with => "jQuery(this).serialize()")
  end

  def update_column_condition(query_column, condition, option, options = {})
    options.merge!({:model => query_column.model.to_s,
                    :column => query_column.column_name,
                    :condition => query_column.conditions.index(condition),
                    :option => option})

    remote_function(:url => update_column_condition_query_generator_generated_queries_path(options), :with => "jQuery(this).serialize()")
  end

  # Builds the options to select ASC/DESC for each column
  #--------------------------------------------------------------
  def order_by_options
    options = t("query_generator.wizard.conditions.order_by_options").invert
    options["--"] = ""
    options
  end

  # Gives the current request_forgery_token to the javascript functions
  # This is necessary as some ajax requests are made without rails helpers
  #--------------------------------------------------------------
  def set_security_token
    if respond_to?('protect_against_forgery?') && protect_against_forgery?
      %{queryGenerator.data.token.key = "#{request_forgery_protection_token}";
        queryGenerator.data.token.value = "#{escape_javascript form_authenticity_token}";}
    end
  end

  private




end
