module Editor2
  class Editor
    attr_reader :tree
    attr_reader :contents

    def initialize
      @dispatcher = Dispatcher.new
      @store = Store.new
      @dispatcher.stores.push(@store)

      @tree = View::Tree.new({}, self)
      @views = [@tree]
      @store.subscribers.push(@tree)
      Element.find('#document-editor>.tree-view').append(@tree.dom_element)
      tree.dispatcher = @dispatcher

      @contents = View::Contents.new({:children => []}, self)
      @views.push(@contents)
      @store.subscribers.push(@contents)
      Element.find('#document-editor>.content-view').append(@contents.dom_element)
      contents.dispatcher = @dispatcher

      @store.subscribers.push(self)

      # 設定ダイアログ
      Element.find('#config-dialog').tap do |d|
        d.find('input[name="markup"]').tap do |i|
          i.on(:click) do |e|
            markup = i.to_a.find{|t| t.prop('checked') }.value
            @dispatcher.dispatch(
              Action.new(
                :operation => :change,
                :payload => {:markup => markup}
              )
            )
            @contents.refresh!
          end
        end

        d.find('#public-checkbox').tap do |i|
          i.on(:click) do |e|
            if e.current_target.prop('checked')
              Dialog::Confirm.new('一般公開', 'この文書を公開してよろしいですか?', 'はい', 'いいえ') do |d|
                d.ok do
                  @dispatcher.dispatch(Action.new(
                    :operation => :change,
                    :payload => {:published => true}
                  ))
                end

                d.cancel do
                  i.prop('checked', false)
                  i.parent.remove_class('is-checked')
                end
              end.open
            else
              @dispatcher.dispatch(Action.new(
                :operation => :change,
                :payload => {:published => false}
              ))
            end

            true
          end
        end
      end

      # キーボード・ショートカット処理
      Shortcut.add('Enter') { enter_key } # 編集
      Shortcut.add('esc', 'disable_in_input' => false) { escape_key } # 編集終了
      Shortcut.add('Ctrl+Alt+n', 'disable_in_input' => false) { mod_alt_n_key } # 新規追加
      Shortcut.add('Ctrl+Delete') { mod_del_key } # 削除
      Shortcut.add('Tab', 'disable_in_input' => false) { tab_key} # カーソルを次へ
      Shortcut.add('Shift+Tab', 'disable_in_input' => false) { shift_tab_key } # カーソルを前へ

      Shortcut.add('Up') { up_key } # 上へ
      Shortcut.add('Down') { down_key } # 下へ
      Shortcut.add('Left') { left_key } # 葉を閉じる
      Shortcut.add('Right') { right_key } # 葉を開く

      Shortcut.add('Ctrl+Up') { mod_up_key } # 上の葉と入れ替え
      Shortcut.add('Ctrl+Down') { mod_down_key } # 下の葉と入れ替え
      Shortcut.add('Ctrl+Left') { mod_left_key } # 1段上げる
      Shortcut.add('Ctrl+Right') { mod_right_key } # 1段下げる

      # スモールスクリーン対応
      if ::Editor2::Editor.phone?
        %x{
          history.pushState('tree', null, '#tree');
          window.addEventListener('popstate', function (e) {
            #{pushstate(`history.state`)}
          })
        }
      end
    end

    def load_from_dom
      doc = {
        :id => Element.find('#document-id').value,
        :title => Element.find('#document-title').value,
        :body => Element.find('#document-description').value,
        :children => (JSON.parse(Element.find('#document-body').value) || []),
        :metadatum => {},
        :markup => JSON.parse(Element.find('#document-markup').value),
        :published => JSON.parse(Element.find('#document-public').value)
      }

      @store.load(doc)
    end

    def pushstate(state)
      case state
      when 'tree'
        to_tree

      when 'contents'
        @contents.find(@store.selected).show
      end
    end

    # ラージスクリーン用
    def adjust_tree_size
      return if ::Editor2::Editor.phone?

      tree = @tree.dom_element.parent
      contents = @contents.dom_element.parent

      column_width = `$(window).innerWidth()` / 12
      columns = (800.0 / column_width).ceil
      columns = 8 if columns > 8

      [tree, contents].each do |element|
        element['class'].
          split(' ').
          select{|c| c.match(/^mdl-cell--.+-col$/) }.
          each{|c| element.remove_class(c) }
      end

      tree.add_class("mdl-cell--#{12 - columns}-col")
      contents.add_class("mdl-cell--#{columns}-col")
    end

    def to_tree
      if self.class.phone?
        @contents.dom_element.hide
        @tree.dom_element.show
      end
    end

    def to_contents
      if self.class.phone? && @contents && @tree && @tree.dom_element.css(:display) != 'none'
        @contents.dom_element.show
        @tree.dom_element.hide
        %x{ history.pushState('contents', null, '#contents') }
      end
    end

    def apply(_)
      @save = true
      Element.find('#save-indicator').effect(:fade_in)
      Window.on(:beforeunload) { close_confirm }
    end

    def save_start
      @save = false
      Element.find('#save-indicator').hide
      Window.off(:beforeunload)
      `setInterval(function(){#{save_loop}}, 5000)`
    end

    # 保存ループの処理実体
    def save_loop
      save if @save
    end

    # PATCH /documents/ID.jsonを発行する
    def save
      indicator = Element.find('#save-indicator')

      data = @store.stored_document
      data = {
        :title => data[:title],
        :description => data[:body],
        :body => data[:children].to_json,
        :public => (data[:published] == true),
        :markup => data[:markup]
      }

      if data == @sent_data
        # 内容が更新されていなければ保存しない
        indicator.effect(:fade_out)
        Window.off(:beforeunload)
      else
        indicator.add_class('mdl-progress__indeterminate')

        HTTP.patch("/documents/#{@store.document.id}.json", :payload => {'document' => data}) do |request|
          if request.ok?
            @save = false
            @sent_data = data
            indicator.remove_class('mdl-progress__indeterminate')
            indicator.effect(:fade_out)
            Window.off(:beforeunload)
          else
          end
        end
      end
    end

    def close_confirm
      'まだ保存されていません。よろしいですか？'
    end

    def self.device
      phone_breakpoint = 480
      tablet_breakpoint = 840

      case `$(window).innerWidth()`
      when 0..phone_breakpoint
        :phone
      when phone_breakpoint..tablet_breakpoint
        :tablet
      else
        :desktop
      end
    end

    def self.phone?
      device == :phone
    end

    private
    # キーボード・ショートカット処理
    def enter_key
      @contents.find(@store.selected).edit
    end

    def escape_key
      @contents.find(@store.selected).show
    end

    def mod_alt_n_key
      @tree.find(@store.selected).dom_element(:add_button).trigger('click')
    end

    def mod_del_key
      @contents.find(@store.selected).dom_element(:delete_button).trigger('click') unless @store.selected == @store.id
    end

    def tab_key
      # フォーカスがあるものを探す
      focused = Element.find(':focus')
      if focused.has_class?('leaf') && focused.has_class?('edit')
        id = focused['data-id']

        if focused.has_class?('title')
          @contents.find(id).dom_element(:body).focus
        else
          @contents.find(id).tap do |c|
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
          @contents.find(id).dom_element(:title).focus
        else
          @contents.find(id).tap do |c|
            if c.previous
              c.show
              c.previous.edit(:body)
            end
          end
        end
      end
    end

    def up_key
      prev = @contents.find(@store.selected).previous
      @store.dispatch(Action.new(
        :operation => :select,
        :target => prev.id
      )) if prev
    end

    def down_key
      n = @contents.find(@store.selected).next
      @dispatcher.dispatch(Action.new(
        :operation => :select,
        :target => n.id
      )) if n
    end

    def left_key
      button = @tree.find(@store.selected).dom_element(:collapse)
      button.trigger('click') if button
    end

    def right_key
      button = @tree.find(@store.selected).dom_element(:expand)
      button.trigger('click') if button
    end

    def mod_up_key
      target = @store.document.find{|l| l.id == @store.selected }

      unless target.parent.nil? || target.index == 0
        @dispatcher.dispatch(Action.new(
          :operation => :move,
          :target => target.id,
          :position => target.index - 1,
          :destination => target.parent.id
        ))
      end
    end

    def mod_down_key
      target = @store.document.find{|l| l.id == @store.selected }

      unless target.parent.nil? || target.index == target.parent.children.size - 1
        @dispatcher.dispatch(Action.new(
          :operation => :move,
          :target => target.id,
          :position => target.index + 1,
          :destination => target.parent.id
        ))
      end
    end

    def mod_left_key
      target = @store.document.find{|l| l.id == @store.selected }
      unless target.parent.nil? || target.parent.parent.nil?
        @dispatcher.dispatch(Action.new(
          :operation => :move,
          :target => target.id,
          :position => target.parent.index + 1,
          :destination => target.parent.parent.id
        ))
      end
    end

    def mod_right_key
      target = @store.document.find{|l| l.id == @store.selected }
      unless target.parent.nil? || target.index == 0
        previous = target.parent.children[target.index - 1]

        @dispatcher.dispatch(Action.new(
          :operation => :move,
          :target => target.id,
          :position => previous.children.size,
          :destination => previous.id
        ))
      end
    end
  end
end

Document.ready? do
  unless Element.find('#document-editor').empty?
    Element.find('footer').remove
    Element.find('.right-bottom-fab').css('bottom', '16px')

    editor = Editor2::Editor.new
    editor.load_from_dom
    editor.to_tree
    editor.save_start

    main = Element.find('main')
    # モバイルではmainのheightはコンテンツ長となるが
    # PCと同様、画面高さに固定する
    if Editor2::Editor.phone?
      Element.find('body').ex_resize do
        main_height = `$(window).innerHeight()` - Element.find('header').outer_height
        main.css('height', "#{main_height}px")
      end
    end

    main.ex_resize do
      height = main.height - 8*2 - 4*2
      editor.tree.dom_element(:container).css('height', "#{height}px")
      editor.contents.dom_element(:container).css('height', "#{height}px")
      editor.adjust_tree_size
    end.call
  end
end
