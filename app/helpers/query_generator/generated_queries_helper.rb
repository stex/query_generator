module QueryGenerator::GeneratedQueriesHelper
  # Forwards the query to CanCan's can? function if the usage of
  # CanCan is enabled in the configuration. Otherwise it will just return true
  #--------------------------------------------------------------
  def ccan?(action, subject, *extra_args)
    QueryGenerator::Configuration.get(:access_control)[:use_cancan] ? can?(action, subject, *extra_args) : true
  end

  def model_node(model, partial = wizard_file(2, "model_node"))
    render :partial => partial, :locals => {:model => model}
  end

  # Creates a <th> element for a given sql table column
  #--------------------------------------------------------------
  def column_header(column)
    title = t("query_generator.misc.column_header_title", :type => column.type, :default_value => column.default)
    content_tag(:th, column.name, :title => title, :class => column.type)
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
    handle_dom_id_options("model_#{model.to_s.underscore}_column_#{column.name}", options)
  end

  def step_forward?
    @step_direction == :forward
  end

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
      options[:title] = t("query_generator.misc.belongs_to_key", :model => dh.linkage_graph.get_node(model).get_model_by_association(association[:name]))
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
    elements = []
    [:notice, :warning, :error].each do |flash_type|
      if flash[flash_type].present?
        elements << content_tag(:div, flash[flash_type], :class => "flash-#{flash_type}")
      end
    end
    elements.join()
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

  def order_by_options
    options = t("query_generator.wizard.conditions.order_by_options").invert
    options["--"] = ""
    options
  end

  private




end
