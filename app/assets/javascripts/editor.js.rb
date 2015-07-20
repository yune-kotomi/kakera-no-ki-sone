module Editor
  class Editor
    attr_reader :document

    def load_from_dom
      id = Element.find('#document-id').value
      title = Element.find('#document-title').value
      description = Element.find('#document-description').value
      children = JSON.parse(Element.find('#document-body').value)
      private = JSON.parse(Element.find('#document-private').value)
      archived = JSON.parse(Element.find('#document-archived').value)
      markup = JSON.parse(Element.find('#document-markup').value)

      @document = Editor::Model::Root.new(
        :id => id,
        :title => title,
        :body => body,
        :children => children,
        :private => private,
        :archived => archived,
        :markup => markup
      )
    end

    def attach(element)
      @tree = Editor::View::Tree.new(@document.tree)
      @contents = Editor::View::Contents.new(@document.contents)
    end
  end
end

Document.ready? do
  if Element.find('#document-editor')
    editor = Editor::Editor.new
    editor.load_from_dom
    editor.attach(Element.find('#document-editor'))
  end
end
