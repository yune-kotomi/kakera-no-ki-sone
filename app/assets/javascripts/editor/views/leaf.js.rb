module Editor
  module View
    class Leaf < Juso::View::Base
      template <<-EOS
      <li class="dd-item" data-id="{{attr:id}}">
        <div class="body">
          <div class="dd-handle">Drag</div>
          <div class="dd-content">
            <span class="chapter_number">{{:chapter_number}}</span>
            <span class="title">{{:title}}</span>
          </div>
        </div>
        <ol class="dd-list" {{if open}}{{else}}style="display:none"{{/if}}></ol>
      </li>
      EOS

      attribute :id
      attribute :target, :default => false
      attribute :open, :default => true
      element :chapter_number, :selector => 'div.dd-content>span.chapter_number'
      element :title, :selector => 'div.dd-content>span.title'
      element :children, :selector => 'ol.dd-list:first', :type => Leaf
      element :collapse, :selector => 'button[data-action="collapse"]'
      element :expand, :selector => 'button[data-action="expand"]'

      def initialize(data = {}, parent = nil)
        if data[:metadatum] && data[:metadatum].has_key?(:open)
          open = data[:metadatum][:open]
        elsif data.has_key?(:open)
          open = data[:open]
        else
          open = true
        end
        data = data.update(:open => open)

        super(data, parent)

        if self.children.nil? || self.children.empty?
          # 子がない場合に不要なものを削除
          dom_element(:children).remove
        end

        # タイトルのクリックでTreeの編集対象にする
        observe(:title, :click) do
          self.target = true
        end

        observe(:target) do |v|
          if v
            dom_element(:title).add_class('selected')
            parental_tree.current_target = self.id
          else
            dom_element(:title).remove_class('selected')
          end
        end

        observe(:open) do |o|
          unless o
            # 閉じた際に子がターゲットだった場合、自分をターゲットにする
            self.target = true if scan{|c| c.target }.include?(true)
          end
        end

        # キーボード・ショートカット
        @hotkeys = Mousetrap::Pool.instance.get("leaf-#{id}")
        up = Mousetrap::Handler.new('up') do |handler|
          handler.condition { parental_tree.focused && self.target }
          handler.procedure do |event|
            # 前のノードにフォーカス
            target = self.visible_previous
            unless target.nil?
              target.target = true
              parental_tree.scroll_to(target.id)
            end
          end
        end
        @hotkeys.bind_handler(up)

        down = Mousetrap::Handler.new('down') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            target = self.visible_next
            unless target.nil?
              target.target = true
              parental_tree.scroll_to(target.id)
            end
          end
        end
        @hotkeys.bind_handler(down)

        left = Mousetrap::Handler.new('left') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            if self.children.empty? || self.open == false
              self.parent.target = true
            else
              collapse
            end
          end
        end
        @hotkeys.bind_handler(left)

        right = Mousetrap::Handler.new('right') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure { expand }
        end
        @hotkeys.bind_handler(right)

        # 兄と入れ替える
        ctrl_up = Mousetrap::Handler.new('mod+up') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            if brother.first
              current_position = parent.children.index(self)
              brother_position = parent.children.index(brother.first)

              new_children = []
              parent.children.each_with_index do |c, i|
                case i
                when current_position
                  new_children.push(brother.first)
                when brother_position
                  new_children.push(self)
                else
                  new_children.push(c)
                end
              end

              parent.children = new_children
            end
          end
        end
        @hotkeys.bind_handler(ctrl_up)

        # 弟と入れ替える
        ctrl_down = Mousetrap::Handler.new('mod+down') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            if brother.last
              current_position = parent.children.index(self)
              brother_position = parent.children.index(brother.last)

              new_children = []
              parent.children.each_with_index do |c, i|
                case i
                when current_position
                  new_children.push(brother.last)
                when brother_position
                  new_children.push(self)
                else
                  new_children.push(c)
                end
              end

              parent.children = new_children
            end
          end
        end
        @hotkeys.bind_handler(ctrl_down)

        ctrl_left = Mousetrap::Handler.new('mod+left') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            if brother.last.nil? && self.parent != parental_tree
              prev_parent = self.parent
              prev_parent.dom_element.after(dom_element)
              parental_tree.rearrange
              prev_parent.disable_child_list if prev_parent.children.empty?
            end
          end
        end
        @hotkeys.bind_handler(ctrl_left)

        ctrl_right = Mousetrap::Handler.new('mod+right') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            b = brother.first
            if b
              b.enable_child_list if b.children.empty?
              b.dom_element(:children).append(dom_element)
              parental_tree.rearrange
            end
          end
        end
        @hotkeys.bind_handler(ctrl_right)

        ctrl_del = Mousetrap::Handler.new('mod+del') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            Dialog::Confirm.new('葉の削除', "#{self.chapter_number} #{self.title} を削除してよろしいですか?", 'はい', 'いいえ') do |d|
              d.ok { @model.destroy }
            end.open
          end
        end
        @hotkeys.bind_handler(ctrl_del)
      end

      def ==(value)
        if value.is_a?(self.class)
          self.id == value.id
        end
      end

      def scan(&block)
        ret = [block.call(self)]
        ret.push children.map {|c| c.scan(&block) }
        ret.flatten
      end

      def find(target_id)
        if id == target_id
          self
        else
          children.map{|c| c.find(target_id) }.compact.first
        end
      end

      def add_child(position, model)
        new_child = Leaf.new(model.attributes, self)
        children.insert(position, new_child)
        if dom_element(:children).nil?
          element = Element.new('ol')
          element.add_class('dd-list')
          dom_element.append(element)
        end

        if position == 0
          dom_element(:children).prepend(new_child.dom_element)
        else
          dom_element(:children).children.at(position - 1).after(new_child.dom_element)
        end

        new_child.attach(model)

        # Treeのcurrent orderを更新しておく
        parental_tree.update_order_silently

        new_child
      end

      def attach(model)
        @model = model

        # 変更内容伝搬用
        model.observe(:title) {|v| self.title = v }
        model.observe(:chapter_number) {|c| self.chapter_number = c }
        observe(:open) {|o| model.metadatum = model.metadatum.clone.update(:open => o) }

        # 削除
        model.observe(nil, :destroy) do
          self.destroy
          parent.disable_child_list if parent.children.empty? && !parent.is_a?(Tree)
        end

        model
      end

      def destroy
        # 選択状態の切り替え
        if self.target
          position = parent.children.index(self)
          if position > 0
            parent.children[position - 1].target = true
          else
            parent.target = true
          end
        end

        parent.children.delete(self)
        self.dom_element.remove
        parental_tree.update_order_silently

        self
      end

      def parental_tree
        if self.parent.is_a?(Tree)
          self.parent
        else
          self.parent.parental_tree
        end
      end

      def brother
        position = parent.children.index(self)
        if position == 0
          elder = nil
        else
          elder = parent.children[position - 1]
        end
        younger = parent.children[position + 1]

        [elder, younger]
      end

      def visible_previous
        if brother.first
          brother.first.last_child(true)
        else
          parent
        end
      end

      def last_child(visible = false)
        if children.empty? || (self.open == false && visible)
          self
        else
          children.last.last_child(visible)
        end
      end

      def visible_next(force_close = false)
        if self.open && force_close == false && !children.empty?
          children.first
        else
          if brother.last
            brother.last
          else
            parent.visible_next(true)
          end
        end
      end

      def fade
        dom_element(:chapter_number).effect(:fade_to, 'fast', 0.3)
        dom_element(:title).effect(:fade_to, 'fast', 0.3)
      end

      def unfade
        dom_element(:chapter_number).effect(:fade_to, 'fast', 1)
        dom_element(:title).effect(:fade_to, 'fast', 1)
      end

      def offset_top
        dom_element(:title).offset.top
      end

      def offset_bottom
        offset_top + dom_element(:title).outer_height
      end

      def observe_open_close
        dom_element(:collapse).on(:click) { self.open = false; true } if dom_element(:collapse)
        dom_element(:expand).on(:click) { self.open = true; true } if dom_element(:expand)
      end

      def collapse
        if dom_element(:children)
          dom_element(:expand).show
          dom_element(:collapse).hide
          dom_element(:children).hide
          self.open = false
        end
      end

      def expand
        if dom_element(:children)
          dom_element(:expand).hide
          dom_element(:collapse).show
          dom_element(:children).show
          self.open = true
        end
      end

      # 子がある状態に表示をあわせる
      def enable_child_list
        ol = Element.new('ol')
        ol.add_class('dd-list')
        dom_element.append(ol)

        collapse_button = Element.new('button')
        collapse_button['type'] = 'button'
        collapse_button['data-action'] = 'collapse'
        collapse_button.css('display', 'block')
        collapse_button.text = 'Collapse'
        dom_element.find('.dd-handle').before(collapse_button)

        expand_button = Element.new('button')
        expand_button['type'] = 'button'
        expand_button['data-action'] = 'expand'
        expand_button.hide
        expand_button.text = 'Expand'
        dom_element.find('.dd-handle').before(expand_button)
      end

      # 子がない状態に表示をあわせる
      def disable_child_list
        dom_element.find('[data-action="collapse"]:first').remove
        dom_element.find('[data-action="expand"]:first').remove
        dom_element(:children).remove
      end
    end
  end
end
