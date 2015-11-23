# ツリー表示
# 葉の増減はNestableを再生成
#
require 'js_diff'
require 'editor/views/leaf'

module Editor
  module View
    class Tree < Juso::View::Base
      template <<-EOS
        <div class="scroll-container">
          <div class="tree">
            <div class="root" data-id="{{attr:id}}">{{:title}}</div>
            <div class="dd">
              <ol class="dd-list"></ol>
            </div>
          </div>
        </div>
      EOS

      element :children, :selector => 'div.dd>ol.dd-list', :type => Leaf
      element :container
      element :nestable, :selector => 'div.dd'
      element :title, :selector => 'div.root'

      attribute :current_target
      attribute :id
      attribute :order
      attribute :target
      attribute :focused, :default => false

      attr_reader :scroll_direction

      def initialize(data = {}, parent = nil)
        super(data, parent)
        init_nestable

        # 開閉状態を反映
        children.each do |leaf|
          leaf.scan do |l|
            unless l.open
              l.dom_element(:collapse).hide if l.dom_element(:collapse)
              l.dom_element(:expand).show if l.dom_element(:expand)
            end
          end
        end

        @rearrange_change_observers = []
        observe(:order) {|current, previous| rearranged(previous, current) }
        rearrange_observe {|t, f, to, pos| rearrange_leaves(t, f, to, pos) }

        # current_targetが変わった場合に前のやつを取り下げる
        observe(:current_target) do |c, prev_id|
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
        observe(:title, :click) do
          self.target = true
        end.call

        # スクロール方向判定
        observe(:container, :scroll) do
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

        # キーボード・ショートカット
        @hotkeys = Mousetrap::Pool.instance.get("tree-#{id}")
        down = Mousetrap::Handler.new('down') do |h|
          h.condition { focused && target }
          h.procedure do
            target = visible_next
            unless target.nil?
              target.target = true
              scroll_to(target.id)
            end
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
        children.insert(position, new_child)
        if position == 0
          dom_element(:children).prepend(new_child.dom_element)
        else
          dom_element(:children).children.at(position - 1).after(new_child.dom_element)
        end

        # 変更内容伝搬用
        new_child.attach(model)

        # current orderを更新しておく
        update_order_silently

        new_child
      end

      # 並び替えイベントのオブザーバ登録
      # ブロック引数は
      # - 移動するノードID string
      # - 移動元親ID string
      # - 移動先親ID string
      # - 挿入位置 number
      def rearrange_observe(&block)
        @rearrange_change_observers.push(block)
        block
      end

      # ノードの追加/削除時にchangeイベントを発生させずに保持しているオーダーを更新する
      def update_order_silently
        update_attribute(:order, serialize_nestable, {:trigger => false})
      end

      # 可視ノードのIDを返す
      def visible_contents
        # 表示領域
        visible_min = dom_element(:container).offset.top
        visible_max = visible_min + dom_element(:container).height

        flatten_leaf(self).select {|c| (visible_min < c.offset_bottom && c.offset_bottom <= visible_max) || (visible_min < c.offset_top && c.offset_top <= visible_max) }.map(&:id)
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

      private
      def serialize_nestable
        JSON.parse(`JSON.stringify(#{dom_element(:nestable)}.nestable('serialize'))`)
      end

      def init_nestable
        params = {:scroll => true, :maxDepth => 100}

        # Nestable初期化時に開閉ボタンが重複して生成されるのを防止
        dom_element(:nestable).find('button').remove

        %x{
          var target = #{dom_element(:nestable)};
          target.nestable(#{params.to_n});
          target.on('change', function(){#{rearrange}});
        }
        update_attribute(:order, serialize_nestable, {:trigger => false})

        # 開閉状態の反映
        children.each {|l| l.scan {|leaf| leaf.observe_open_close } }
      end

      def rearrange
        self.order = serialize_nestable
      end

      def rearranged(previous, current)
        # IDの一覧テキストを生成
        prev_text = generate_id_text({'id' => '', 'children' => previous}) + "\n"
        curr_text = generate_id_text({'id' => '', 'children' => current}) + "\n"

        diff = JsDiff.diff(prev_text, curr_text)

        # 子を引きぬかれた親を探す
        removed = diff.find{|d| d.removed? }
        tmp = removed.value.split("\n").first.split(":")
        target = tmp.pop
        from = tmp.last
        from = self.id if from == '' # ルートノード
        # 子の挿入先を探す
        added = diff.find{|d| d.added? }
        tmp = added.value.split("\n").first.split(":")
        tmp.pop
        to = tmp.last
        if to == ''
          to = self.id # ルートノード
        else
          find(to).observe_open_close
        end
        # 子の挿入位置検出
        children = curr_text.split("\n").
          select{|s| s.split(':').size == tmp.size + 1 }.
          select{|s| s.match(/^#{tmp.join(':')}:/) }
        position = children.index{|s| s == "#{tmp.join(':')}:#{target}" }

        @rearrange_change_observers.each do |o|
          o.call(target, from, to, position)
        end
      end

      def generate_id_text(src)
        id = src['id']
        result = [id]
        unless src['children'].nil? || src['children'].empty?
          ret = src['children'].map {|c| generate_id_text(c) }.join("\n")
          ret = ret.split("\n").map{|s| "#{id}:#{s}" }.join("\n")
          result.push(ret)
        end

        result.join("\n")
      end

      # 内部で保持しているLeafオブジェクト群を並び替える
      def rearrange_leaves(target_id, from_id, to_id, position)
        target = find(target_id)
        from = find(from_id)
        to = find(to_id)
        from.children.delete(target)
        to.children.insert(position, target)
        target.parent = to
      end

      def flatten_leaf(target)
        [target, target.children.map{|c| flatten_leaf(c) }].flatten
      end
    end
  end
end
