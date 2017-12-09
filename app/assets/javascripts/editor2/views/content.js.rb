module Editor2
  class Content < AbstractView
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
      # 章番号
      (attr[:children] || []).each_with_index do |c, i|
        c[:chapter_number] = "#{attr[:chapter_number]}.#{i + 1}"
      end

      apply_body(attr[:body]) unless attributes[:body] == attr[:body]
      super(attr.update(:title_display => attr[:title]))
    end

    def apply_body(src)
      unless dom_element(:display).css(:display) == 'none'
        html = root.render(src)
        dom_element(:body_display).html = html
      end
    end

    def show
      @emit_input_timer.stop
      @emit_input_timer.execute # 滞留しているactionを実行

      dom_element(:display).show
      dom_element(:editor).hide
      apply_body(attributes[:body])

      `history.back()` if ::Editor2::Editor.phone? && `history.state` == 'edit'
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

      %x{ history.pushState('edit', null, '#edit') } if ::Editor2::Editor.phone? && `history.state` == 'contents'
    end

    def root
      parents.find{|c| c.is_a?(Contents) }
    end

    def parents
      [parent, parent.parents].flatten
    end

    def visible?
      container = root.dom_element(:container)
      min = container.offset.top
      max = min + container.height.to_i
      d = dom_element(:display)

      min < d.offset.top && d.offset.top + d.outer_height < max
    end

    def find(id)
      if @id == id
        self
      else
        attribute_instances[:children].
          map{|c1| c1.find(id) }.
          compact.
          first
      end
    end

    # 親のchildrenにおけるインデックスを返す
    def index
      parent.attribute_instances[:children].index(self)
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

    # 自分を頂点とした部分木の一番下
    def last_child
      c = attribute_instances[:children].last
      if c
        c.last_child
      else
        self
      end
    end

    # 自分と同じか自分より上の階層で次に位置する葉
    def next_leaf_not_below
      younger_brother || parent.next_leaf_not_below
    end

    private
    def elder_brother
      parent.attribute_instances[:children][index - 1] if index > 0
    end

    def younger_brother
      parent.attribute_instances[:children][index + 1] if index < parent.attribute_instances[:children].size - 1
    end
  end
end
