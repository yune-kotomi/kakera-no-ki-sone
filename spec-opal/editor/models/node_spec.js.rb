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
      it { expect(child1_2.parent).to eq child1_1 }
      it { expect(child1_2.chapter_number).to eq '1.1.2' }
      it { expect(child1_3.chapter_number).to eq '1.2' }
    end

    describe '1-1を1の前に' do
      before { root.rearrange('1-1', 'c1', 'id', 0) }
      it { expect(root.children.first).to eq child1_1 }
      it { expect(child1_1.parent).to eq root }
    end

    describe '1-2を1の後ろに' do
      before { root.rearrange('1-2', 'c1', 'id', 1) }
      it { expect(root.children.last).to eq child1_2 }
      it { expect(child1_2.parent).to eq root }
    end

    describe '1-3を1-1の前に' do
      before { root.rearrange('1-3', 'c1', 'c1', 0) }
      it { expect(child1.children.first).to eq child1_3 }
      it { expect(child1_3.parent).to eq child1 }
    end

    describe '1-1-1を1-1の後に' do
      before { root.rearrange('1-1-1', '1-1', 'c1', 1) }
      it { expect(child1.children[1]).to eq child1_1_1 }
      it { expect(child1_1_1.parent).to eq child1}
    end

    describe '1-3を1-2の子に' do
      before { root.rearrange('1-3', 'c1', '1-2', 0) }
      it { expect(child1_2.children.first).to eq child1_3 }
      it { expect(child1_2.children.size).to eq 1 }
      it { expect(child1_3.parent).to eq child1_2 }
      it { expect(child1_3.children).to be_empty }
    end
  end

  describe 'ノードの追加' do
    before do
      root.observe(:children) { @root_changed = true }
      child1.observe(:children) { @child1_changed = true }
      @new_child = child1.add_child(1)
    end
    it { expect(child1.children.size).to eq 4 }
    it { expect(child1.children[0]).to eq child1_1 }
    it { expect(child1.children[1]).to eq @new_child }
    it { expect(child1.children[2]).to eq child1_2 }
    it { expect(@new_child.id).not_to be_empty }
    it { expect(@root_changed).to be_nil }
    it { expect(@child1_changed).to eq true }
    it { expect(@new_child.chapter_number).to eq '1.2' }
    it { expect(child1_2.chapter_number).to eq '1.3' }

    describe '空の場合' do
      let(:empty_root) do
        root = Editor::Model::Root.new(source.update(:children => []))
        root.add_child(0)
        root
      end
      it { expect(empty_root.children.size).to eq 1 }
    end
  end

  describe 'last_child' do
    # content挿入用
    describe '1の最後の子は1-3' do
      it { expect(child1.last_child).to eq child1_3 }
    end

    describe '1-2の最後の子は自分自身' do
      it { expect(child1_2.last_child).to eq child1_2 }
    end
  end

  describe 'scan' do
    before do
      @ret = []
      child1.scan {|leaf| @ret.push(leaf.id) }
    end

    it { expect(@ret).to eq ['c1', '1-1', '1-1-1', '1-2', '1-3'] }
  end

  describe '削除' do
    describe '末端の葉' do
      before do
        child1_1_1.observe(nil, :destroy) { @triggered = true }
        child1_1.observe(:children) {|n, o| @children = [n, o] }
        @ret = child1_1_1.destroy
      end
      let(:new_children) { @children.first }
      let(:old_children) { @children.last }
      it { expect(child1_1.children).to be_empty }
      it { expect(@ret).to eq child1_1_1 }
      it { expect(@triggered).to eq true }
      it { expect(new_children).to be_empty }
      it { expect(old_children).to eq [child1_1_1] }
    end

    describe '枝の途中' do
      before { @ret = child1_1.destroy }
      it { expect(child1.children.size).to eq 2 }
      it { expect(@ret).to eq child1_1 }
    end
  end

  describe '章番号' do
    it { expect(child1.chapter_number).to eq '1' }
    it { expect(child1_1.chapter_number).to eq '1.1' }
    it { expect(child1_1_1.chapter_number).to eq '1.1.1' }
    it { expect(child1_2.chapter_number).to eq '1.2' }
  end

  describe '変更の伝搬' do
    before do
      root.observe(nil, :document_update) { @changed = true }
      child1_1_1.title = 'new'
    end
    it { expect(@changed).to eq true }
  end

  describe '全タグ' do
    it { expect(root.tags).to eq ['t1', 't11', 't111', 't12', 't13'] }
  end
end
