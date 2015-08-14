# ツリー表示
# 葉の増減はNestableを再生成
#
module Editor
  module JsDiff
    class Diff
      attr_accessor :count
      attr_accessor :value

      def added?
        @added == true
      end

      def removed?
        @removed == true
      end

      def initialize(values)
        @count = values['count']
        @value = values['value']
        @added = true if values['added']
        @removed = true if values['removed']
      end
    end

    def self.diff(a, b)
      result = JSON.parse(`JSON.stringify(JsDiff.diffLines(#{a}, #{b}))`)
      result.map {|v| Diff.new(v) }
    end
  end

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
      element :children, :selector => 'ol.dd-list:first', :type => Leaf

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

      def add_child(model)
        if model.is_a?(Hash)
          model_attributes = model
        else
          model_attributes = model.attributes
        end

        new_child = Leaf.new(model_attributes)
        children.push(new_child)
        dom_element(:children).append(new_child.dom_element)

        new_child
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
        # IDの一覧テキストを生成
        prev_text = generate_id_text({'id' => '', 'children' => previous}) + "\n"
        curr_text = generate_id_text({'id' => '', 'children' => current}) + "\n"

        diff = JsDiff.diff(prev_text, curr_text)

        # 子を引きぬかれた親を探す
        removed = diff.find{|d| d.removed? }
        tmp = removed.value.split("\n").first.split(":")
        target = tmp.pop
        from = tmp.last
        from = nil if from == ''
        # 子の挿入先を探す
        added = diff.find{|d| d.added? }
        tmp = added.value.split("\n").first.split(":")
        tmp.pop
        to = tmp.last
        to = nil if to == ''
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
        unless src['children'].nil?
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
      end
    end
  end
end
