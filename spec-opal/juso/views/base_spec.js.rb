require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'opal-jquery'
require 'juso/models/base'
require 'juso/views/base'

class JusoViewBaseTest2 < Juso::View::Base
  template '<li>{{:test1}}</li>'
  element :test1
end

class JusoViewBaseTest < Juso::View::Base
  template <<-EOS
  <div>
    <span class="test1">{{:test1}}</span>
    <input type="text" class="test2" value="{{attr:test2}}">
    <div class="test3" data-value="{{attr:test3}}"></div>
    <ul class="test4"></ul>
    <input type="checkbox">
  </div>
  EOS

  element :test1, :selector => 'span'
  element :test2, :selector => 'input.test2'
  element :test3, :selector => 'div.test3', :dom_attribute => 'data-value'
  element :test4, :selector => 'ul.test4', :type => JusoViewBaseTest2
  element :test5, :selector => 'input[type="checkbox"]', :default => false
end

describe 'Juso::View::Base' do
  let(:init_data) { {} }
  let(:test) { JusoViewBaseTest.new(init_data) }

  describe 'DOM要素取得' do
    it { expect(test.dom_element(:test1).tag_name).to eq 'span' }
  end

  describe '値の反映' do
    let(:data) { {:test1 => 'test1', :test2 => 'test2', :test3 => 'test3', :test4 => {:test1 => 'test4'}} }
    let(:init_data) { data }
    let(:test1_dom) { test.dom_element(:test1) }
    let(:test2_dom) { test.dom_element(:test2) }
    let(:test3_dom) { test.dom_element(:test3) }
    let(:test4_dom) { test.dom_element(:test4) }

    it { expect(test.test1).to eq data[:test1] }
    it { expect(test1_dom.text).to eq data[:test1] }
    it { expect(test2_dom.value).to eq data[:test2] }
    it { expect(test3_dom['data-value']).to eq data[:test3] }
    it { expect(test4_dom.find('li').text).to eq data[:test4][:test1] }

    describe 'setter' do
      let(:init_data) { {} }
      before do
        test.test1 = data[:test1]
        test.test2 = data[:test2]
        test.test3 = data[:test3]
        test.test4 = data[:test4]
      end

      it { expect(test.test1).to eq data[:test1] }
      it { expect(test1_dom.text).to eq data[:test1] }
      it { expect(test2_dom.value).to eq data[:test2] }
      it { expect(test3_dom['data-value']).to eq data[:test3] }
      it { expect(test4_dom.find('li').text).to eq data[:test4][:test1] }
    end

    describe '複数の子' do
      let(:init_data) { {:test4 => [{:test1 => 'test4-1'}, {:test1 => 'test4-2'}, {:test1 => 'test4-3'}]} }
      it { expect(test4_dom.find('li').count).to eq 3 }

      describe '更新' do
        before do
          @test4_1 = test.test4[0]
          @test4_2 = test.test4[1]

          new_test4 = test.test4.clone
          new_test4.insert(1, {:test1 => 'test4-2-new'})
          new_test4.pop
          test.test4 = new_test4
        end

        it { expect(test.test4.first).to eq @test4_1 }
        it { expect(test.test4.first.dom_element).to eq @test4_1.dom_element }
        it { expect(test.test4.last).to eq @test4_2 }
        it { expect(test.test4.last.dom_element).to eq @test4_2.dom_element }
        it { expect(test.test4.size).to eq 3 }
        it { expect(test.test4[1].test1).to eq 'test4-2-new' }
        it { expect(test.dom_element(:test4).find('li').map(&:text)).to eq ['test4-1', 'test4-2-new', 'test4-2'] }
      end
    end
  end

  describe '入力イベント' do
    describe 'text_field' do
      let(:values) do
        v = []
        test.observe(:test2) {|n, o| v = [n, o] }
        test.dom_element(:test2).value = 'input'
        test.dom_element(:test2).trigger(:input)
        v
      end

      it { expect(values).to eq ['input', nil] }
    end

    describe 'checkbox' do
      before { test.dom_element(:test5).trigger(:click) }
      it { expect(test.test5).to eq true }
    end
  end

  describe 'DOMイベント' do
    let(:triggered) do
      t = false
      test.observe(:test1, :click) { t = true }
      test.dom_element(:test1).trigger(:click)
      t
    end

    it { expect(triggered).to eq true }
  end
end
