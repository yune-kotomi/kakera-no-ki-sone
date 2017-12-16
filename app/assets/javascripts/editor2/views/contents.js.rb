require 'rickdom'

module Editor2
  class Contents < AbstractView
    include CommonLeaf
    include CommonContent

    template <<-EOS
      <div>
        <div class="scroll-container" tabindex="-1">
          <div class="contents mdl-shadow--4dp">
            <div class="root content">
              <div class="display">
                <div class="display">
                  <h3><span class="title">{{:title}}</span></h3>
                  <div class="body-display mdl-typography--body-1"></div>
                </div>
              </div>
              <div class="editor" style="display:none">
                <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
                  <input class="mdl-textfield__input title leaf edit" type="text" value="{{attr:title}}">
                  <label class="mdl-textfield__label">題名...</label>
                </div>

                <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
                  <textarea class="mdl-textfield__input body leaf edit" type="text" rows= "10">{{:body}}</textarea>
                  <label class="mdl-textfield__label">本文...</label>
                </div>

                <div class="footer">
                  <button class="mdl-button mdl-js-button mdl-button--icon close">
                    <i class="material-icons">done</i>
                  </button>
                </div>
              </div>
            </div>

            <div>
              <div class="children"></div>
            </div>
          </div>
        </div>
      </div>
    EOS

    element :display, :selector => 'div.display'
    element :title_display, :selector => 'div.display span.title'
    element :body_display, :selector => 'div.display>.body-display'

    element :editor, :selector => 'div.editor'
    element :title, :selector => 'input.title'
    element :body, :selector => 'textarea.body'
    element :close_button, :selector => 'button.close'

    element :children, :selector => 'div.children', :type => Content
    element :container, :selector => 'div.scroll-container'

    def initialize(attr = {:children => []}, parent)
      super(attr, parent)

      # 入力監視
      # 入力時のパフォーマンスに問題が出るため１秒間隔でemitする
      observe do |name, value|
        @input_action =
          Action.new(
            :operation => :change,
            :target => @id,
            :payload => {name.to_sym => value}
          )
      end
      @emit_input_timer =
        Timer::Timer.new(1) do
          if @input_action
            emit(@input_action)
            @input_action = nil
          end
        end

      dom_element(:display).on(:click){|e| edit }
      dom_element(:close_button).on(:click){|e| show }
    end

    def apply(attr)
      @markup = attr[:markup]
      [:title, :body].map{|n| dom_element(n) }.each{|e| e['data-id'] = @id }
      attr = update_chapter_number(attr)
      apply_body(attr[:body]) unless attributes[:body] == attr[:body]

      super(attr.update(:title_display => attr[:title]))

      # 選択操作
      selected = find(attr[:selected])
      if !selected.visible? && selected.dom_element(:editor).css(:display) == 'none'
        container = dom_element(:container)
        target =
          if selected == self
            selected.dom_element.find('.root.content')
          else
            selected.dom_element
          end
        offset = target.offset.top +
          container.scroll_top - container.offset.top
        container.scroll_top = offset
      end
    end

    def render(text)
      # 記法展開して表示
      html =
        case @markup
        when 'plaintext'
          render_plaintext(text)
        when 'hatena'
          render_hatena(text)
        when 'markdown'
          render_markdown(text)
        else
          raise 'unknown markup'
        end

      # 危険なタグを除去
      RickDOM.new.build(html)
    end

    def root
      self
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

    def next
      attribute_instances[:children].first
    end

    def previous
      nil
    end

    def next_leaf_not_below
      nil
    end
  end
end
