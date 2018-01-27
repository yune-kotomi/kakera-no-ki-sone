module Editor2
  module View
    class Leaf < AbstractView
      include CommonLeaf

      template <<-EOS
      <li class="leaf" data-id="{{attr:id}}">
        <div class="body">
          <div class="handle" data-id="{{attr:id}}"><i class="material-icons">drag_handle</i></div>

          <button class="mdl-button mdl-js-button mdl-button--icon expand">
            <i class="material-icons more">expand_more</i>
          </button>
          <button class="mdl-button mdl-js-button mdl-button--icon collapse">
            <i class="material-icons less">expand_less</i>
          </button>

          <div class="content">
            <span class="chapter_number">{{:chapter_number}}</span>
            <span class="title">{{:title}}</span>
          </div>
        </div>

        <div class="child-droptarget"></div>

        <ol class="children"></ol>
        <div class="buttons">
        <button class="mdl-button mdl-js-button mdl-button--icon add-button">
        <i class="material-icons">add</i>
        </button>
        </div>

        <div class="brother-droptarget"></div>
      </li>
      EOS

      element :chapter_number, :selector => 'span.chapter_number'
      element :title, :selector => 'span.title'
      element :content, :selector => 'div.content'
      element :children, :selector => 'ol.children', :type => Leaf
      element :collapse, :selector => 'button.collapse'
      element :expand, :selector => 'button.expand'
      element :add_button, :selector => '.add-button:last'

      def initialize(attr = {}, parent)
        super(attr, parent)

        dom_element(:collapse).on(:click) do |e|
          emit(Action.new(
            :operation => :change,
            :target => @id,
            :payload => {:metadatum => {:open => false}}
          ))
        end

        dom_element(:expand).on(:click) do |e|
          emit(Action.new(
            :operation => :change,
            :target => @id,
            :payload => {:metadatum => {:open => true}}
          ))
        end

        dom_element(:content).on(:click) do |e|
          emit(Action.new(
            :operation => :select,
            :target => @id
          ))
        end

        dom_element(:add_button).on(:click) do |e|
          new_id = UUID.generate

          emit(Action.new(
            :operation => :add,
            :target => parent.id,
            :position => index + 1,
            :payload => {:id => new_id}
          ),
          Action.new(
            :operation => :select,
            :target => new_id
          ))
        end

        # DnD関係初期化
        %x{
          #{dom_element}.draggable({
            handle: #{".handle[data-id='#{@id}']"},
            scroll: true,
            stop: function(event, ui) {
              var leaf = ui.helper;
              leaf.css('top', '');
              leaf.css('bottom', '');
              leaf.css('left', '');
              leaf.css('right', '');
              leaf.css('width', '');
              leaf.css('height', '');
            },
            revert: "invalid"
          });

          #{dom_element.children('.brother-droptarget')}.droppable({
            activeClass: 'active',
            drop: function(event, ui) { #{dropped(`ui.draggable.attr('data-id')`, :brother)} },
            hoverClass: "hover",
            tolerance: 'pointer'
          });

          #{dom_element.children('.child-droptarget')}.droppable({
            activeClass: 'active',
            drop: function(event, ui) { #{dropped(`ui.draggable.attr('data-id')`, :child)} },
            hoverClass: "hover",
            tolerance: 'pointer'
          });
        }
      end

      def apply(attr)
        attr = update_chapter_number(attr)
        super(attr)

        [dom_element, dom_element.find('.handle').first].each{|e| e['data-id'] = @id }

        # 開閉状態
        if attr[:metadatum][:open] == false
          dom_element(:children).hide
          dom_element(:collapse).hide
          dom_element(:expand).show
        else
          dom_element(:children).show
          dom_element(:collapse).show
          dom_element(:expand).hide
        end

        # 末端の場合は開閉ボタンを隠す
        if attr[:children] && attr[:children].empty?
          dom_element(:collapse).hide
          dom_element(:expand).hide
        end

        # 選択状態にある場合、treeが#selectを叩きに来るので一括で落としておくだけで良い
        dom_element.remove_class('selected')
      end

      # 並べ替え処理
      def dropped(id, as = :brother) # or :child
        actions =
          if as == :brother
            position = parent.attribute_instances[:children].reject{|c| c.id == id }.index(self) + 1

            [Action.new(
              :operation => :move,
              :target => id,
              :position => position,
              :destination => parent.id
            )]
          else
            [
              Action.new(
                :operation => :change,
                :target => @id,
                :payload => {:metadatum => {:open => true}}
              ),
              Action.new(
                :operation => :move,
                :target => id,
                :position => 0,
                :destination => id
              )
            ]
          end

        emit(*actions)

        # 位置情報をリセットする
        Element.find(".leaf[data-id='#{id}']").tap{|e| ['top', 'bottom', 'left', 'right', 'width', 'height'].each{|a| e.css(a, '') } }
      end

      def select
        dom_element.add_class('selected')
      end

      def visible?
        min = root.dom_element(:container).offset.top
        max = min + root.dom_element(:container).height.to_i
        d = dom_element(:title)

        min < d.offset.top && d.offset.top + d.outer_height < max
      end

      def open?
        dom_element(:children).css(:display) != 'none' && children.size > 0
      end

      def last_visible_child
        if open?
          children.last.last_visible_child
        else
          self
        end
      end
    end
  end
end
