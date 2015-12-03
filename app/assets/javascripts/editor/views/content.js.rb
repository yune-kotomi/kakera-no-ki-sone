require 'rickdom'

module Editor
  module View
    class Tag < Juso::View::Base
      template <<-EOS
        <li class="tag">{{:str}}</li>
      EOS

      element :str
    end

    class Display < Juso::View::Base
      template <<-EOS
        <div class="display">
          <h4>
            <span class="chapter_number">{{:chapter_number}}</span>
            <span class="title">{{:title}}</span>
          </h4>
          <div class="body-display mdl-typography--body-1"></div>

          <div class="footer">
            <ul class="tags"></ul>
            <button class="mdl-button mdl-js-button mdl-button--icon delete">
              <i class="material-icons">delete</i>
            </button>
          </div>
        </div>
      EOS

      element :chapter_number, :selector => 'span.chapter_number'
      element :title, :selector => 'span.title'
      element :body_display, :selector => 'div.body-display'
      element :edit_button
      element :delete_button, :selector => 'button.delete'
      element :tags, :selector => 'ul.tags', :default => [], :type => Tag

      attribute :markup, :default => 'plaintext'
      attribute :body, :default => ''

      def initialize(data = {}, parent = nil)
        super(data, parent)

        observe(:body) {|b| render(self.markup, b) }
        observe(:markup) {|m| render(m, self.body) }.call(self.markup)
      end

      private
      def render(markup, text)
        # 記法展開して表示
        html = case markup
        when 'plaintext'
          render_plaintext(body)
        when 'hatena'
          render_hatena(body)
        when 'markdown'
          render_markdown(body)
        else
          raise UnknownMarkupError.new({})
        end

        # 危険なタグを除去
        self.body_display = RickDOM.new.build(html)
      end

      def render_plaintext(src)
        text = src.to_s
        ({
          '&' => '&amp;',
          '>' => '&gt;',
          '<' => '&lt;',
          '"' => '&quot;',
          "'" => '&#39;',
          ' ' => '&nbsp;',
          "\n" => '<br>'
        }).each do |k, v|
          text = text.gsub(k, v)
        end
        text
      end

      def render_hatena(src)
        parser = Text::Hatena.new(:sectionanchor => "■")
        parser.parse(src)
        parser.to_html
      end

      def render_markdown(src)
        parser = Markdown::Parser.new
        parser.parse(src)
        parser.to_html
      end

      class UnknownMarkupError < StandardError; end
    end

    class Editor < Juso::View::Base
      template <<-EOS
        <div class="editor">
          <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
            <input class="mdl-textfield__input title" type="text" value="{{attr:title}}">
            <label class="mdl-textfield__label">題名...</label>
          </div>

          <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
            <textarea class="mdl-textfield__input body" type="text" rows= "10">{{:body}}</textarea>
            <label class="mdl-textfield__label">本文...</label>
          </div>

          <div class="footer">
            <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
              <input class="mdl-textfield__input tag-str" type="text" value="{{attr:title}}">
              <label class="mdl-textfield__label">タグ...</label>
            </div>

            <button class="mdl-button mdl-js-button mdl-button--icon close">
              <i class="material-icons">close</i>
            </button>
          </div>
        </div>
      EOS

      element :title, :selector => 'div>input.title'
      element :body, :selector => 'div>textarea.body'
      element :tag_str, :selector => 'div>input.tag-str'
      element :close_button, :selector => 'button.close'

      attribute :tags, :default => []

      def initialize(data = {}, parent = nil)
        super(data, parent)

        observe(:tag_str) do |tag_str|
          # タグ入力ボックスの入力内容を分解して格納する
          self.tags = tag_str.split(/ +/)
        end

        observe(:tags) do |tags|
          # 与えられたタグを結合して入力ボックスに投入
          self.tag_str = tags.join(' ')
        end.call(self.tags)

        # キーボード・ショートカット
        @title_hotkey = Mousetrap::Pool.instance.get("editor-#{parent.id}-title")
        @title_hotkey.set_stop_callback do |e, element, combo|
          `element != #{self.dom_element(:title).get(0)}`
        end
        # Shift+Tabで前のノードを編集対象にし、タグ入力ボックスにフォーカスを当てる
        shift_tab = Mousetrap::Handler.new('shift+tab') do |h|
          h.condition { parent.previous }
          h.procedure { parent.previous.edit(true) }
        end
        @title_hotkey.bind_handler(shift_tab)

        @tag_hotkey = Mousetrap::Pool.instance.get("editor-#{parent.id}-tag")
        @tag_hotkey.set_stop_callback do |e, element, combo|
          `element != #{self.dom_element(:tag_str).get(0)}`
        end
        # Tabで次のノードを編集対象にし、タイトル入力ボックスにフォーカスを当てる
        tab = Mousetrap::Handler.new('tab') do |h|
          h.condition { parent.next_content }
          h.procedure { parent.next_content.edit }
        end
        @tag_hotkey.bind_handler(tab)
      end

      def edit(focus_to_last = false)
        if focus_to_last
          dom_element(:tag_str).focus
        else
          dom_element(:title).focus
        end
      end
    end

    class Content < Juso::View::Base
      template <<-EOS
        <div class="content" data-id="{{:id}}">
          <div class="display-container"></div>
          <div class="editor-container" style="display:none"></div>
        </div>
      EOS

      element :display, :selector => '.display-container', :type => Display

      attribute :id
      attribute :chapter_number
      attribute :title
      attribute :body
      attribute :markup, :default => 'plaintext'
      attribute :tags, :default => []
      attribute :target, :default => false

      attr_accessor :editor

      def initialize(data = {}, parent = nil)
        super(data, parent)

        # displayと結合
        self.display = Display.new(
          data.merge(:tags => (data[:tags]||[]).map{|t| {:str => t} })
        )
        observe(:chapter_number) {|n| display.chapter_number = n }
        observe(:title) {|t| display.title = t }
        observe(:markup) {|m| display.markup = m }
        observe(:body) {|b| display.body = b }
        observe(:tags) {|t| display.tags = (t||[]).map{|s| {:str => s} } }

        # editorと結合
        self.editor = Editor.new(data, self)
        dom_element.find('.editor-container').append(editor.dom_element)
        editor.observe(:title) {|t| self.title = t }
        editor.observe(:body) {|b| self.body = b }
        editor.observe(:tags) {|t| self.tags = t }

        display.observe(:edit_button, :click) { edit }
        editor.observe(:close_button, :click) { show }

        observe(:target) do |v|
          if v
            parent.current_target = self.id
          else
            show # 編集を終了する
          end

          if v && parent.focused
            dom_element.add_class('mdl-shadow--4dp')
          else
            dom_element.remove_class('mdl-shadow--4dp')
          end
        end.call(target)

        # 本文領域からフォーカスが外れたら編集終了
        parent.observe(:focused) do |f|
          show unless f

          if f && target
            dom_element.add_class('mdl-shadow--4dp')
          else
            dom_element.remove_class('mdl-shadow--4dp')
          end
        end

        # キーボード・ショートカット
        @hotkeys = Mousetrap::Pool.instance.get("content-#{id}")
        up = Mousetrap::Handler.new('up') do |handler|
          handler.condition { parent.focused && self.target }
          handler.procedure { previous.target = true unless previous.nil? }
        end
        @hotkeys.bind_handler(up)

        down = Mousetrap::Handler.new('down') do |handler|
          handler.condition { parent.focused && self.target }
          handler.procedure { next_content.target = true unless next_content.nil? }
        end
        @hotkeys.bind_handler(down)

        # 入力ボックスにフォーカスがあっても発動させるもの
        @force_hotkeys = Mousetrap::Pool.instance.get("content-#{id}-force")
        @hotkeys.set_stop_callback { false }
        escape = Mousetrap::Handler.new('escape') do |handler|
          handler.condition { parent.focused && self.target }
          handler.procedure { show }
        end
        @hotkeys.bind_handler(escape)
      end

      def edit(focus_to_last = false)
        dom_element(:display).hide
        dom_element.find('.editor-container').show

        editor.edit(focus_to_last)
        parent.focused = true
        self.target = true
      end

      def show
        dom_element.find('.editor-container').hide
        dom_element(:display).show
      end

      def destroy
        parent.children.delete(self)
        self.dom_element.remove
        self
      end

      def fade
        dom_element.effect(:fade_to, 'fast', 0.3)
      end

      def unfade
        dom_element.effect(:fade_to, 'fast', 1)
      end

      def offset_top
        dom_element.offset.top
      end

      def offset_bottom
        offset_top + dom_element.outer_height
      end

      def attach(model)
        observe(:title) {|v| model.title = v }
        observe(:body) {|v| model.body = v }
        observe(:tags) {|t| model.metadatum = model.metadatum.clone.update('tags' => t) }
        display.observe(:delete_button, :click) do
          Dialog::Confirm.new('葉の削除', "#{self.chapter_number} #{self.title} を削除してよろしいですか?", 'はい', 'いいえ') do |d|
            d.ok { model.destroy }
          end.open
        end
        # 表示領域はツリー上の親子関係を持たないのでnodeが持つ子をすべて明示的に消す
        model.observe(nil, :destroy) { model.scan{|n| parent.find(n.id).destroy } }
        model.observe(:chapter_number) {|c| self.chapter_number = c }
      end

      def previous
        position = @parent.children.index(self)
        if position == 0
          @parent
        else
          @parent.children[position - 1]
        end
      end

      def next_content
        position = @parent.children.index(self)
        @parent.children[position + 1]
      end
    end
  end
end
