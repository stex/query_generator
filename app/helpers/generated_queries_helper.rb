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

  # Creates divs for each flash message
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
