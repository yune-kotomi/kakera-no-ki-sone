module Editor2
  class Content < AbstractView
    template <<-EOS
      <div class="content">
        <div class="display-container">
          <div class="display">
            <h4>
              <span class="chapter_number">{{:chapter_number}}</span>
              <span class="title">{{:title}}</span>
            </h4>
            <div class="body-display mdl-typography--body-1"></div>

            <div class="footer">
              <button class="mdl-button mdl-js-button mdl-button--icon delete">
                <i class="material-icons">delete</i>
              </button>
            </div>
          </div>
        </div>

        <div class="editor-container" style="display:none">
          <div class="editor">
            <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
              <input class="mdl-textfield__input title leaf edit" type="text" value="{{attr:title}}">
              <label class="mdl-textfield__label">題名...</label>
            </div>

            <div class="footer">
              <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
              <textarea class="mdl-textfield__input body leaf edit" type="text" rows= "10">{{:body}}</textarea>
              <label class="mdl-textfield__label">本文...</label>
              </div>

              <button class="mdl-button mdl-js-button mdl-button--icon close">
                <i class="material-icons">close</i>
              </button>
            </div>
          </div>
        </div>
      </div>
    EOS

    element :display, :selector => '.display'
    element :chapter_number, :selector => '.display span.chapter_number'
    element :title_display, :selector => '.display span.title'
    element :body_display, :selector => '.display div.body-display'
    element :delete_button, :selector => 'button.delete'

    element :editor, :selector => '.editor-container'
    element :title, :selector => '.editor>div>input.title'
    element :body, :selector => '.editor div.footer textarea.body'
    element :close_button, :selector => '.editor button.close'

    def initialize(attr, parent)
      super(attr, parent)

      # 入力監視
      observe do |name, value|
        emit(Action.new(
        :operation => :change,
        :target => @id,
        :payload => {name.to_sym => value}
        ))
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
      end
    end

    def apply(attr)
      dom_element.remove_class('mdl-shadow--4dp')
      [:title, :body].map{|n| dom_element(n) }.each{|e| e['data-id'] = @id }

      apply_body(attr[:body]) unless attributes[:body] == attr[:body]
      super(attr.update(:title_display => attr[:title]))
    end

    def apply_body(src)
      unless dom_element(:display).css(:display) == 'none'
        html = parent.render(src)
        dom_element(:body_display).html = html
      end
    end

    def show
      dom_element(:display).show
      dom_element(:editor).hide
      apply_body(attributes[:body])
    end

    def edit(focus = :title)
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

    def visible?
      container = parent.dom_element(:container)
      min = container.offset.top
      max = min + container.height.to_i
      d = dom_element

      min < d.offset.top && d.offset.top + d.outer_height < max
    end

    def select
      dom_element.add_class('mdl-shadow--4dp')
    end

    def next
      children = parent.attribute_instances[:children]
      index = children.index(self)
      children[index + 1]
    end

    def previous
      children = parent.attribute_instances[:children]
      index = children.index(self)
      if index == 0
        parent
      else
        children[index - 1]
      end
    end
  end
end
