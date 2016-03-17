module Editor
  module View
    class RootDisplay < Display
      template <<-EOS
        <div class="display">
          <h3><span class="title">{{:title}}</span></h3>
          <div class="body-display mdl-typography--body-1"></div>
        </div>
      EOS
    end

    class Contents < Juso::View::Base
      template <<-EOS
        <div>
          <div class="scroll-container" tabindex="-1">
            <div class="contents">
              <div class="root content">
                <div class="display"></div>
                <div class="editor" style="display:none">
                  <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
                    <input class="mdl-textfield__input title" type="text" value="{{attr:title}}">
                    <label class="mdl-textfield__label">題名...</label>
                  </div>

                  <div class="footer">
                    <div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">
                      <textarea class="mdl-textfield__input body" type="text" rows= "10">{{:body}}</textarea>
                      <label class="mdl-textfield__label">本文...</label>
                    </div>
                    <button class="mdl-button mdl-js-button mdl-button--icon close">
                      <i class="material-icons">close</i>
                    </button>
                  </div>
                </div>
              </div>
              <div>
                <div class="children"></div>
              </div>
              <div class="right-bottom-fab-spacer"></div>
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
      element :container, :selector => 'div.scroll-container'

      attribute :id
      attribute :markup
      attribute :focused, :default => false
      attribute :target, :default => true
      attribute :visible, :default => true
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
        display.observe(:edit_button, :event => :click) { edit }
        observe(:close_button, :event => :click) { show }

        # 記法変更
        observe(:markup) do |m|
          display.markup = m
          children.each {|c| c.markup = m }
        end

        # フォーカス
        observe(:focused) do |v|
          show unless v

          if v && target
            dom_element.find('.root.content').add_class('mdl-shadow--4dp')
          else
            dom_element.find('.root.content').remove_class('mdl-shadow--4dp')
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
          if t
            self.current_target = id
          else
            show # 自分自身がターゲットから外れたら編集終了
          end
          if t && focused
            dom_element.find('.root.content').add_class('mdl-shadow--4dp')
          else
            dom_element.find('.root.content').remove_class('mdl-shadow--4dp')
          end
        end.call(target)

        # スクロール
        observe(:current_target) {|t| scroll_to(t) unless visible_contents.include?(t) } unless ::Editor.phone?

        observe(:visible) do |v|
          if v
            dom_element.show
            scroll_to(current_target)
          else
            dom_element.hide
          end
        end.call(visible)

        @hotkeys = Mousetrap::Pool.instance.get("content-#{id}")
        down = Mousetrap::Handler.new('down') do |handler|
          handler.condition { self.focused && self.target && !self.edit? }
          handler.procedure { next_content.target = true unless next_content.nil? }
        end
        @hotkeys.bind_handler(down)

        # 入力ボックスにフォーカスがあっても発動させるもの
        @force_hotkeys = Mousetrap::Pool.instance.get("content-#{id}-force")
        @hotkeys.set_stop_callback { false }
        escape = Mousetrap::Handler.new('escape') do |handler|
          handler.condition { focused && self.target }
          handler.procedure { show }
        end
        @hotkeys.bind_handler(escape)

        @content_hotkey = Mousetrap::Pool.instance.get("content-#{id}-content")
        @content_hotkey.set_stop_callback do |e, element|
          `element != #{self.dom_element(:body).get(0)}`
        end
        tab = Mousetrap::Handler.new('tab') do |h|
          h.condition { self.next_content }
          h.procedure { self.next_content.edit }
        end
        @content_hotkey.bind_handler(tab)
      end

      def find(target_id)
        if self.id == target_id
          self
        else
          children.find{|c| c.id == target_id }
        end
      end

      def rearrange(new_order)
        new_list = new_order.map{|id| find(id) }
        children.clear
        children.push(new_list)
        children.flatten!

        new_list.each{|c| dom_element(:children).append(c.dom_element) }
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

        new_content
      end

      # 可視ノードのIDを返す
      def visible_contents
        # 表示領域
        visible_min = dom_element(:container).offset.top
        visible_max = visible_min + dom_element(:container).height.to_i

        ret = children.select {|c| (visible_min < c.offset_top && c.offset_top <= visible_max) || (visible_min < c.offset_bottom && c.offset_bottom <= visible_max) }.map(&:id)

        if visible_min < offset_top && offset_bottom <= visible_max
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
        if ::Editor.phone?
          # MDLヘッダ+アドレスバーの分下げる
          offset = target.offset_top - Element.find('header').outer_height*2
          `$(window).scrollTop(#{offset})`
        else
          offset = target.offset_top +
            dom_element(:container).scroll_top -
            dom_element(:container).offset.top
          dom_element(:container).scroll_top = offset
        end
      end

      def edit(focus_to_last = false)
        dom_element(:editor).show
        display.dom_element.hide

        if focus_to_last
          `setTimeout(function(){#{dom_element(:body).focus}}, 10)`
        else
          `setTimeout(function(){#{dom_element(:title).focus}}, 10)`
        end
        self.focused = true
        self.target = true

        if ::Editor.phone?
          %x{ history.pushState('edit', null, '#edit') }
        end
      end

      def edit?
        dom_element(:editor).css('display') == 'block'
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
