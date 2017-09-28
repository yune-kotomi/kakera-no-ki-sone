module Editor2
  class DomLoader
    def load
      {
        :id => Element.find('#document-id').value,
        :title => Element.find('#document-title').value,
        :body => Element.find('#document-description').value,
        :children => (JSON.parse(Element.find('#document-body').value) || []),
        :metadatum => {},
        :markup => JSON.parse(Element.find('#document-markup').value),
        :published => JSON.parse(Element.find('#document-public').value)
      }
    end
  end
end
