require 'spec_helper'
require 'juso/models/base'

class JusoModelBaseTest2 < Juso::Model::Base
  attribute :attr1
end

class JusoModelBaseTest < Juso::Model::Base
  attribute :attr1
  attribute :attr2, :default => 'default1'
  attribute :attr3, :type => JusoModelBaseTest2
end

describe 'Juso::Model::Base' do
  let(:test) { JusoModelBaseTest.new }

  context '初期化' do
    let(:attributes) { {:attr1 => 'test value'} }
    let(:test) { JusoModelBaseTest.new(attributes) }
    it { expect(test.attr1).to eq attributes[:attr1] }
  end

  context 'setter' do
    let(:expected) { 'test value' }
    before { test.attr1 = expected }
    it { expect(test.attr1).to eq expected }
  end

  context 'デフォルト値' do
    it { expect(test.attr2).to eq 'default1' }
  end

  context '子クラス' do
    it { expect(test.attr3).to be_nil }

    describe 'Hashで初期値を与える' do
      let(:value) { {:attr1 => 'test value'} }
      let(:test) { JusoModelBaseTest.new(:attr3 => value) }
      it { expect(test.attr3).not_to be_nil }
      it { expect(test.attr3.is_a?(JusoModelBaseTest2)).to be true }
      it { expect(test.attr3.attr1).to eq value[:attr1] }
      it { expect(test.attr3.parent).to eq test }
    end

    describe '子クラスのインスタンスを与える' do
      let(:child) { JusoModelBaseTest2.new(:attr1 => 'test value') }
      let(:test) { JusoModelBaseTest.new(:attr3 => child) }
      it { expect(test.attr3).not_to be_nil }
      it { expect(test.attr3).to eq child }
      it { expect(test.attr3.parent).to eq test }
    end
  end

  context 'attributes' do
    it { expect(test.attributes).to eq ({
        :attr1 => nil,
        :attr2 => 'default1',
        :attr3 => nil
      }) }

    describe '子クラスのattributesを展開' do
      let(:test) { JusoModelBaseTest.new(:attr3 => {:attr1 => 'test value'}) }
      it { expect(test.attributes).to eq ({
          :attr1 => nil,
          :attr2 => 'default1',
          :attr3 => {:attr1 => 'test value'}
        }) }

      describe '指定キーのreject' do
        let(:attributes) { test.attributes(:reject => [:attr1]) }
        it { expect(attributes).to eq ({:attr2 => 'default1', :attr3 => {}})}
      end
    end

    describe '生成時の値' do
      let(:test) { JusoModelBaseTest.new(:attr1 => 'test value 1', :attr2 => 'test value 2') }
      it { expect(test.attributes).to eq ({
          :attr1 => 'test value 1',
          :attr2 => 'test value 2',
          :attr3 => nil
        }) }
    end
  end

  context 'update_attributes' do
    let(:expected) { {:attr1 => 'test value 1', :attr2 => 'test value 2'} }
    before { test.update_attributes(expected) }
    it { expect(test.attr1).to eq expected[:attr1] }
    it { expect(test.attr2).to eq expected[:attr2] }
    it { expect(test.attr3).to be_nil }
  end

  context 'observer' do
    before do
      test.attr1 = 'old'
      test.observe(:attr1) do |n, o|
        @new_value = n
        @old_value = o
      end
      test.attr1 = 'new'
    end

    it { expect(@new_value).to eq 'new' }
    it { expect(@old_value).to eq 'old' }
  end

  context '全属性observer' do
    before do
      test.attr1 = 'old'
      test.observe do |name, n, o|
        @name = name
        @new_value = n
        @old_value = o
      end
      test.attr1 = 'new'
    end

    it { expect(@name).to eq :attr1 }
    it { expect(@new_value).to eq 'new' }
    it { expect(@old_value).to eq 'old' }
  end
end
