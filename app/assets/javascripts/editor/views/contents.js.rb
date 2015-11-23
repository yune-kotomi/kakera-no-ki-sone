module Editor
  module View
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
          if t
            self.current_target = id
          else
            show # 自分自身がターゲットから外れたら編集終了
          end
        end.call(target)

        # スクロール
        observe(:current_target) {|t| scroll_to(t) }

        @hotkeys = Mousetrap::Pool.instance.get("content-#{id}")
        down = Mousetrap::Handler.new('down') do |handler|
          handler.condition { self.focused && self.target }
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

      def edit(focus_to_last = false)
        dom_element(:editor).show
        display.dom_element.hide

        if focus_to_last
          dom_element(:body).focus
        else
          dom_element(:title).focus
        end
        self.focused = true
        self.target = true
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
