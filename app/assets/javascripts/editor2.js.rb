module Editor2
  class Editor
    attr_reader :tree
    attr_reader :contents
    attr_reader :store
    attr_reader :dispatcher

    def initialize(demo = false)
      @dispatcher = Dispatcher.new
      @dispatcher.stores.push(ViewSwitcher.new(self)) if self.class.phone?
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

      @store.subscribers.push(self) unless demo

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
      @shortcut = Shortcut.new(self)

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
        @tree.select_leaf(@store.selected)
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

    # モバイル環境でのtree/contents切り替えを司るクラス
    class ViewSwitcher
      def initialize(editor)
        @editor = editor
      end

      def dispatch(*actions)
        last_action = actions.
          select{|a| a.operation == :select }.
          last
        if last_action
          if @previous_target == last_action.target
            @editor.to_contents
          end
          @previous_target = last_action.target
        end
      end
    end
  end
end

Document.ready? do
  unless Element.find('#document-editor').empty?
    Element.find('footer').remove
    Element.find('.right-bottom-fab').css('bottom', '16px')

    editor = Editor2::Editor.new(Element.find('#document-demo-mode').value == 'true')
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
      end.call
    end

    main.ex_resize do
      height = main.height - 8*2 - 4*2
      editor.tree.dom_element(:container).css('height', "#{height}px")
      editor.contents.dom_element(:container).css('height', "#{height}px")
      editor.adjust_tree_size
    end.call
  end
end
