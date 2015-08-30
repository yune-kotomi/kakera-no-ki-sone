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
          content.destroy_clicked { node.destroy }
          node.observe(nil, :destroy) do
            leaf.destroy
            # 表示領域はツリー上の親子関係を持たないのでnodeが持つ子をすべて明示的に消す
            node.scan {|n| @contents.find(n.id).destroy }
          end
        end
      end

      # 並び替え
      @tree.rearrange_observe do |target, from, to, position|
        @document.rearrange(target, from, to, position)
      end
      @tree.observe(:order) {|v| @contents.rearrange(v) }
    end

    # 編集対象の要素の弟ノードを追加する
    def add_child
      default_values = {:title => '(無題)'}
      target = @document.find(@tree.current_target)

      if target.is_a?(Editor::Model::Root)
        position = target.children.size
        node = target.add_child(position, default_values)
        leaf = @tree.add_child(position, node)
        if position == 0
          content = @contents.add_child(nil, node)
        else
          content = @contents.add_child(target.children[target.children.size - 2].last_child.id, node)
        end
      else
        position = target.parent.children.index(target) + 1
        node = target.parent.add_child(position, default_values)
        leaf = @tree.find(target.parent.id).add_child(position, node)
        content = @contents.add_child(target.last_child.id, node)
      end

      # 生成した新ノードを選択状態にする
      leaf.target = true
    end
  end
end

Document.ready? do
  unless Element.find('#document-editor').empty?
    editor = Editor::Editor.new
    editor.load_from_dom
    editor.attach(Element.find('#document-editor'))

    Element.find('#add-button').on(:click) do
      editor.add_child
    end
  end
end
