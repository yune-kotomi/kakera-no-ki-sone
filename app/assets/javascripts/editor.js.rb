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
      @tree = Editor::View::Tree.new(@document)
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
          content = @contents.find(node.id)
          attach_mv(node, leaf, content)

          if node.metadatum && node.metadatum[:tags]
            content.tags = node.metadatum[:tags]
          end
        end
      end

      # 並び替え
      @tree.observe(nil, :event => :rearrange) do |_, target_id, from_id, to_id, position, order|
        @document.rearrange(target_id, from_id, to_id, position)
        @contents.rearrange(order)
      end

      # 文書全体の編集操作
      @document.observe(:tags) {|t| @tags.tags = t }
      @document.observe(nil, :event => :document_update) { save_enable }
      @document.observe { save_enable }

      # タグ選択
      @tags.observe(:selected_tags) {|t| highlight_by_tags(t) }

      # 編集対象の同期
      @tree.observe(:current_target) {|t| @contents.current_target = t }
      @contents.observe(:current_target) {|t| @tree.current_target = t }

      # 公開/非公開
      if @document.public
        elements[:public_checkbox].prop('checked', true)
      else
        elements[:public_checkbox].prop('checked', false)
      end
      elements[:public_checkbox].on(:click) do |e|
        if e.current_target.prop('checked')
          @document.public = true
          elements[:password].hide
        else
          @document.public = false
          elements[:password].show
        end

        true
      end

      password_field = elements[:password].find('[name="password"]')
      password_apply = elements[:password].find('.apply')
      password_cancel = elements[:password].find('.cancel')

      password_apply.on(:click) do |e|
        save_password(password_field.value)
        password_cancel.show
      end
      password_cancel.on(:click) do |e|
        save_password
        password_field.value = ''
        password_cancel.hide
      end

      # 記法
      elements[:markup_selector].on(:click) do |e|
        @document.markup = elements[:markup_selector].to_a.find{|e| e.prop('checked') }.value
      end

      # フォーカスの排他処理
      @tree.observe(:focused) {|f| @contents.focused = !f }
      @contents.observe(:focused) {|f| @tree.focused = !f }
      @tree.focused = true

      # ホットキーを有効に
      @hotkeys = Hotkeys.new(self, @document, @tree, @contents)
    end

    def attach_mv(node, leaf, content)
      node.observe(:title) {|v| leaf.title = v }
      node.observe(:chapter_number) {|v| leaf.chapter_number = v }
      node.observe(:chapter_number) {|v| content.chapter_number = v }

      leaf.observe(:open) {|v| node.metadatum = node.metadatum.dup.update(:open => v) }
      leaf.observe(nil, :event => :destroy) do
        node.destroy
        node.scan{|n| @contents.find(n.id).destroy }
      end

      content.observe(:title) {|v| node.title = v }
      content.observe(:body) {|v| node.body = v }
      content.observe(:tags) {|v| node.metadatum = node.metadatum.dup.update(:tags => v) }
      content.observe(nil, :event => :destroy) do
        leaf.destroy
        node.scan{|n| @contents.find(n.id).destroy unless n.id == content.id }
        node.destroy
      end
    end

    # 編集対象の要素の弟ノードを追加する
    def add_child
      default_values = {}
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

      attach_mv(node, leaf, content)

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
      @save_indicator.effect(:fade_in)
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

      if data == @sent_data
        # 内容が更新されていなければ保存しない
        @save_indicator.effect(:fade_out)
        Window.off(:beforeunload)
      else
        @save_indicator.add_class('mdl-progress__indeterminate')

        HTTP.patch("/documents/#{@document.id}.json", :payload => {'document' => data}) do |request|
          if request.ok?
            @save = false
            @sent_data = data
            @save_indicator.remove_class('mdl-progress__indeterminate')
            @save_indicator.effect(:fade_out)
            Window.off(:beforeunload)
          else
          end
        end
      end
    end

    def save_password(password = '')
      HTTP.patch("/documents/#{@document.id}.json", :payload => {'document' => {'password' => password}}) do |request|
        if request.ok?
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
      :tags => Element.find('#tag-list'),
      :save_indicator => Element.find('#save-indicator'),
      :public_checkbox => Element.find('#public-checkbox'),
      :password => Element.find('#password-box'),
      :markup_selector => Element.find('input[name="markup"]'),
      :setting_dialog => Element.find('#config-dialog')
    )
    main = Element.find('main')
    main.ex_resize do
      height = main.height - 8*2 - 4*2
      editor.tree.dom_element(:container).css('height', "#{height}px")
      editor.contents.dom_element(:container).css('height', "#{height}px")
    end

    Element.find('#add-button').on(:click) do
      editor.add_child
    end
  end
end
