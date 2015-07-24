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
      attribute :title
      element :children, :selector => 'ol.dd-list', :type => Leaf

      def initialize(data = {}, parent = nil)
        super(data, parent)

        if self.children.nil? || self.children.empty?
          # 子がない場合に不要なものを削除
          dom_element(:children).remove
          dom_element.find('button').remove
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
    end
  end
end
