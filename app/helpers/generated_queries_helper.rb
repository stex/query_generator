module GeneratedQueriesHelper
  # Forwards the query to CanCan's can? function if the usage of
  # CanCan is enabled in the configuration. Otherwise it will just return true
  #--------------------------------------------------------------
  def ccan?(action, subject, *extra_args)
    QueryGenerator::Configuration.get(:access_control)[:use_cancan] ? can?(action, subject, *extra_args) : true
  end

  def model_node(model)
    render :partial => "model_node", :locals => {:model => model}
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
end
