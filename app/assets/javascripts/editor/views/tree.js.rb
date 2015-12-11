# ツリー表示
#
require 'editor/views/leaf'

module Editor
  module View
    class Tree < Juso::View::Base
      template <<-EOS
        <div class="scroll-container">
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

      attr_reader :scroll_direction
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

        # current_targetが変わった場合に前のやつを取り下げる
        observe(:current_target) do |c, prev_id|
          prev = find(prev_id)
          prev.target = false unless prev.nil?
          find(c).target = true
          scroll_to(c) unless visible_contents.include?(c)
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
          self.target = true
        end.call

        # スクロール方向判定
        observe(:container, :event => :scroll) do
          c = dom_element(:container)
          if @prev_scroll_top.to_i < c.scroll_top
            @scroll_direction = :down
          else
            @scroll_direction = :up
          end
          @prev_scroll_top = c.scroll_top
        end

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

      def scroll_to(id)
        target = find(id)
        offset = target.offset_top +
          dom_element(:container).scroll_top -
          dom_element(:container).offset.top
        dom_element(:container).scroll_top = offset
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
