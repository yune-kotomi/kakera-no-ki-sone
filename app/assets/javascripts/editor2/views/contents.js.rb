require 'rickdom'

module Editor2
  class Contents < AbstractView
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
      # 章番号
      (attr[:children] || []).each_with_index do |c, i|
        c[:chapter_number] = i + 1
      end

      apply_body(attr[:body]) unless attributes[:body] == attr[:body]

      super(attr.update(:title_display => attr[:title]))

      # 選択操作
      selected =
        if attr[:selected] == @id
          self
        else
          attribute_instances[:children].
            map{|c1| c1.find(attr[:selected]) }.
            compact.
            first
        end

      unless selected.visible?
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

    def show
      @emit_input_timer.stop
      @emit_input_timer.execute # 滞留しているactionを実行

      dom_element(:display).show
      dom_element(:editor).hide
      apply_body(attributes[:body])
    end

    def edit(focus = :title)
      @emit_input_timer.start

      dom_element(:display).hide
      dom_element(:editor).show
      emit(Action.new(
        :operation => :select,
        :target => @id
      ))

      if focus == :title
        dom_element(:title).focus
      else
        dom_element(:body).focus
      end

      %x{ history.pushState('edit', null, '#edit') } if ::Editor2::Editor.phone?
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

    def visible?
      false
    end

    def parents
      [parent]
    end

    # 全ての本文を強制更新
    def refresh!
      apply_body(attributes[:body])
      attribute_instances[:children].each{|c| c.apply_body(c.attributes[:body]) }
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

    def apply_body(body)
      unless dom_element(:display).css(:display) == 'none'
        html = render(body)
        dom_element(:body_display).html = html
      end
    end

    def find(id)
      if id == @id
        self
      else
        attribute_instances[:children].map{|c| c.find(id) }.compact.first
      end
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
