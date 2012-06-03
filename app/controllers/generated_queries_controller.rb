class GeneratedQueriesController < ApplicationController

  def index
    QueryGenerator::DataHolder.exclusions = [Tolk::Locale, Tolk::Translation, Tolk::Phrase, Audit, Attachment, SheetLayout, VestalVersions::Version]
    @dh = QueryGenerator::DataHolder.instance
  end
end
