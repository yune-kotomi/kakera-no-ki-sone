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
          <h2><span class="chapter_number">{{:chapter_number}}</span><span class="title">{{:title}}</span></h2>
          <div class="body-display"></div>
          <div class="controls">
            <button class="delete">削除</button>
            <button class="edit">編集</button>
          </div>
          <ul class="tags"></ul>
        </div>
      EOS

      element :chapter_number, :selector => 'h2>span.chapter_number'
      element :title, :selector => 'h2>span.title'
      element :body_display, :selector => 'div.body-display'
      element :edit_button, :selector => 'button.edit'
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
          <div>
            <input type="text" class="title" value="{{attr:title}}">
          </div>
          <div>
            <textarea class="body">{{:body}}</textarea>
          </div>
          <div>
            <input type="text" class="tag-str" value="{{attr:tag_str}}">
          </div>
          <div>
            <button class="close">閉じる</button>
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
      end

      def edit
        dom_element(:title).focus
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
        self.editor = Editor.new(data)
        dom_element.find('.editor-container').append(editor.dom_element)
        editor.observe(:title) {|t| self.title = t }
        editor.observe(:body) {|b| self.body = b }
        editor.observe(:tags) {|t| self.tags = t }

        display.observe(:edit_button, :click) { edit }
        editor.observe(:close_button, :click) { show }

        observe(:target) do |v|
          if v
            dom_element.add_class('target')
            parent.current_target = self.id
          else
            dom_element.remove_class('target')
          end
        end.call(target)

        # 本文領域からフォーカスが外れたら編集終了
        parent.observe(:focused) {|f| show unless f }
      end

      def edit
        dom_element(:display).hide
        dom_element.find('.editor-container').show

        editor.edit
        parent.focused = true
        parent.show
        parent.children.reject{|c| c == self }.each{|c| c.show }
      end

      def show
        dom_element.find('.editor-container').hide
        dom_element(:display).show
      end

      def destroy_clicked
        display.observe(:delete_button, :click) { yield }
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
        destroy_clicked { model.destroy }
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

    class RootDisplay < Display
      template <<-EOS
        <div class="display">
          <h2><span class="title">{{:title}}</span></h2>
          <div class="body-display"></div>
          <div class="controls">
            <button class="edit">編集</button>
          </div>
        </div>
      EOS

      attribute :target, :default => true

      def initialize(data = {}, parent = nil)
        super(data, parent)

        observe(:target) do |t|
          if t
            dom_element.add_class('target')
          else
            dom_element.remove_class('target')
          end
        end.call(target)
      end
    end

    class Contents < Juso::View::Base
      template <<-EOS
        <div class="scroll-container">
          <div class="contents">
            <div class="root">
              <div class="display"></div>
              <div class="editor" style="display:none">
                <div>
                  <input type="text" class="title" value="{{attr:title}}">
                </div>
                <div>
                  <textarea class="body">{{:body}}</textarea>
                </div>
                <div>
                  <button class="close">閉じる</button>
                </div>
              </div>
            </div>
            <div>
              <div class="children"></div>
            </div>
          </div>
        </div>
      EOS

      element :display, :selector => 'div.display', :type => RootDisplay
      element :editor, :selector => 'div.editor'
      element :title, :selector => 'input.title'
      element :body, :selector => 'textarea.body'
      element :close_button, :selector => 'button.close'
      element :children, :selector => 'div.children', :type => Content
      element :container

      attribute :id
      attribute :markup
      attribute :focused, :default => false
      attribute :target, :default => true
      attribute :current_target

      def initialize(data = {}, parent = nil)
        data.update(
          'children' => flatten_children(data['children']).map{|s| s.update(:markup => data[:markup]) },
          'display' => data.select{|k, v| ['title', 'body', 'markup'].include?(k) }
        )
        super(data, parent)

        # ルートノードの編集処理
        observe(:title) {|t| display.title = t }
        observe(:body) {|b| display.body = b }
        display.observe(:edit_button, :click) { edit }
        observe(:close_button, :click) { show }

        # 記法変更
        observe(:markup) do |m|
          display.markup = m
          children.each {|c| c.markup = m }
        end

        # フォーカス
        observe(:focused) do |v|
          if v
            dom_element.find('.contents').add_class('focused')
          else
            dom_element.find('.contents').remove_class('focused')
            show # フォーカスが外れたら編集終了
          end
        end.call(focused)

        # ターゲットの排他処理
        observe(:current_target) do |n, o|
          target = find(n)
          prev_target = find(o)
          target.target = true unless target.nil?
          prev_target.target = false unless prev_target.nil?
        end
        self.current_target = id

        # 自分自身へのターゲット指定
        observe(:target) do |t|
          display.target = t
          self.current_target = id if t
        end.call(target)

        # スクロール
        observe(:current_target) {|t| scroll_to(t) }
      end

      def find(target_id)
        if self.id == target_id
          self
        else
          children.find{|c| c.id == target_id }
        end
      end

      def rearrange(new_order)
        new_list = flatten_children(new_order).
          map{|src| children.find{|c| c.id == src['id'] } }
        children.clear
        children.push(new_list)
        children.flatten!

        # DOM要素の並べ直し
        dom_element(:children).prepend(new_list.first.dom_element)

        (1..new_list.size - 1).each do |i|
          prev = new_list[i - 1]
          current = new_list[i]

          unless prev.dom_element['data-id'] == current.dom_element.prev['data-id']
            prev.dom_element.after(current.dom_element)
          end
        end
      end

      def add_child(target_id, model)
        if model.metadatum && model.metadatum[:tags]
          tags = node.metadatum[:tags]
        else
          tags = []
        end

        new_content = Content.new(model.attributes.update(:tags => tags), self)

        if target_id.nil?
          self.children = [new_content]
        else
          prev_content = find(target_id)
          position = children.index {|c| c.id == target_id }
          children.insert(position + 1, new_content)
          prev_content.dom_element.after(new_content.dom_element)
        end

        new_content.attach(model)

        new_content
      end

      # 可視ノードのIDを返す
      def visible_contents
        # 表示領域
        visible_min = dom_element(:container).offset.top
        visible_max = visible_min + dom_element(:container).height

        ret = children.select {|c| (visible_min < c.offset_bottom && c.offset_bottom <= visible_max) || (visible_min < c.offset_top && c.offset_top <= visible_max) }.map(&:id)

        if (visible_min < offset_bottom && offset_bottom <= visible_max) || (visible_min < offset_top && offset_top <= visible_max)
          ret.push(self.id)
        end

        ret
      end

      def offset_top
        dom_element(:display).offset.top
      end

      def offset_bottom
        offset_top + dom_element(:display).outer_height
      end

      def scroll_to(id)
        target = find(id)
        offset = target.offset_top +
          dom_element(:container).scroll_top -
          dom_element(:container).offset.top
        dom_element(:container).scroll_top = offset
      end

      def edit
        dom_element(:editor).show
        display.dom_element.hide

        dom_element(:title).focus
        self.focused = true
        children.each {|c| c.show }
      end

      def show
        dom_element(:editor).hide
        display.dom_element.show
      end

      def previous
        nil
      end

      def next_content
        children.first
      end

      private
      def flatten_children(src)
        case src
        when Array
          src.map{|e| flatten_children(e) }
        when Hash
          if src['children'].nil?
            [src]
          else
            [src, flatten_children(src['children'])]
          end
        end.flatten
      end
    end
  end
end
