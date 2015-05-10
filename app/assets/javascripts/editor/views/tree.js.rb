# ツリー表示
# 葉の増減はNestableを再生成
#
module Editor
  module View
    class Leaf < Juso::View::Base
      template DATA.read
      attribute :id
      attribute :title
      element :leaves, :selector => 'ol.dd-list', :type => Leaf
    end

    class Tree < Juso::View::Base
      template <<EOS
<div class="tree">
  <span class="root" data-id="{{attr:id}}">{{:title}}</span>
  <div class="dd">
    <ol class="dd-list"></ol>
  </div>
</div>
EOS
      attribute :id
      element :title, :selector => 'span.root'
      element :leaves, :selector => 'div.dd>ol.dd-list', :type => Leaf
    end
  end
end

__END__
<li class="dd-item" data-id="{{attr:id}}">
  <div class="dd-handle">Drag</div><div class="dd-content">{{:title}}</div>
  <ol class="dd-list"></ol>
</li>
