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

      attribute :mode, :default => 'plaintext'
      attribute :body, :default => ''

      def initialize(data = {}, parent = nil)
        super(data, parent)

        observe(:body) do |body|
          # 記法展開して表示
          case mode
          when 'plaintext'
            self.body_display = render_plaintext(body)
          else
            raise UnknownMarkupError.new({})
          end
        end.call(self.body)
      end

      private
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
      attribute :mode, :default => 'plaintext'
      attribute :tags, :default => []

      attr_accessor :editor

      def initialize(data = {}, parent = nil)
        super(data, parent)

        # displayと結合
        self.display = Display.new(
          data.merge(:tags => (data[:tags]||[]).map{|t| {:str => t} })
        )
        observe(:chapter_number) {|n| display.chapter_number = n }
        observe(:title) {|t| display.title = t }
        observe(:mode) {|m| display.mode = m }
        observe(:body) {|b| display.body = b }
        observe(:tags) {|t| display.tags = t }

        # editorと結合
        self.editor = Editor.new(data)
        dom_element.find('.editor-container').append(editor.dom_element)
        editor.observe(:title) {|t| self.title = t }
        editor.observe(:body) {|b| self.body = b }
        editor.observe(:tags) {|t| self.tags = t.map{|s| {:str => s} } }

        display.observe(:edit_button, :click) { edit }
        editor.observe(:close_button, :click) { show }
      end

      def edit
        dom_element(:display).hide
        dom_element.find('.editor-container').show
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
    end

    class Contents < Juso::View::Base
      template <<-EOS
        <div>
          <div class="children"></div>
        </div>
      EOS

      element :children, :selector => 'div.children', :type => Content

      def initialize(data = {}, parent = nil)
        data['children'] = flatten_children(data['children'])
        super(data, parent)
      end

      def find(target_id)
        children.find{|c| c.id == target_id }
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
        new_content = Content.new(model.attributes, self)

        if target_id.nil?
          self.children = [new_content]
        else
          prev_content = find(target_id)
          position = children.index {|c| c.id == target_id }
          children.insert(position + 1, new_content)
          prev_content.dom_element.after(new_content.dom_element)
        end

        new_content.observe(:title) {|v| model.title = v }
        new_content.observe(:body) {|v| model.body = v }
        new_content.destroy_clicked { model.destroy }
        model.observe(nil, :destroy) { model.scan{|n| find(n.id).destroy } }
        model.observe(:chapter_number) {|c| new_content.chapter_number = c }

        new_content
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
