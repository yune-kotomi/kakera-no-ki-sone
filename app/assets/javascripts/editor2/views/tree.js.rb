require 'editor2/views/abstract_view'
require 'editor2/views/leaf'

module Editor2
  module View
    class Tree < AbstractView
      include CommonLeaf

      template <<-EOS
        <div class="scroll-container" tabindex="-1">
          <div class="tree mdl-shadow--4dp">
            <div class="root" data-id="{{attr:id}}"><span>{{:title}}</span></div>
            <div class="buttons">
              <button class="mdl-button mdl-js-button mdl-button--icon add-button">
                <i class="material-icons">add</i>
              </button>
            </div>
            <ol class="children"></ol>
          </div>
        </div>
      EOS

      element :children, :selector => 'ol.children', :type => Leaf
      element :container
      element :title, :selector => 'div.root>span'
      element :add_button, :selector => '.buttons .add-button'
      element :tree, :selector => '.tree'

      attr_reader :id
      attr_reader :component_id
      attr_reader :focused

      def initialize(attributes = {}, parent)
        @id = attributes.delete(:id)
        @component_id = UUID.generate

        super(attributes, parent)

        # イベントハンドラ
        dom_element(:title).on(:click) do |e|
          # 自分自身を編集対象にする
          action = Action.new(
            :operation => :select,
            :target => @id
          )
          emit(action)
        end

        dom_element(:add_button).on(:click) do |e|
          new_id = UUID.generate

          emit(Action.new(
            :operation => :add,
            :target => id,
            :position => 0,
            :payload => {:id => new_id}
          ),
          Action.new(
            :operation => :select,
            :target => new_id
          ))
        end

        # ドロップ処理
        %x{
          #{dom_element(:title)}.droppable({
            activeClass: 'active',
            drop: function(event, ui) { #{dropped(`ui.draggable.attr('data-id')`)} },
            hoverClass: "hover",
            tolerance: 'pointer'
          });
        }
      end

      def apply(attr)
        attr = update_chapter_number(attr)
        super

        # 選択操作
        select_leaf(attr[:selected])
      end

      def dropped(id)
        emit(Action.new(
          :operation => :move,
          :target => id,
          :position => 0,
          :destination => @id
        ))

        # 位置情報をリセットする
        Element.find(".leaf[data-id='#{id}']").tap{|e| ['top', 'bottom', 'left', 'right', 'width', 'height'].each{|a| e.css(a, '') } }
      end

      def select_leaf(target)
        selected = find(target)
        selected.select
        unselect unless selected == self

        unless selected.visible?
          # スクロール処理
          container = dom_element(:container)
          container.scroll_top = selected.dom_element(:title).offset.top +
            container.scroll_top - container.offset.top

          width = selected.dom_element(:title).offset.left +
            selected.dom_element(:title).outer_width -
            selected.dom_element(:title).offset.left
          if container.width.to_i > width
            container.scroll_left = selected.dom_element(:title).offset.left +
              container.scroll_left - container.offset.left -
              (container.width - width)/2
          else
            # 幅がありすぎるので左端をあわせる
            container.scroll_left = selected.dom_element(:title).offset.left +
              container.scroll_left - container.offset.left
          end
        end
      end

      def select
        dom_element(:tree).add_class('selected')
      end

      def unselect
        dom_element(:tree).remove_class('selected')
      end

      def visible?
        false
      end

      def open?
        true
      end

      def root
        self
      end
    end
  end
end
