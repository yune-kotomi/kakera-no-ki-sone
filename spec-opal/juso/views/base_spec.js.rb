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
  </div>
  EOS

  element :test1, :selector => 'span'
  element :test2, :selector => 'input.test2'
  element :test3, :selector => 'div.test3', :dom_attribute => 'data-value'
  element :test4, :selector => 'ul.test4', :type => JusoViewBaseTest2
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
      let(:init_data) { {:test4 => [{:test1 => 'test4-1'}, {:test1 => 'test4-2'}]} }
      it { expect(test4_dom.find('li').count).to eq 2 }
    end
  end

  describe '入力イベント' do
    let(:values) do
      v = []
      test.observe(:test2) {|n, o| v = [n, o] }
      test.dom_element(:test2).value = 'input'
      test.dom_element(:test2).trigger(:input)
      v
    end

    it { expect(values).to eq ['input', nil] }
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
