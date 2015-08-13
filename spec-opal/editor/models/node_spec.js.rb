require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'jquery.nestable'
require 'uuid.core'
require 'uuid'
require 'opal-jquery'
require 'juso/models/base'
require 'editor/fixtures'
require 'editor/models/node'

describe 'Editor::Model::Node' do
  document_source
  let(:root) { Editor::Model::Root.new(source) }
  let(:child1) { root.find('c1') }
  let(:child1_1) { root.find('1-1') }
  let(:child1_2) { root.find('1-2') }
  let(:child1_1_1) { root.find('1-1-1') }
  let(:child1_3) { root.find('1-3') }

  context '並び替え' do
    describe '1-2を1-1の子に' do
      before { root.rearrange('1-2', 'c1', '1-1', 1) }
      it { expect(child1_1.children[1]).to eq child1_2 }
    end

    describe '1-1を1の前に' do
      before { root.rearrange('1-1', 'c1', nil, 0) }
      it { expect(root.children.first).to eq child1_1 }
    end

    describe '1-2を1の後ろに' do
      before { root.rearrange('1-2', 'c1', nil, 1) }
      it { expect(root.children.last).to eq child1_2 }
    end

    describe '1-3を1-1の前に' do
      before { root.rearrange('1-3', 'c1', 'c1', 0) }
      it { expect(child1.children.first).to eq child1_3 }
    end

    describe '1-1-1を1-1の後に' do
      before { root.rearrange('1-1-1', '1-1', 'c1', 1) }
      it { expect(child1.children[1]).to eq child1_1_1 }
    end
  end

  describe 'ノードの追加' do
    before do
      root.observe(:children) { @root_changed = true }
      child1.observe(:children) { @child1_changed = true }
      @new_child = child1.add_child
    end
    it { expect(child1.children.size).to eq 4 }
    it { expect(child1.children.last).to eq @new_child }
    it { expect(@new_child.id).not_to be_empty }
    it { expect(@root_changed).to be_nil }
    it { expect(@child1_changed).to eq true }
  end
end
