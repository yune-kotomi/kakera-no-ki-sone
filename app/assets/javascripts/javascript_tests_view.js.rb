module JavascriptTestsView
  def self.execute
    ModelTest.execute
    ViewTest.execute
    puts '全テスト通過'
  end

  module ModelTest
    class Test2 < Juso::Model::Base
      attribute :attr1
    end

    class Test < Juso::Model::Base
      attribute :attr1
      attribute :attr2, :default => 'default1'
      attribute :attr3, :type => Test2
    end

    def self.execute
      test_value = 'test value'

      # initialize
      test = Test.new(:attr1 => test_value)
      raise 'initializeで与えた値がちがう' unless test.attr1 == test_value

      # attribute
      setup
      @test.attr1 = test_value
      raise 'attributeの値が異常' unless @test.attr1 == test_value

      # attribute デフォルト値指定
      setup
      raise 'デフォルト値が異常' unless @test.attr2 == 'default1'

      # attribute 子クラス指定
      setup
      raise 'nilのはず' unless @test.attr3.nil?
      test = Test.new(:attr3 => {:attr1 => test_value})
      raise 'Test2のはず' unless test.attr3.is_a?(Test2)
      raise '値が異常' unless test.attr3.attr1 == test_value
      @test.attr3 = {:attr1 => test_value}
      raise 'Test2のはず' unless @test.attr3.is_a?(Test2)
      raise '値が異常' unless @test.attr3.attr1 == test_value

      # attributes
      setup
      raise "attributesが異常: #{@test.attributes.inspect}" unless @test.attributes == {
        :attr1 => nil,
        :attr2 => 'default1',
        :attr3 => nil
      }

      setup
      @test.attr3 = {:attr1 => test_value}
      raise "attributesが異常: #{@test.attributes.inspect}" unless @test.attributes == {
        :attr1 => nil,
        :attr2 => 'default1',
        :attr3 => {:attr1 => test_value}
      }

      # update_attributes
      setup
      @test.update_attributes(:attr1 => test_value, :attr2 => test_value)
      raise 'update_attributeが効いてない' if @test.attr1 != test_value || @test.attr2 != test_value

      # observe 属性指定
      setup
      triggered = 'no'
      @test.attr1 = 'old'
      @test.observe(:attr1) do |n, o|
        triggered = 'yes'
        raise 'observeの古い値がちがう' unless o == 'old'
        raise 'observeの新しい値がちがう' unless n == 'new'
      end
      @test.attr1 = 'new'
      raise 'observeが効いてない' unless triggered == 'yes'

      # observe 全属性指定
      setup
      triggered = 'no'
      @test.observe do
        triggered = 'yes'
      end
      @test.attr1 = 'new'
      raise 'observeが効いてない' unless triggered == 'yes'

      # trigger
      setup
      triggered = 'no'
      @test.observe(:attr1, :test) do
        triggered = 'yes'
      end
      @test.trigger(:attr1, :test)
      raise 'trigger失敗' unless triggered == 'yes'
    end

    def self.setup
      @test = Test.new
    end
  end

  module ViewTest
    class Test2 < Juso::View::Base
      template '<li>{{:test1}}</li>'
      element :test1
    end

    class Test < Juso::View::Base
      template DATA.read
      element :test1, :selector => 'span'
      element :test2, :selector => 'input.test2'
      element :test3, :selector => 'div.test3', :dom_attribute => 'data-value'
      element :test4, :selector => 'ul.test4', :type => Test2
    end

    def self.setup(data = {})
      @test = Test.new(data)
    end

    def self.execute
      # テンプレートの解釈
      setup
      raise 'DOM要素取得異常' unless @test.dom_element(:test1).tag_name == 'span'

      # 値の反映
      @test2 = Test2.new(:test1 => 'test')
      value = @test2.test1
      raise "値が異常: #{value}" unless value == 'test'
      @test2.test1 = 'test2'
      value = @test2.test1
      raise "値が異常: #{value}" unless value == 'test2'

      data = {:test1 => 'test1', :test2 => 'test2', :test3 => 'test3', :test4 => {:test1 => 'test4'}}
      setup(data)
      value = @test.dom_element(:test1).text
      raise "値が異常: #{value}" unless value == data[:test1]
      value = @test.dom_element(:test2).value
      raise "値が異常: #{value}" unless value == data[:test2]
      value = @test.dom_element(:test3)['data-value']
      raise "値が異常: #{value}" unless value == data[:test3]
      value = @test.dom_element(:test4).find('li').text
      raise "値が異常: #{value}" unless value == data[:test4][:test1]

      setup
      @test.test1 = data[:test1]
      value = @test.dom_element(:test1).text
      raise "値が異常: #{value}" unless value == data[:test1]
      @test.test2 = data[:test2]
      value = @test.dom_element(:test2).value
      raise "値が異常: #{value}" unless value == data[:test2]
      @test.test3 = data[:test3]
      value = @test.dom_element(:test3)['data-value']
      raise "値が異常: #{value}" unless value == data[:test3]
      @test.test4 = data[:test4]
      value = @test.dom_element(:test4).find('li').text
      raise "値が異常: #{value}" unless value == data[:test4][:test1]

      # 入力イベント
      setup
      value = nil
      @test.observe(:test2) do |val, old|
        value = val
      end
      @test.dom_element(:test2).value = 'input'
      @test.dom_element(:test2).trigger(:input)
      raise '入力値が反映されていない' unless @test.test2 == 'input'
      raise '入力イベントが発火していない' unless value == 'input'

      # DOMイベント
      setup
      triggered = false
      @test.observe(:test1, :click) do
        triggered = true
      end
      @test.dom_element(:test1).trigger(:click)
      raise 'clickイベントが発火していない' unless triggered
    end
  end
end

Document.ready? do
  JavascriptTestsView.execute if Element.find('body.javascript_test')
end

# view test用
__END__
<div>
  <span class="test1">{{:test1}}</span>
  <input type="text" class="test2" value="{{attr:test2}}">
  <div class="test3" data-value="{{attr:test3}}"></div>
  <ul class="test4"></ul>
</div>
