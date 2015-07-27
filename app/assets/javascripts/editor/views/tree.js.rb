# ツリー表示
# 葉の増減はNestableを再生成
#
module Editor
  module View
    class Leaf < Juso::View::Base
      template <<-EOS
      <li class="dd-item" data-id="{{attr:id}}">
        <button data-action="collapse" type="button">Collapse</button>
        <button data-action="expand" type="button" style="display: none;">Expand</button>
        <div class="dd-handle">Drag</div><div class="dd-content">{{:title}}</div>
        <ol class="dd-list"></ol>
      </li>
      EOS

      attribute :id
      element :title, :selector => 'div.dd-content'
      element :children, :selector => 'ol.dd-list', :type => Leaf

      def initialize(data = {}, parent = nil)
        super(data, parent)

        if self.children.nil? || self.children.empty?
          # 子がない場合に不要なものを削除
          dom_element(:children).remove
          dom_element.find('button').remove
        end
      end

      def find(target_id)
        if id == target_id
          self
        else
          children.map{|c| c.find(target_id) }.compact.first
        end
      end
    end

    class Tree < Juso::View::Base
      template <<-EOS
      <div class="tree">
        <span class="root" data-id="{{attr:id}}">{{:title}}</span>
        <div class="dd">
          <ol class="dd-list"></ol>
        </div>
      </div>
      EOS

      attribute :id
      attribute :order
      element :title, :selector => 'span.root'
      element :children, :selector => 'div.dd>ol.dd-list', :type => Leaf
      element :nestable, :selector => 'div.dd'

      def initialize(data = {}, parent = nil)
        super(data, parent)
        init_nestable
        @rearrange_change_observers = []
        observe(:order) {|current, previous| rearranged(previous, current) }
        rearrange_observe {|t, f, to, pos| rearrange_leaves(t, f, to, pos) }
      end

      def find(target_id)
        if target_id.nil?
          self
        else
          children.map{|c| c.find(target_id) }.compact.first
        end
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

      private
      def serialize_nestable
        JSON.parse(`JSON.stringify(#{dom_element(:nestable)}.nestable('serialize'))`)
      end

      def init_nestable
        params = {:scroll => true}

        # Nestable初期化時に開閉ボタンが重複して生成されるのを防止
        dom_element(:nestable).find('button').remove

        %x{
          var target = #{dom_element(:nestable)};
          target.nestable(#{params.to_n});
          target.on('change', function(){#{rearrange}});
        }
        update_attribute(:order, serialize_nestable, {:trigger => false})
      end

      def rearrange
        self.order = serialize_nestable
      end

      def rearranged(previous, current)
        target, from, _ = find_removed_node(nil, previous, current)
        _, to, position = find_removed_node(nil, current, previous)


        @rearrange_change_observers.each do |o|
          o.call(target, from, to, position)
        end
      end

      def find_removed_node(from, previous_source, current_source)
        previous = (previous_source||[]).map{|s| s['id'] }
        current = (current_source||[]).map{|s| s['id'] }

        if previous.size > current.size
          target = (previous - current).first
          position = previous.index(target)
          return [target, from, position]
        elsif (previous.size == current.size) && (previous != current)
          # 同一配列内で移動を行った場合
          prev_sub = []
          curr_sub = []
          previous.each_with_index do |id, i|
            if current[i] != id
              prev_sub.push(id)
              curr_sub.push(current[i])
            end
          end

          prev_sub.each do |id|
            if (prev_sub - [id]) == (curr_sub - [id])
              target = id
              position = previous.index(id)
              return [target, from, position]
            end
          end
        else
          # この階層じゃないので下に潜る
          previous_source.each do |previous_child|
            current_child = current_source.find{|c| c['id'] == previous_child['id'] }
            target, from, position = find_removed_node(previous_child['id'], previous_child['children'], current_child['children'])

            return [target, from, position] unless target.nil?
          end
        end
      end

      # 内部で保持しているLeafオブジェクト群を並び替える
      def rearrange_leaves(target_id, from_id, to_id, position)
        target = find(target_id)
        from = find(from_id)
        to = find(to_id)
        from.children.delete(target)
        to.children.insert(position, target)
      end
    end
  end
end
