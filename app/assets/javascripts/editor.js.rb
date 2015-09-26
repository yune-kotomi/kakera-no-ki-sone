module Editor
  class Editor
    attr_reader :document

    def load_from_dom
      id = Element.find('#document-id').value
      title = Element.find('#document-title').value
      description = Element.find('#document-description').value
      children = JSON.parse(Element.find('#document-body').value)
      priv = JSON.parse(Element.find('#document-private').value)
      archived = JSON.parse(Element.find('#document-archived').value)
      markup = JSON.parse(Element.find('#document-markup').value)

      @document = Editor::Model::Root.new(
        :id => id,
        :title => title,
        :body => description,
        :children => children,
        :private => priv,
        :archived => archived,
        :markup => markup
      )

      #保存ループ起動
      `setInterval(function(){#{save_loop}}, 5000)`

      @document
    end

    def attach(elements)
      # view生成
      @tree = Editor::View::Tree.new(@document.attributes)
      elements[:tree].append(@tree.dom_element)
      @contents = Editor::View::Contents.new(@document.attributes)
      elements[:contents].append(@contents.dom_element)
      @tags = Editor::View::Tags.new(:tags => @document.tags)
      elements[:tags].append(@tags.dom_element)
      @save_indicator = elements[:save_indicator]

      # ルートノードの編集操作
      @contents.observe(:title) {|t| @document.title = t }
      @contents.observe(:body) {|b| @document.body = b }
      @document.observe(:title) {|t| @tree.title = t }

      # 各属性を接続
      @document.children.each do |c|
        c.scan do |node|
          leaf = @tree.find(node.id)
          content = @contents.find(node.id)

          if node.metadatum && node.metadatum[:tags]
            content.tags = node.metadatum[:tags]
          end

          node.observe(:title) {|t| leaf.title = t }
          node.observe(:chapter_number) do |c|
            leaf.chapter_number = c
            content.chapter_number = c
          end

          content.observe(:title) {|t| node.title = t }
          content.observe(:body) {|b| node.body = b }
          content.observe(:tags) {|t| node.metadatum = node.metadatum.clone.update('tags' => t) }
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

      # 文書全体の編集操作
      @document.observe(:tags) {|t| @tags.tags = t }
      @document.observe(nil, :document_update) { save_enable }
      @document.observe { save_enable }

      # タグ選択
      @tags.observe(:selected_tags) {|t| highlight_by_tags(t) }

      # スクロール制御
      @tree.observe(:current_target) {|t| @contents.scroll_to(t) }

      @tree.observe(:container, :scroll) do
        # targetが不可視になったら可視範囲にあるノードをtargetにする
        visible_contents = @tree.visible_contents
        unless visible_contents.include?(@tree.current_target)
          if @tree.scroll_direction == :down
            target = visible_contents.first
          else
            target = visible_contents.last
          end

          @tree.find(target).target = true
        end
      end

      @contents.observe(:container, :scroll) do
        contents = @contents.visible_contents
        tree = @tree.visible_contents
        # contentとtreeの可視範囲がずれたら追従させる
        if (contents & tree).size == 0
          @tree.scroll_to(contents.first)
          @tree.find(contents.first).target = true
        end
      end
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

    # タグ選択でのハイライト処理
    # タグが一つ以上選択されたらそのタグを持たないノードを落とす
    # 選択タグが0の場合は全ノードを通常表示
    def highlight_by_tags(selected_tags)
      @document.scan do |node|
        next if node == @document # ルートノードには手を付けない

        leaf = @tree.find(node.id)
        content = @contents.find(node.id)

        if selected_tags.empty?
          leaf.unfade
          content.unfade
        else
          if (selected_tags - (node.metadatum['tags'] || [])).size < selected_tags.size
            leaf.unfade
            content.unfade
          else
            leaf.fade
            content.fade
          end
        end
      end
    end

    def save_enable
      @save = true
      @save_indicator.find('.saved').hide
      @save_indicator.find('.working').effect(:fade_in)
    end

    # 保存ループの処理実体
    def save_loop
      save if @save
    end

    # PATCH /documents/ID.jsonを発行する
    def save
      data = @document.attributes(:reject => [:chapter_number])
      data = data.update(
        'description' => data['body'],
        'body' => data['children'].to_json,
      ).reject{|k, v| ['id', 'tags', 'children', 'metadatum'].include?(k) }

      unless data == @sent_data # 内容が更新されていなければ保存しない
        HTTP.patch("/documents/#{@document.id}.json", :payload => {'document' => data}) do |request|
          if request.ok?
            @save = false
            @sent_data = data
            @save_indicator.find('.working').hide
            @save_indicator.find('.saved').effect(:fade_in)
          else
          end
        end
      end
    end
  end
end

Document.ready? do
  unless Element.find('#document-editor').empty?
    editor = Editor::Editor.new
    editor.load_from_dom
    editor.attach(
      :tree => Element.find('#document-editor>.tree-view'),
      :contents => Element.find('#document-editor>.content-view'),
      :tags => Element.find('#document-editor>.tag-list'),
      :save_indicator => Element.find('#save-indicator')
    )

    Element.find('#add-button').on(:click) do
      editor.add_child
    end
  end
end
