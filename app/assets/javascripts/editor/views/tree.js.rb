# ツリー表示
#
require 'editor/views/leaf'

module Editor
  module View
    class Tree < Juso::View::Base
      template <<-EOS
        <div class="scroll-container" tabindex="-1">
          <div class="tree">
            <div class="root" data-id="{{attr:id}}">{{:title}}</div>
            <ol class="children"></ol>
          </div>
        </div>
      EOS

      element :children, :selector => 'ol.children', :type => Leaf
      element :container
      element :title, :selector => 'div.root'

      attribute :current_target
      attribute :id
      attribute :target
      attribute :focused, :default => false

      attr_reader :model

      custom_events :rearrange

      def initialize(model, parent = nil)
        super(model.attributes, parent)
        @model = model

        # 開閉状態を反映
        children.each do |leaf|
          leaf.scan do |l|
            unless l.open
              l.dom_element(:collapse).hide if l.dom_element(:collapse)
              l.dom_element(:expand).show if l.dom_element(:expand)
            end
          end
        end

        observe(:current_target) do |c, prev_id|
          # current_targetが変わった場合に前のやつを取り下げる
          prev = find(prev_id)
          prev.target = false unless prev.nil?
          find(c).target = true
          scroll_to(c)
        end

        observe(:target) do |v|
          if v
            dom_element(:title).add_class('selected')
            self.current_target = self.id
          else
            dom_element(:title).remove_class('selected')
          end
        end
        # クリックで自分自身を選択状態に
        observe(:title, :event => :click) do
          if ::Editor.phone?
            # Editor#switch_to_contents
            parent.switch_to_contents
            %x{ history.pushState('contents', null, '#contents') }
          end
          self.target = true
        end
        self.target = true

        # ツリービューへのフォーカス
        observe(:focused) do |v|
          if v
            dom_element.find('.tree').add_class('focused')
          else
            dom_element.find('.tree').remove_class('focused')
          end
        end.call

        # ドロップ処理
        %x{
          #{dom_element(:title)}.droppable({
            activeClass: 'active',
            drop: function(event, ui) { #{child_dropped(`ui.draggable.attr('data-id')`)} },
            hoverClass: "hover",
            tolerance: 'pointer'
          });
        }

        # キーボード・ショートカット
        @hotkeys = Mousetrap::Pool.instance.get("tree-#{id}")
        down = Mousetrap::Handler.new('down') do |h|
          h.condition { focused && target }
          h.procedure do
            target = visible_next
            target.target = true unless target.nil?
          end
        end
        @hotkeys.bind_handler(down)
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

      # 可視ノードのIDを返す
      def visible_contents
        # 表示領域
        visible_min = dom_element(:container).offset.top
        visible_max = visible_min + dom_element(:container).height.to_i
        flatten_leaf(self).select {|c| visible_min < c.offset_top && c.offset_bottom < visible_max }.map(&:id)
      end

      def offset_top
        dom_element(:title).offset.top
      end

      def offset_bottom
        offset_top + dom_element(:title).outer_height
      end

      def offset_left
        dom_element(:title).offset.left
      end

      def offset_right
        offset_left + dom_element(:title).outer_width
      end

      def scroll_to(id)
        target = find(id)
        container = dom_element(:container)

        unless visible_contents.include?(id)
          container.scroll_top = target.offset_top +
            container.scroll_top - container.offset.top
        end

        width = target.offset_right - target.offset_left
        if container.width.to_i > width
          container.scroll_left = target.offset_left +
            container.scroll_left - container.offset.left -
            (container.width - width)/2
        else
          # 幅がありすぎるので左端をあわせる
          container.scroll_left = target.offset_left +
            container.scroll_left - container.offset.left
        end
      end

      def visible_previous
        nil
      end

      def visible_next(force_close = false)
        if force_close
          nil
        else
          children.first
        end
      end

      def brother
        []
      end

      def update_expand_collapse_buttons
        # dummy
      end

      def parents
        []
      end

      private
      def flatten_leaf(target)
        [target, target.children.map{|c| flatten_leaf(c) }].flatten
      end

      def rearrange_notify(target_id, from_id, to_id, position)
        order = flatten_leaf(self)
        order.shift
        trigger(nil, :rearrange, target_id, from_id, to_id, position, order.map(&:id))
      end

      def child_dropped(id)
        dropped = find(id)
        dropped.parent.children.delete_if{|c| c == dropped }
        children.insert(0, dropped)

        dom_element(:children).prepend(dropped.dom_element)

        dropped.dom_element.css('position', '')
        dropped.dom_element.css('left', '')
        dropped.dom_element.css('top', '')

        rearrange_notify(dropped.id, dropped.parent.id, self.id, 0)
        dropped.parent.update_expand_collapse_buttons
        dropped.parent = self
      end
    end
  end
end
