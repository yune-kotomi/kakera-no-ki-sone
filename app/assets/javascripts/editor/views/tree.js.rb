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
        <div class="dd-handle">Drag</div>
        <div class="dd-content">
          <span class="chapter_number">{{:chapter_number}}</span>
          <span class="title">{{:title}}</span>
        </div>
        <ol class="dd-list"></ol>
      </li>
      EOS

      attribute :id
      attribute :target, :default => false
      element :chapter_number, :selector => 'div.dd-content>span.chapter_number'
      element :title, :selector => 'div.dd-content>span.title'
      element :children, :selector => 'ol.dd-list:first', :type => Leaf

      def initialize(data = {}, parent = nil)
        super(data, parent)

        if self.children.nil? || self.children.empty?
          # 子がない場合に不要なものを削除
          dom_element(:children).remove
          dom_element.find('button').remove
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
        model.observe(:title) {|v| new_child.title = v }
        model.observe(:chapter_number) {|c| new_child.chapter_number = c }

        # 削除
        model.observe(nil, :destroy) { new_child.destroy }

        # Treeのcurrent orderを更新しておく
        parental_tree.update_order_silently

        new_child
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

      def fade
        dom_element(:chapter_number).effect(:fade_to, 'fast', 0.3)
        dom_element(:title).effect(:fade_to, 'fast', 0.3)
      end

      def unfade
        dom_element(:chapter_number).effect(:fade_to, 'fast', 1)
        dom_element(:title).effect(:fade_to, 'fast', 1)
      end
    end

    class Tree < Juso::View::Base
      template <<-EOS
      <div class="tree">
        <div class="root" data-id="{{attr:id}}">{{:title}}</div>
        <div class="dd">
          <ol class="dd-list"></ol>
        </div>
      </div>
      EOS

      attribute :id
      attribute :order
      element :title, :selector => 'div.root'
      element :children, :selector => 'div.dd>ol.dd-list', :type => Leaf
      element :nestable, :selector => 'div.dd'
      attribute :current_target
      attribute :target

      def initialize(data = {}, parent = nil)
        super(data, parent)
        init_nestable
        @rearrange_change_observers = []
        observe(:order) {|current, previous| rearranged(previous, current) }
        rearrange_observe {|t, f, to, pos| rearrange_leaves(t, f, to, pos) }

        # current_targetが変わった場合に前のやつを取り下げる
        observe(:current_target) do |c, prev_id|
          prev = find(prev_id)
          prev.target = false unless prev.nil?
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
        model.observe(:title) {|v| new_child.title = v }
        model.observe(:chapter_number) {|c| new_child.chapter_number = c }

        # 削除
        model.observe(nil, :destroy) { new_child.destroy }

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
        from = self.id if from == '' # ルートノード
        # 子の挿入先を探す
        added = diff.find{|d| d.added? }
        tmp = added.value.split("\n").first.split(":")
        tmp.pop
        to = tmp.last
        to = self.id if to == '' # ルートノード
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
        target.parent = to
      end
    end
  end
end
