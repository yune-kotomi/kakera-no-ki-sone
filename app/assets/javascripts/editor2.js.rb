module Editor2
  class Editor
    attr_reader :tree
    attr_reader :contents
    attr_reader :store
    attr_reader :dispatcher
    attr_accessor :writer

    def initialize(loader)
      @loader = loader
      @writer = DummyWriter.new(self)

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
      @shortcut = Shortcut.new(self)

      # スモールスクリーン対応
      if ::Editor2::Editor.phone?
        %x{
          history.pushState('tree', null, '#tree');
          window.addEventListener('popstate', function (e) {
            #{pushstate(`history.state`)}
          })
        }
        Element.find('#back-button').on('click') do
          `history.back()`
          false
        end

        @contents.dom_element.hide
      end

      # 画面サイズまわり
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
        height = main.height - 4
        self.tree.dom_element(:container).css('height', "#{height}px")
        self.contents.dom_element(:container).css('height', "#{height}px")
        self.adjust_tree_size
      end.call
    end

    def load
      @store.load(@loader.load)
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
      columns = 6 if columns < 6

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
        Element.find('#back-button').hide
      end
    end

    def to_contents
      if self.class.phone? && @contents && @tree && @tree.dom_element.css(:display) != 'none'
        @contents.dom_element.show
        @tree.dom_element.hide
        %x{ history.pushState('contents', null, '#contents') }
        Element.find('#back-button').show
      end
    end

    def indicate_save(mode)
      indicator = Element.find('#save-indicator')

      case mode
      when :on
        indicator.css('opacity', 1)
        Window.on(:beforeunload) { close_confirm }
      when :progress
        indicator.add_class('mdl-progress__indeterminate')
      when :off
        indicator.remove_class('mdl-progress__indeterminate')
        indicator.css('opacity', 0)
        Window.off(:beforeunload)
      end
    end

    def apply(_)
      @writer.write
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
