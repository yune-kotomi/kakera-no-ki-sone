# Juso::Model::Base
# class NewModel < Juso::Model::Base
#   attribute :name, :default => 'name1', :type => Class
#   attribute :content
# end
#
# model = NewModel.new(:content => 'foo bar')
# model.name
# => "name1"
# model.content
# => "foo bar"
# model.observe(:name) {|n, o| p "old: #{o} new: #{n}" }
# model.name = 'name2'
# "old: name1 new: name2"

module Juso
  module Model
    class Base
      attr_accessor :parent

      # 属性の定義
      # default: デフォルト値
      def self.attribute(name, options = {})
        raise AttributeNameMustBeASymbolError.new unless name.class == Symbol
        attribute_definitions[name] = options
      end

      def self.attribute_definitions
        @attribute_definitions ||= {}
      end

      def initialize(init_data = {})
        @attribute_definitions = {}
        # 継承関係をたどる
        self.class.ancestors.reverse.each do |klass|
          if klass.ancestors.include?(Juso::Model::Base)
            @attribute_definitions.update(
              Hash[
                klass.attribute_definitions.
                  map{|name, options| [name, options] }
              ]
            )
          end
        end
        @attributes = @attribute_definitions.map do |k, v|
          value = v[:default]
          value = v[:default].dup unless v[:default].nil?
          [k, value]
        end.to_h
        @observers = {}
        @wide_observers = []

        update_attributes(init_data || {})

        self
      end

      def method_missing(method, *args)
        writer_matched = method.to_s.match(/^(.+?)=$/)
        if writer_matched
          attr_name = writer_matched[1]
          if @attributes.keys.include?(attr_name)
            update_attribute(attr_name.to_sym, args.first)
            self
          else
            super
          end

        elsif @attributes.keys.include?(method)
          @attributes[method]

        else
          super
        end
      end

      def attributes
        ret = @attributes.map do |k, v|
          case v
          when Array
            v = v.map do |v|
              v = v.attributes if v.respond_to?(:attributes)
              v
            end
          else
            v = v.attributes if v.respond_to?(:attributes)
          end
          [k, v]
        end
        Hash[ret]
      end

      def update_attributes(source)
        source.
          select{|k, v| @attributes.keys.include?(k) }.
          each{|k, v| update_attribute(k, v) }
      end

      def observe(name = nil, event = :change, &block)
        raise ObserverBlockMissingError.new if block.nil?

        observer = {:name => name, :event => event, :block => block}

        if name.nil?
          @wide_observers.push(observer)
        else
          @observers[name] = [] if @observers[name].nil?
          @observers[name].push(observer)
        end

        block
      end

      def trigger(name, event, *args)
        (@observers[name]||[]).select{|o| o[:event] == event }.each do |observer|
          observer[:block].call(*args)
        end

        @wide_observers.select{|o| o[:event] == event }.each do |observer|
          observer[:block].call(name, *args)
        end
      end

      private
      def update_attribute(name, value, options = {:trigger => true})
        attribute_definition = @attribute_definitions[name]
        previous_value = @attributes[name]

        if attribute_definition[:type].nil?
          unless previous_value == value
            @attributes[name] = value
            trigger(name, :change, value, previous_value) if options[:trigger]
          end
        else
          # 子クラスが指定されている
          if value.is_a?(Array)
            value.each{|v| raise AttributeMustBeAHashOrClassError.new unless [Hash, attribute_definition[:type]].include?(v.class) }

            if value.first.is_a?(Hash)
              previous_attributes = if previous_value.nil?
                nil
              else
                previous_value.map{|v| v.attributes }
              end

              unless previous_attributes == value
                values = value.map{|v| attribute_definition[:type].new(v, self) }
                values.each {|v| v.parent = self }
                @attributes[name] = values
                trigger(name, :change, values, previous_value) if options[:trigger]
              end
            else
              unless previous_value == value
                @attributes[name] = value
                value.each {|v| v.parent = self }
                trigger(name, :change, value, previous_value) if options[:trigger]
              end
            end
          else
            if previous_value.nil? || previous_value.attributes != value
              if value.is_a?(Hash)
                @attributes[name] = attribute_definition[:type].new(value, self)
              else
                @attributes[name] = value
              end
              @attributes[name].parent = self unless @attributes[name].nil?

              trigger(name, :change, value, previous_value) if options[:trigger]
            end
          end
        end

        self
      end
    end

    class AttributeNameMustBeASymbolError < StandardError; end
    class ObserverBlockMissingError < StandardError; end
    class AttributeMustBeAHashOrClassError < StandardError; end
  end
end

# class Hoge < Juso::Model::Base
#   attribute :hoge
#   attribute :hogehoge, :default => 'hoge'
# end
#
# a = Hoge.new
# p a.hoge
# p a.hogehoge
#
# a.observe(:hoge) {|v1, v2| puts "[hoge] #{v1} #{v2}" }
# a.observe {|n, v1, v2| puts "[all] #{n} #{v1} #{v2}" }
#
# a.hoge = 'aaaa'
# a.hoge = 'bbbb'
# a.hogehoge = 'test'
