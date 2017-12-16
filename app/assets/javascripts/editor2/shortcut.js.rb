module Editor2
  class Shortcut
    def initialize(editor)
      @editor = editor

      ::Shortcut.add('Enter') { enter_key } # 編集
      ::Shortcut.add('esc', 'disable_in_input' => false) { escape_key } # 編集終了
      ::Shortcut.add('Ctrl+Alt+n', 'disable_in_input' => false) { mod_alt_n_key } # 新規追加
      ::Shortcut.add('Ctrl+Delete') { mod_del_key } # 削除
      ::Shortcut.add('Tab', 'disable_in_input' => false) { tab_key} # カーソルを次へ
      ::Shortcut.add('Shift+Tab', 'disable_in_input' => false) { shift_tab_key } # カーソルを前へ

      ::Shortcut.add('Up') { up_key } # 上へ
      ::Shortcut.add('Down') { down_key } # 下へ
      ::Shortcut.add('Left') { left_key } # 葉を閉じる
      ::Shortcut.add('Right') { right_key } # 葉を開く

      ::Shortcut.add('Ctrl+Up') { mod_up_key } # 上の葉と入れ替え
      ::Shortcut.add('Ctrl+Down') { mod_down_key } # 下の葉と入れ替え
      ::Shortcut.add('Ctrl+Left') { mod_left_key } # 1段上げる
      ::Shortcut.add('Ctrl+Right') { mod_right_key } # 1段下げる
    end

    private
    # キーボード・ショートカット処理
    def enter_key
      @editor.contents.find(@editor.store.selected).edit
    end

    def escape_key
      @editor.contents.find(@editor.store.selected).show
    end

    def mod_alt_n_key
      @editor.tree.find(@editor.store.selected).dom_element(:add_button).trigger('click')
    end

    def mod_del_key
      @editor.contents.find(@editor.store.selected).dom_element(:delete_button).trigger('click') unless @editor.store.selected == @editor.store.id
    end

    def tab_key
      # フォーカスがあるものを探す
      focused = Element.find(':focus')
      if focused.has_class?('leaf') && focused.has_class?('edit')
        id = focused['data-id']

        if focused.has_class?('title')
          @editor.contents.find(id).dom_element(:body).focus
        else
          @editor.contents.find(id).tap do |c|
            if c.next
              c.show
              c.next.edit
            end
          end
        end
      end
    end

    def shift_tab_key
      focused = Element.find(':focus')
      if focused.has_class?('leaf') && focused.has_class?('edit')
        id = focused['data-id']

        if focused.has_class?('body')
          @editor.contents.find(id).dom_element(:title).focus
        else
          @editor.contents.find(id).tap do |c|
            if c.previous
              c.show
              c.previous.edit(:body)
            end
          end
        end
      end
    end

    def up_key
      current = @editor.tree.find(@editor.store.selected)
      unless current == @editor.tree
        prev =
          if current.elder_brother
            current.elder_brother.last_visible_child
          else
            current.parent
          end

        @editor.store.dispatch(Action.new(
          :operation => :select,
          :target => prev.id
        )) if prev
      end
    end

    def down_key
      current = @editor.tree.find(@editor.store.selected)
      n =
        if current.open?
          current.children.first
        else
          current.next_leaf_not_below
        end

      @editor.dispatcher.dispatch(Action.new(
        :operation => :select,
        :target => n.id
      )) if n
    end

    def left_key
      current = @editor.tree.find(@editor.store.selected)
      if current.open?
        button = current.dom_element(:collapse)
        button.trigger('click') if button
      else
        @editor.dispatcher.dispatch(Action.new(
          :operation => :select,
          :target => current.parent.id
        ))
      end
    end

    def right_key
      button = @editor.tree.find(@editor.store.selected).dom_element(:expand)
      button.trigger('click') if button
    end

    def mod_up_key
      target = @editor.store.document.find{|l| l.id == @editor.store.selected }

      unless target.parent.nil? || target.index == 0
        @editor.dispatcher.dispatch(Action.new(
          :operation => :move,
          :target => target.id,
          :position => target.index - 1,
          :destination => target.parent.id
        ))
      end
    end

    def mod_down_key
      target = @editor.store.document.find{|l| l.id == @editor.store.selected }

      unless target.parent.nil? || target.index == target.parent.children.size - 1
        @editor.dispatcher.dispatch(Action.new(
          :operation => :move,
          :target => target.id,
          :position => target.index + 1,
          :destination => target.parent.id
        ))
      end
    end

    def mod_left_key
      target = @editor.store.document.find{|l| l.id == @editor.store.selected }
      unless target.parent.nil? || target.parent.parent.nil?
        @editor.dispatcher.dispatch(Action.new(
          :operation => :move,
          :target => target.id,
          :position => target.parent.index + 1,
          :destination => target.parent.parent.id
        ))
      end
    end

    def mod_right_key
      target = @editor.store.document.find{|l| l.id == @editor.store.selected }
      unless target.parent.nil? || target.index == 0
        previous = target.parent.children[target.index - 1]

        @editor.dispatcher.dispatch(
          Action.new(
            :operation => :change,
            :target => previous.id,
            :payload => {:metadatum => {:open => true}}
          ),
          Action.new(
            :operation => :move,
            :target => target.id,
            :position => previous.children.size,
            :destination => previous.id
          )
        )
      end
    end
  end
end
