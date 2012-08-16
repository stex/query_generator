require "#{File.dirname(__FILE__)}/../../test_helper"

class QueryGenerator::GeneratedQueryTest < ActiveSupport::TestCase
  context "Validations" do
    should validate_presence_of :name
    should validate_presence_of :main_model
    should validate_presence_of :associations
  end
end
