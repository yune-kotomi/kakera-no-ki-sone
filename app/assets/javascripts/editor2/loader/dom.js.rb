module Editor2
  module Loader
    class Dom
      def load
        doc =
          {
            :id => Element.find('#document-id').value,
            :title => Element.find('#document-title').value,
            :body => Element.find('#document-description').value,
            :children => (JSON.parse(Element.find('#document-body').value) || []),
            :metadatum => {},
            :markup => JSON.parse(Element.find('#document-markup').value),
            :published => JSON.parse(Element.find('#document-public').value),
            :version => JSON.parse(Element.find('#document-version').value)
          }
        yield(doc)
      end
    end
  end
end
