class Hash
  # Recursive merge functions
  #
  # Normal merge example:
  #   {:a =>  "b", :c => {:d => "e"}}.merge({:c => {:g => "h"}})
  #   #=> {:a => "b", :c => {:g => "h"}}
  #
  # Recursive merge example:
  #   {:a =>  "b", :c => {:d => "e"}}.recursive_merge({:c => {:g => "h"}})
  #   #=> {:a => "b", :c => {:g => "h", :d => "e"}}
  #
  def recursive_merge(h)
    self.merge(h) {|key, _old, _new| if _old.class == Hash then _old.recursive_merge(_new) else _new end  }
  end

  def recursive_merge!(h)
    self.merge!(h) {|key, _old, _new| if _old.class == Hash then _old.recursive_merge(_new) else _new end  }
  end

  def recursive_reverse_merge(h)
    self.reverse_merge(h) {|key, _old, _new| if _old.class == Hash then _old.recursive_reverse_merge(_new) else _new end  }
  end

  def recursive_reverse_merge!(h)
    self.reverse_merge!(h) {|key, _old, _new| if _old.class == Hash then _old.recursive_reverse_merge(_new) else _new end  }
  end

  def escape_javascript(options = {})
    escape_keys = options[:escape_keys] || false

    new_hash = {}
    self.each do |k,v|
      if escape_keys
        if [Hash, Array, String].include?(k.class)
          k = k.escape_javascript(_options)
        end
      end

      if [Hash, Array, String].include?(v.class)
        v = v.escape_javascript(_options)
      end

      new_hash[k] = v
    end
    new_hash
  end

  # Converts a ruby-hash to one in Javascript (e.g. for parameters/ajax)
  #----------------------------------------------------------------------------
  def to_javascript(options = {})
    pairs = []

    self.each do |key, value|
      next if value.nil?

      if QueryGenerator::Configuration.get(:javascript)[:end_classes].include?(value.class)
        value = value.to_javascript(options[v.class])
      elsif QueryGenerator::Configuration.get(:javascript)[:container_classes].include?(value.class)
        value = value.to_javascript(options)
      end

      pairs << "#{key}: #{value}"
    end

    "{#{pairs.join(", ")}}"
  end
end

class ::Array
  def to_javascript(_options = {})
    "[" + self.map {|v|
      if QueryGenerator::Configuration.get(:javascript)[:end_classes].include?(v.class)
        v.to_javascript(_options[v.class])
      elsif QueryGenerator::Configuration.get(:javascript)[:container_classes].include?(v.class)
        v.to_javascript(_options)
      else
        v
      end
    }.join(", ") + "]"
  end

  def escape_javascript(_options = {})
    self.map {|o|
      if [Hash, Array, String].include?(o.class)
        o.escape_javascript(_options)
      else
        o
      end
    }
  end
end

class String
  #Just a redirect to the ActionView method, this one makes it available in all classes
  def escape_javascript(_options = {})
    ActionView::Base.new.escape_javascript(self)
  end

  def to_javascript(_options = {})
    options = String.parse_to_javascript_options(_options)

    #If the result is javascript, don't convert it to a javascript string
    unless options[:ignore_javascript_indicators]
      for ji in QueryGenerator::Configuration.get(:javascript)[:indicators]
        return self.sub(ji, "") if self.index(ji) == 0
      end
    end

    options[:double_quotes] ? '"' + self + '"' : "'#{self}'"
  end

  private

  #set default conversion options
  def self.parse_to_javascript_options(options)
    options ||= {}
    options[:double_quotes] ||= false #yes, nil ~ false, but FalseClass is better
    options[:ignore_javascript_indicators] ||= false
    options
  end
end

class Symbol
  def to_javascript(options = {})
    self.to_s.to_javascript(options)
  end
end