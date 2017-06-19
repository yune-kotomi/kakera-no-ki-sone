require 'jsrender'

module Editor2
  class AbstractView
    attr_reader :id
    attr_reader :attributes
    attr_reader :attribute_instances
    attr_reader :dispatcher
    attr_reader :parent

    # 要素の定義
    def self.element(name, options = {})
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

    def initialize(attributes, parent = nil)
      @parent = parent

      # 初期値を投入
      @attributes = element_options.map do |k, v|
        if v.keys.include?(:default)
          case v[:default]
          when TrueClass, FalseClass, NilClass
            value = v[:default]
          else
            value = v[:default].dup
          end
        else
          value = nil
        end
        [k, value]
      end.to_h

      @attribute_instances = {}

      @observers = []

      template = self.class.ancestors.find{|klass| !klass.entire_template.nil? }.entire_template

      source = `$.templates(#{template}).render(#{@attributes.to_n})`
      @rendered = `$(source)`

      self.apply(attributes)

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

      # MDL固有処理
      # 入力系タグのイベント設定
      element_options.keys.each do |name|
        elem = dom_element(name)
        unless elem.nil?
          if elem.tag_name == 'input' && elem['type'] == 'checkbox'
            elem.on('click') do |e|
              emit_input(name, e.current_target.prop('checked'))
              true
            end
          elsif ['input', 'textarea'].include?(elem.tag_name)
            # 入力 -> 属性
            elem.on('input') do |e|
              emit_input(name, e.current_target.value)
              true
            end
          end
        end
      end
    end

    # 値を投入する口
    def apply(attributes)
      @id = attributes[:id]

      attributes.each do |k, v|
        options = element_options(k)
        if options
          elem = dom_element(k)

          if options[:type].nil?
            unless @attributes[k] == v
              if options[:dom_attribute].nil?
                # 入力中に属性値反映を行うと正常に入力できない(特に日本語入力時)のでフォーカスをチェックする
                if ['input', 'textarea'].include?(elem.tag_name)
                  # 入力系DOM要素ならvalueに値を投入
                  elem.value = v unless elem.is( ":focus" )
                  if v
                    elem.parent.add_class('is-dirty')
                  else
                    elem.parent.remove_class('is-dirty')
                  end
                else
                  # 入力系でなければhtmlを更新
                  elem.html = v
                end
              else
                # 指定されたDOM attributeに値を投入
                elem[options[:dom_attribute]] = v
              end
            end
          else
            # 別のビュークラスに依頼する箇所
            if v.is_a?(Array)
              instances = v.map do |value|
                instance = (@attribute_instances[k] || []).find{|i| i.id == value[:id] }
                if instance.nil?
                  instance = options[:type].new(value, self)
                  instance.dispatcher = @dispatcher
                else
                  instance.apply(value)
                end
                instance
              end
              unless instances == @attribute_instances[k]
                instances.each{|i| elem.append(i.dom_element) }
                # 不要になったものを消去
                (@attribute_instances[k] - instances).each(&:destroy) unless @attribute_instances[k].nil?

                @attribute_instances[k] = instances
              end
            else
              if @attribute_instances[k].nil?
                i = options[:type].new(v, self)
                @attribute_instances[k] = i
                elem.append(i.dom_element)
              else
                @attribute_instances[k].apply(v)
              end
            end
          end

          @attributes[k] = v
        end
      end
    end

    # 入力を通知する
    def emit_input(name, value)
      @observers.each{|o| o.call(name, value) }
    end

    def observe(&block)
      @observers.push(block)
      block
    end

    def dispatcher=(d)
      @dispatcher = d
      @attribute_instances.values.flatten.each{|i| i.dispatcher = d }
    end

    def emit(*actions)
      @dispatcher.dispatch(*actions)
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

    def destroy
      dom_element.remove
    end

    def element_options(name = nil)
      if name.nil?
        self.class.element_definitions
      else
        self.class.element_definitions[name.to_sym]
      end
    end
  end
end
