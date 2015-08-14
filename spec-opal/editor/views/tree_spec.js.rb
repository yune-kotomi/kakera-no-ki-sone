require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'jquery.nestable'
require 'opal-jquery'
require 'diff'
require 'juso/models/base'
require 'juso/views/base'
require 'editor/models/node'
require 'editor/views/tree'
require 'editor/fixtures'

describe 'Editor::View::Tree' do
  document_source

  let(:tree) { Editor::View::Tree.new(source) }
  let(:child1) { tree.find('c1') }
  let(:child1_1) { tree.find('1-1') }
  let(:child1_1_1) { tree.find('1-1-1') }
  let(:child1_2) { tree.find('1-2') }
  let(:child1_3) { tree.find('1-3') }

  it '初期orderのチェック' do
    expect(tree.order).to eq [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-2"}, {"id"=>"1-3"}]}]
  end

  context '並べ替え処理' do
    before do
      tree.rearrange_observe do |target, from, to, position|
        @target = target
        @from = from
        @to = to
        @position = position
      end
      tree.order = new_order
    end

    describe '1-2を1-1の子に' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}, {"id"=>"1-2"}]}, {"id"=>"1-3"}]}] }

      it { expect(@target).to eq '1-2' }
      it { expect(@from).to eq 'c1' }
      it { expect(@to).to eq '1-1' }
      it { expect(@position).to eq 1 }

      context '子要素の構造' do
        it { expect(child1_1.children.last).to eq child1_2 }
        it { expect(child1.children.length).to eq 2 }
      end
    end

    describe '1-1を1の前に' do
      let(:new_order) { [{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>'c1', "children"=>[{"id"=>"1-2"}, {"id"=>"1-3"}]}] }

      it do
        expect(@target).to eq '1-1'
        expect(@from).to eq 'c1'
        expect(@to).to be_nil
        expect(@position).to eq 0
      end

      context '子要素' do
        it { expect(tree.children.first).to eq child1_1 }
        it { expect(tree.children.size).to eq 2 }
      end
    end

    describe '1-2を1の後ろに' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-3"}]}, {"id"=>"1-2"}] }

      it do
        expect(@target).to eq '1-2'
        expect(@from).to eq 'c1'
        expect(@to).to be_nil
        expect(@position).to eq 1
      end

      context '子要素' do
        it { expect(tree.children.last).to eq child1_2 }
        it { expect(tree.children.size).to eq 2 }
      end
    end

    describe '1-3を1-1の前に' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-3"}, {"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-2"}]}] }

      it { expect(@target).to eq '1-3' }
      it { expect(@from).to eq 'c1' }
      it { expect(@to).to eq 'c1' }
      it { expect(@position).to eq 0 }

      context '子要素' do
        it { expect(child1.children.first).to eq child1_3 }
        it { expect(child1.children.last).to eq child1_2 }
        it { expect(child1.children.size).to eq 3 }
      end
    end

    describe '1-1-1を1-1の後に' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1"}, {"id"=>"1-1-1"}, {"id"=>"1-2"}, {"id"=>"1-3"}]}] }

      it { expect(@target).to eq '1-1-1' }
      it { expect(@from).to eq '1-1' }
      it { expect(@to).to eq 'c1' }
      it { expect(@position).to eq 1 }

      context '子要素' do
        it { expect(child1.children[1]).to eq child1_1_1 }
        it { expect(child1.children.size).to eq 4 }
      end
    end

    describe '1-2-1を1-1の子にする' do
      let(:children) {
        [{"id"=>'c1',
          "title"=>"c1",
          "body"=>"body 1",
          "children"=>
           [{"id"=>"1-1", "title"=>"1-1", "body"=>"body 1-1", "children"=> []},
            {"id"=>"1-2", "title"=>"1-2", "body"=>"body 1-2", "children"=>[{"id"=>"1-2-1", "title"=>"1-2-1", "body"=>"body 1-2-1", "children"=>[]}]},
            {"id"=>"1-3", "title"=>"1-3", "body"=>"body 1-3", "children"=>[]}]}]

      }
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1", 'children' => [{"id"=>"1-2-1"}]}, {"id"=>"1-2"}, {"id"=>"1-3"}]}] }

      it { expect(@target).to eq '1-2-1' }
      it { expect(@from).to eq '1-2' }
      it { expect(@to).to eq '1-1' }
      it { expect(@position).to eq 0 }
    end
  end

  describe '子要素の追加' do
    describe 'Hashで追加' do
      before do
        child1.add_child(:id => '1-4', :title => 'child1-4')
      end
      let(:child1_4) { tree.find('1-4') }
      let(:dom_element) { child1.dom_element(:children).children('li:last-child') }

      it { expect(child1.children.size).to eq 4 }
      it { expect(child1.children.last).to eq child1_4 }
      it { expect(dom_element['data-id']).to eq '1-4' }
      it { expect(dom_element.find('.dd-content').text).to eq 'child1-4' }
    end

    describe 'Node modelで追加' do
      let(:model) { Editor::Model::Node.new(:id => '1-4', :title => 'child1-4', :body => 'body') }
      before do
        child1.add_child(model)
      end
      let(:child1_4) { tree.find('1-4') }
      let(:dom_element) { child1.dom_element(:children).children('li:last-child') }

      it { expect(child1.children.size).to eq 4 }
      it { expect(child1.children.last).to eq child1_4 }
      it { expect(dom_element['data-id']).to eq '1-4' }
      it { expect(dom_element.find('.dd-content').text).to eq 'child1-4' }
    end
  end
end

describe 'Editor::JsDiff' do
  let(:a) { "1\n1.1-1\n1.1-1.1-1-1\n1.1-2\n1.1-3\n" }
  let(:b) { "1\n1.1-2\n1.1-2.1-1\n1.1-2.1-1.1-1-1\n1.1-3\n" }
  let(:results) { Editor::JsDiff.diff(a, b) }
  it { expect(results.size).to eq 5 }

  describe '変更なしの行' do
    let(:result) { results[0] }
    it { expect(result.added?).to be false }
    it { expect(result.removed?).to be false }
    it { expect(result.value).to eq "1\n" }
  end

  describe '削除された行' do
    let(:result) { results[1] }
    it { expect(result.added?).to be false }
    it { expect(result.removed?).to be true }
    it { expect(result.value).to eq "1.1-1\n1.1-1.1-1-1\n" }
  end

  describe '追加された行' do
    let(:result) { results[3] }
    it { expect(result.added?).to be true }
    it { expect(result.removed?).to be false }
    it { expect(result.value).to eq "1.1-2.1-1\n1.1-2.1-1.1-1-1\n" }
  end
end
