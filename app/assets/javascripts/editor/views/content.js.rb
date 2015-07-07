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
          <h2><span class="number">{{:number}}</span><span class="title">{{:title}}</span></h2>
          <div class="body-display"></div>
          <ul class="tags"></ul>
        </div>
      EOS

      element :number, :selector => 'h2>span.number'
      element :title, :selector => 'h2>span.title'
      element :body_display, :selector => 'div.body-display'
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
        text = src
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
        </div>
      EOS

      element :title, :selector => 'div>input.title'
      element :body, :selector => 'div>textarea.body'
      element :tag_str, :selector => 'div>input.tag-str'

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
        <div class="content">
          <div class="display-container"></div>
          <div class="editor-container" style="display:none"></div>
        </div>
      EOS

      element :display, :selector => '.display-container', :type => Display

      attribute :number
      attribute :title
      attribute :body
      attribute :mode, :default => 'plaintext'
      attribute :tags, :default => []

      attr_accessor :editor

      def initialize(data = {}, parent = nil)
        super(data, parent)

        # displayと結合
        self.display = Display.new(
          data.merge(:tags => data[:tags].map{|t| {:str => t} })
        )
        observe(:number) {|n| display.number = n }
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
      end

      def edit
        dom_element(:display).hide
        dom_element.find('.editor-container').show
      end

      def show
        dom_element.find('.editor-container').hide
        dom_element(:display).show
      end
    end

    class Contents < Juso::View::Base
    end
  end
end
