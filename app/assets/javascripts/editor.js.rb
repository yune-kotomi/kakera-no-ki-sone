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
        :body => description,
        :children => children,
        :private => private,
        :archived => archived,
        :markup => markup
      )
    end

    def attach(element)
      # view生成
      @tree = Editor::View::Tree.new(@document.attributes)
      element.find('.tree-view').append(@tree.dom_element)
      @contents = Editor::View::Contents.new(@document.attributes)
      element.find('.content-view').append(@contents.dom_element)

      # 各属性を接続
      @document.children.each do |c|
        c.scan do |node|
          leaf = @tree.find(node.id)
          content = @contents.find(node.id)

          node.observe(:title) {|t| leaf.title = t }
          content.observe(:title) {|t| node.title = t }
          content.observe(:body) {|b| node.body = b }
        end
      end

      # 並び替え
      @tree.rearrange_observe do |target, from, to, position|
        @document.rearrange(target, from, to, position)
      end
      @tree.observe(:order) {|v| @contents.rearrange(v) }
    end
  end
end

Document.ready? do
  unless Element.find('#document-editor').empty?
    editor = Editor::Editor.new
    editor.load_from_dom
    editor.attach(Element.find('#document-editor'))
  end
end
