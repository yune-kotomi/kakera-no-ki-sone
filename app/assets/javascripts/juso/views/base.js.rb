# Juso::View::Base
# class NewView < Juso::View::Base
#   template '<div><input type="text"><div class="display"></div></div>'
#   element :input, :selector => 'input[type="text"]'
#   element :display, :selector => '.display', :type => DisplayView
# end
#
# view = NewView.new(:input => 'default input')
# view.input
# => "default input"
# view.display = 'foo'
# => "foo" がdiv.displayに表示される
# view.observe(:input) {|nv, ov| puts "#{ov} -> #{nv}" }
# "input"と入力
# => "default input -> input"とコンソールに出力

require 'jsrender'

module Juso
  module View
    class Base < Juso::Model::Base
      # 要素の定義
      def self.element(name, options = {})
        attribute(name, options)
        element_definitions[name] = options

        self
      end

      def self.element_definitions
        @element_definitions ||= {}
      end

      def self.template(source)
        @entire_template = source
      end

      def self.entire_template
        @entire_template
      end

      def self.custom_events(*v)
        @custom_events = v
      end

      def self.custom_event_list
        @custom_events || []
      end

      def initialize(init_data = {}, parent = nil)
        @parent = parent

        # attributes投入
        super(init_data)

        # テンプレート評価
        template = self.class.ancestors.find{|klass| !klass.entire_template.nil? }.entire_template
        source = `$.templates(#{template}).render(#{attributes.to_n})`
        @rendered = `$(source)`

        # 子クラスのDOM展開
        element_options.
          reject{|_, o| o[:type].nil? }.
          each do |n, _|
            attr = @attributes[n]
            case attr
            when NilClass
              # do nothing
            when Array
              attr.each{|a| dom_element(n).append(a.dom_element) }
            else
              dom_element(n).append(attr.dom_element)
            end
          end

        element_options.keys.each do |name|
          elem = dom_element(name)
          unless elem.nil?
            if elem.tag_name == 'input' && elem['type'] == 'checkbox'
              elem.on('click') do |e|
                send("#{name}=", e.current_target.prop('checked'))
                true
              end
            else
              # 入力 -> 属性
              observe(name, :event => :input) {|e| send("#{name}=", e.current_target.value) }
            end
          end
        end

        # MDL固有処理
        # cf. http://www.getmdl.io/started/index.html
        # body以下にappendChild済みでないとupgradeElement出来ないので
        # 不可視divに突っ込んで実行する
        %x{
          if(typeof(componentHandler) != 'undefined' && componentHandler.upgradeElement){
            var tmp = $('#upgrade-element-tmp-container');
            if(tmp.size() == 0){
              tmp = $('<div id="upgrade-element-tmp-container">');
              tmp.css('display', 'none');
            }
            $('body').append(tmp);
            tmp.append(#{dom_element});

            #{dom_element}.find('[class^=mdl-]').each(function(_, e){
              componentHandler.upgradeElement(e);
            });
          }
        }

        self
      end

      def observe(name, params = {}, &block)
        params = ({:event => :change}).update(params)
        event = params[:event]
        elem = dom_element(name)

        if self.class.custom_event_list.include?(event)
          super(name, params) {|*args| block.call(*args) }
        else
          case event
          when :change
            super(name, params) {|*args| block.call(*args) }
          else
            if elem.nil?
              # 継承先でマークアップが変更された場合、dom_elementがnilを返す場合がある
              Proc.new{}
            else
              # 知らないイベントはDOMイベントとする
              # 親要素にイベントが伝搬しないようにする
              elem.on(event) {|*args| block.call(*args); false }
            end
          end
        end
      end

      def trigger(name, event, *args)
        super(name, event, *args)

        target = dom_element(name)
        target.trigger(event) unless target.nil?
      end

      def dom_element(name = nil)
        return nil if @rendered.nil?

        if name.nil?
          @rendered
        else
          options = element_options(name)
          if options.nil?
            nil
          else
            if options[:selector].nil?
              @rendered
            else
              @rendered.find(options[:selector]).first
            end
          end
        end
      end

      private
      def method_missing(method, *args)
        writer_matched = method.to_s.match(/^(.+?)=$/)
        if writer_matched
          attr_name = writer_matched[1].to_sym
          if !element_options(attr_name).nil?
            update_element(attr_name, args.first)
            self
          else
            super
          end

        else
          super
        end
      end

      def element_options(name = nil)
        element_definitions = {}
        self.class.ancestors.reverse.each do |klass|
          if klass.ancestors.include?(Juso::View::Base)
            element_definitions.update(
              Hash[
                klass.element_definitions.
                map{|name, options| [name, options] }
              ]
            )
          end
        end

        if name.nil?
          element_definitions
        else
          element_definitions[name]
        end
      end

      # 表示の更新
      def update_element(name, value)
        elem = dom_element(name)
        return if elem.nil?

        options = element_options(name)

        if !options[:type].nil?
          # 小クラスに更新を依頼
          if value.is_a?(Array)
            value.each{|v| raise Juso::Model::AttributeMustBeAHashOrClassError.new unless [Hash, options[:type]].include?(v.class) }

            children = value.map do |v|
              if v.is_a?(Hash)
                options[:type].new(v, self)
              else
                v
              end
            end
            children.each{|c| elem.append(c.dom_element) }

            # 使われなくなったDOM要素を始末
            (self.send(name) - children).each{|c| c.dom_element.remove }

            update_attribute(name, children)
          else
            old_dom_elements = elem.children
            if value.nil?
              child = nil
            else
              if value.is_a?(options[:type])
                child = value
                child.parent = self
              else
                child = options[:type].new(value, self)
              end
              elem.append(child.dom_element)
            end
            old_dom_elements.remove if child.nil? || child != self.send(name)

            update_attribute(name, child)
          end

        elsif !options[:dom_attribute].nil?
          # 指定されたDOM attributeに値を投入
          elem[options[:dom_attribute]] = value
          update_attribute(name, value)

        else
          # 入力中に属性値反映を行うと正常に入力できない(特に日本語入力時)のでフォーカスをチェックする
          if ['input', 'textarea'].include?(elem.tag_name) && !elem.is( ":focus" )
            # 入力系DOM要素ならvalueに値を投入
            elem.value = value
          else
            # 入力系でなければhtmlを更新
            elem.html = value
          end
          update_attribute(name, value)
        end
      end
    end
  end
end
