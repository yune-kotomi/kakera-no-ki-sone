module Editor
  module View
    class Leaf < Juso::View::Base
      template <<-EOS
      <li class="leaf" data-id="{{attr:id}}">
        <div class="body">
          <div class="handle" data-id="{{attr:id}}"><i class="material-icons">drag_handle</i></div>

          <button class="mdl-button mdl-js-button mdl-button--icon expand" {{if open}}style="display:none"{{/if}}>
            <i class="material-icons more">expand_more</i>
          </button>
          <button class="mdl-button mdl-js-button mdl-button--icon collapse" {{if open}}{{else}}style="display:none"{{/if}}>
            <i class="material-icons less">expand_less</i>
          </button>

          <div class="content">
            <span class="chapter_number">{{:chapter_number}}</span>
            <span class="title">{{:title}}</span>
          </div>
        </div>

        <div class="brother-droppable"></div>
        <ol class="children" {{if open}}{{else}}style="display:none"{{/if}}></ol>
      </li>
      EOS

      attribute :id
      attribute :target, :default => false
      attribute :open, :default => true
      element :chapter_number, :selector => 'span.chapter_number'
      element :title, :selector => 'span.title'
      element :content, :selector => 'div.content'
      element :children, :selector => 'ol.children', :type => Leaf
      element :collapse, :selector => 'button.collapse'
      element :expand, :selector => 'button.expand'

      attr_reader :model

      custom_events :destroy

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
        # タイトルのクリックでTreeの編集対象にする
        observe(:content, :event => :click) do
          if ::Editor.phone?
            # Editor#switch_to_contents
            parental_tree.parent.switch_to_contents
            %x{ history.pushState('contents', null, '#contents') }
          end
          self.target = true
        end

        observe(:target) do |v|
          if v
            dom_element(:content).add_class('selected')
            parental_tree.current_target = self.id
            parents.each{|p| p.open = true unless p.is_a?(Tree) }
          else
            dom_element(:content).remove_class('selected')
          end
        end

        # 開閉処理
        observe(:expand, :event => :click) { self.open = true }
        observe(:collapse, :event => :click) { self.open = false }
        observe(:open) do |o|
          if o
            expand
          else
            collapse
            # 閉じた際に子がターゲットだった場合、自分をターゲットにする
            self.target = true if scan{|c| c.target }.include?(true)
          end
        end.call(open)
        update_expand_collapse_buttons

        draggable_init

        # キーボード・ショートカット
        @hotkeys = Mousetrap::Pool.instance.get("leaf-#{id}")
        up = Mousetrap::Handler.new('up') do |handler|
          handler.condition { parental_tree.focused && self.target }
          handler.procedure do |event|
            # 前のノードにフォーカス
            target = self.visible_previous
            target.target = true unless target.nil?
          end
        end
        @hotkeys.bind_handler(up)

        down = Mousetrap::Handler.new('down') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            target = self.visible_next
            target.target = true unless target.nil?
          end
        end
        @hotkeys.bind_handler(down)

        left = Mousetrap::Handler.new('left') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            if self.children.empty? || self.open == false
              self.parent.target = true
            else
              self.open = false
            end
          end
        end
        @hotkeys.bind_handler(left)

        right = Mousetrap::Handler.new('right') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure { self.open = true }
        end
        @hotkeys.bind_handler(right)

        # 兄と入れ替える
        ctrl_up = Mousetrap::Handler.new('mod+up') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            elder = brother.first
            brother_dropped(elder.id) if elder
          end
        end
        @hotkeys.bind_handler(ctrl_up)

        # 弟と入れ替える
        ctrl_down = Mousetrap::Handler.new('mod+down') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            younger = brother.last
            younger.brother_dropped(id) if younger
          end
        end
        @hotkeys.bind_handler(ctrl_down)

        ctrl_left = Mousetrap::Handler.new('mod+left') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            if brother.last.nil? && self.parent != parental_tree
              self.parent.brother_dropped(id)
            end
          end
        end
        @hotkeys.bind_handler(ctrl_left)

        ctrl_right = Mousetrap::Handler.new('mod+right') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            elder = brother.first
            if elder
              if elder.children.empty?
                elder.child_dropped(id)
              else
                elder.children.last.brother_dropped(id)
              end
            end
          end
        end
        @hotkeys.bind_handler(ctrl_right)

        ctrl_del = Mousetrap::Handler.new('mod+del') do |h|
          h.condition { parental_tree.focused && self.target }
          h.procedure do
            Dialog::Confirm.new('葉の削除', "#{self.chapter_number} #{self.title} を削除してよろしいですか?", 'はい', 'いいえ') do |d|
              d.ok do
                destroy
                trigger(nil, :destroy, self.id)
              end
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
        children = self.children.dup
        children.insert(position, new_child)
        self.children = children

        new_child
      end

      # 並べ替え処理
      def brother_dropped(id)
        dropped = parental_tree.find(id)
        dropped.parent.children.delete_if{|c| c == dropped }
        position = @parent.children.index(self)
        @parent.children.insert(position + 1, dropped)

        dom_element.after(dropped.dom_element)

        dropped.dom_element.css('position', '')
        dropped.dom_element.css('left', '')
        dropped.dom_element.css('top', '')

        parental_tree.rearrange_notify(dropped.id, dropped.parent.id, self.parent.id, position + 1)
        dropped.parent.update_expand_collapse_buttons
        dropped.parent = @parent
      end

      def child_dropped(id)
        dropped = parental_tree.find(id)
        dropped.parent.children.delete_if{|c| c == dropped }
        children.insert(0, dropped)

        dom_element(:children).prepend(dropped.dom_element)

        dropped.dom_element.css('position', '')
        dropped.dom_element.css('left', '')
        dropped.dom_element.css('top', '')

        parental_tree.rearrange_notify(dropped.id, dropped.parent.id, self.id, 0)
        dropped.parent.update_expand_collapse_buttons
        update_expand_collapse_buttons
        dropped.parent = self
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
        parent.update_expand_collapse_buttons

        self
      end

      def parental_tree
        parents.last
      end

      def parents
        [parent, parent.parents].flatten
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
        offset_top + dom_element(:content).outer_height
      end

      def offset_left
        dom_element.offset.left
      end

      def offset_right
        title = dom_element(:title)
        offset_left + title.offset.left + title.width.to_i
      end

      def collapse
        dom_element(:expand).show
        dom_element(:collapse).hide
        dom_element(:children).hide
      end

      def expand
        dom_element(:expand).hide
        dom_element(:collapse).show
        dom_element(:children).show
      end

      def update_expand_collapse_buttons
        if children.empty?
          dom_element(:expand).hide
          dom_element(:collapse).hide
        else
          if open
            dom_element(:collapse).show
          else
            dom_element(:expand).show
          end
        end
      end

      def draggable_init
        %x{
          #{dom_element}.draggable({
            handle: #{".handle[data-id='#{id}']"},
            scroll: true,
            revert: "invalid"
          });

          #{dom_element.children('.brother-droppable')}.droppable({
            activeClass: 'active',
            drop: function(event, ui) { #{brother_dropped(`ui.draggable.attr('data-id')`)} },
            hoverClass: "hover",
            tolerance: 'pointer'
          });

          #{dom_element(:content)}.droppable({
            activeClass: 'active',
            drop: function(event, ui) { #{child_dropped(`ui.draggable.attr('data-id')`)} },
            hoverClass: "hover",
            tolerance: 'pointer'
          });
        }
      end
    end
  end
end
