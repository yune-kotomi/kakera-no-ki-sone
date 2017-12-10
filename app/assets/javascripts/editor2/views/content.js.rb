module Editor2
  class Content < AbstractView
    include CommonLeaf
    include CommonContent

    template <<-EOS
      <div class="content">
        <hr>
        <div class="display-container">
          <div class="display">
            <h4>
              <span class="chapter_number">{{:chapter_number}}</span>
              <span class="title">{{:title}}</span>
            </h4>
            <div class="body-display mdl-typography--body-1"></div>
          </div>
        </div>

        <div class="editor-container" style="display:none">
          <div class="editor">
            <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
              <input class="mdl-textfield__input title leaf edit" type="text" value="{{attr:title}}">
              <label class="mdl-textfield__label">題名...</label>
            </div>

            <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
              <textarea class="mdl-textfield__input body leaf edit" type="text" rows= "10">{{:body}}</textarea>
              <label class="mdl-textfield__label">本文...</label>
            </div>

            <div class="footer">
              <button class="mdl-button mdl-js-button mdl-button--icon delete">
                <i class="material-icons">delete</i>
              </button>

              <button class="mdl-button mdl-js-button mdl-button--icon close">
                <i class="material-icons">done</i>
              </button>
            </div>
          </div>
        </div>

        <ol class="children"></ol>
      </div>
    EOS

    element :display, :selector => '.display'
    element :chapter_number, :selector => '.display span.chapter_number'
    element :title_display, :selector => '.display span.title'
    element :body_display, :selector => '.display div.body-display'
    element :delete_button, :selector => 'button.delete'

    element :editor, :selector => '.editor-container'
    element :title, :selector => 'input.title'
    element :body, :selector => 'textarea.body'
    element :close_button, :selector => '.editor button.close'

    element :children, :selector => 'ol.children', :type => Content

    def initialize(attr, parent)
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
      dom_element(:delete_button).on(:click) do |e|
        children = parent.attribute_instances[:children]
        previous =
          if children.first == self
            parent.id
          else
            children[children.index(self) - 1].id
          end

        emit(Action.new(
          :operation => :remove,
          :target => id
        ),
        Action.new(
          :operation => :select,
          :target => previous
        ))

        `history.back()` if ::Editor2::Editor.phone? && `history.state` == 'edit'
      end
    end

    def apply(attr)
      [:title, :body].map{|n| dom_element(n) }.each{|e| e['data-id'] = @id }

      attr = update_chapter_number(attr)
      apply_body(attr[:body]) unless attributes[:body] == attr[:body]
      super(attr.update(:title_display => attr[:title]))
    end

    def next
      child = attribute_instances[:children].first
      brother = younger_brother
      if child.nil?
        if brother.nil?
          parent.next_leaf_not_below
        else
          brother
        end
      else
        child
      end
    end

    def previous
      brother = elder_brother
      if brother
        brother.last_child
      else
        parent
      end
    end
  end
end
