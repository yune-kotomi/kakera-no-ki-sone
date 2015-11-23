module Editor
  class Editor
    attr_reader :document
    attr_reader :tree
    attr_reader :contents
    attr_reader :tags

    def load_from_dom
      id = Element.find('#document-id').value
      title = Element.find('#document-title').value
      description = Element.find('#document-description').value
      children = JSON.parse(Element.find('#document-body').value) || []
      publ = JSON.parse(Element.find('#document-public').value)
      archived = JSON.parse(Element.find('#document-archived').value)
      markup = JSON.parse(Element.find('#document-markup').value)

      @document = Editor::Model::Root.new(
        :id => id,
        :title => title,
        :body => description,
        :children => children,
        :public => publ,
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
      @document.observe(:markup) {|m| @contents.markup = m }

      # 各属性を接続
      @document.children.each do |c|
        c.scan do |node|
          leaf = @tree.find(node.id)
          leaf.attach(node)

          content = @contents.find(node.id)
          content.attach(node)

          if node.metadatum && node.metadatum[:tags]
            content.tags = node.metadatum[:tags]
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

      # 編集対象の同期
      @tree.observe(:current_target) {|t| @contents.current_target = t }
      @contents.observe(:current_target) {|t| @tree.current_target = t }

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

      # 公開/非公開
      if @document.public
        elements[:public_checkbox].prop('checked', true)
      else
        elements[:public_checkbox].prop('checked', false)
      end
      elements[:public_checkbox].on(:click) do |e|
        if e.current_target.prop('checked')
          @document.public = true
        else
          @document.public = false
        end

        true
      end

      # 記法
      elements[:markup_selector].on(:change) do |e|
        @document.markup = e.current_target.value
      end

      # ツリービューにフォーカスを当てる
      @tree.observe(:focused) {|f| @contents.focused = !f }
      @tree.focused = true

      # ホットキーを有効に
      @hotkeys = Hotkeys.new(self, @document, @tree, @contents)
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
      Window.on(:beforeunload) { close_confirm }
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
            Window.off(:beforeunload)
          else
          end
        end
      end
    end

    def close_confirm
      'まだ保存されていません。よろしいですか？'
    end

    class Hotkeys
      def initialize(parent, document, tree, contents)
        @parent = parent
        @document = document
        @tree = tree
        @contents = contents

        @global_trap = Mousetrap::Binding.new
        @global_trap.bind('enter') {|e| enter(e) }
        @global_trap.bind('mod+0') {|e| ctrl_0(e) }
        @global_trap.bind('mod+alt+n') {|e| ctrl_n(e) }
        @global_trap.bind('mod+alt+e') {|e| ctrl_e(e) }
      end

      def deactivate
        @global_trap.unbind('enter')
        @global_trap.unbind('mod+0')
        @global_trap.unbind('mod+alt+n')
        @global_trap.unbind('mod+alt+e')
      end

      private
      def enter(event)
        ctrl_e(event) if @tree.focused
      end

      def ctrl_0(event)
        @tree.focused = !@tree.focused
      end

      def ctrl_n(event)
        @parent.add_child
      end

      def ctrl_e(event)
        @tree.focused = false
        @contents.find(@contents.current_target).edit
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
      :save_indicator => Element.find('#save-indicator'),
      :public_checkbox => Element.find('#public-checkbox'),
      :markup_selector => Element.find('#markup')
    )

    Element.find('#add-button').on(:click) do
      editor.add_child
    end
  end
end
