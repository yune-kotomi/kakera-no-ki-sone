require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'jquery.nestable'
require 'opal-jquery'
require 'mousetrap_rb'
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

  describe '操作' do
    let(:parental_tree) { child1_1_1.parental_tree }
    it { expect(parental_tree).to eq tree }
  end

  describe '編集対象の指定' do
    let(:current) do
      ret = nil
      tree.observe(:current_target) {|v| ret = v }
      child1_1.dom_element(:title).trigger(:click)
      ret
    end
    it { expect(current).to eq child1_1.id }
    it { current; expect(child1_1.dom_element(:title).has_class?('selected')).to eq true }

    describe '前の編集対象からremove_class' do
      before do
        child1_1.dom_element(:title).trigger(:click)
        child1_3.dom_element(:title).trigger(:click)
      end
      it { expect(child1_1.dom_element(:title).has_class?('selected')).to eq false }
      it { expect(child1_3.dom_element(:title).has_class?('selected')).to eq true }
    end

    describe 'rootのクリック' do
      before { tree.dom_element(:title).trigger(:click) }
      it { expect(tree.current_target).to eq tree.id }
      it { expect(tree.target).to eq true }
      it { expect(tree.dom_element(:title).has_class?('selected')).to eq true }
    end

    describe '開閉操作' do
      describe '編集対象の親を閉じるとtargetが親に移る' do
        before do
          child1_1_1.target = true
          child1_1.open = false
        end
        it { expect(child1_1.target).to eq true }
        it { expect(child1_1_1.target).not_to eq true }
      end

      describe '他のノードを開閉してもtargetに変更はない' do
        before do
          child1_2.target = true
          child1_1.open = false
        end
        it { expect(child1_2.target).to eq true }
        it { expect(child1_1.target).not_to eq true }
      end
    end
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

    let(:parent) { tree.find(@to) }
    let(:target) { tree.find(@target) }

    describe '1-2を1-1の子に' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}, {"id"=>"1-2"}]}, {"id"=>"1-3"}]}] }

      it { expect(@target).to eq '1-2' }
      it { expect(@from).to eq 'c1' }
      it { expect(@to).to eq '1-1' }
      it { expect(@position).to eq 1 }
      it { expect(target.parent).to eq parent }

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
        expect(@to).to eq 'id'
        expect(@position).to eq 0
      end
      it { expect(target.parent).to eq parent }

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
        expect(@to).to eq 'id'
        expect(@position).to eq 1
      end
      it { expect(target.parent).to eq parent }

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
      it { expect(target.parent).to eq parent }

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
      it { expect(target.parent).to eq parent }

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
      it { expect(target.parent).to eq parent }
    end

    describe '1-3を1-2の子にする' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-2", "children" => [{"id"=>"1-3"}]}]}] }
      it { expect(@target).to eq '1-3' }
      it { expect(@from).to eq 'c1' }
      it { expect(@to).to eq '1-2' }
      it { expect(@position).to eq 0 }
      it { expect(target.parent).to eq parent }
      it { expect(parent.children.size).to eq 1 }
      it { expect(parent.children.first).to eq target }
    end
  end

  describe '子要素の追加' do
    describe 'Node modelで追加' do
      let(:model) { Editor::Model::Node.new(:id => '1-4', :title => 'child1-4', :body => 'body') }
      let(:child1_4) { tree.find('1-4') }
      let(:dom_elements) { child1.dom_element(:children).children }

      describe '2番目に挿入' do
        before { child1.add_child(1, model) }

        it { expect(child1.children.size).to eq 4 }
        it { expect(child1.children[0]).to eq child1_1 }
        it { expect(child1.children[1]).to eq child1_4 }
        it { expect(child1.children[2]).to eq child1_2 }
        it { expect(dom_elements.at(1)['data-id']).to eq '1-4' }
        it { expect(dom_elements.at(1).find('.dd-content').text.strip).to eq 'child1-4' }
        it { expect(tree.order).to eq [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-4"}, {"id"=>"1-2"}, {"id"=>"1-3"}]}] }

        describe 'ModelからViewへの変更伝搬' do
          before { model.title = 'child1-4 title' }
          it { expect(child1_4.title).to eq 'child1-4 title' }
        end
      end

      describe '先頭に挿入' do
        before { child1.add_child(0, model) }
        it { expect(child1.children[0]).to eq child1_4 }
        it { expect(child1.children[1]).to eq child1_1 }
        it { expect(dom_elements.at(0)['data-id']).to eq '1-4' }
        it { expect(dom_elements.at(1)['data-id']).to eq '1-1' }
        it { expect(tree.order).to eq [{"id"=>'c1', "children"=>[{"id"=>"1-4"}, {"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-2"}, {"id"=>"1-3"}]}] }
      end

      describe '空のtreeに追加' do
        let(:tree) { Editor::View::Tree.new(source.update(:children => [])) }
        before { tree.add_child(0, model) }
        let(:new_child) { tree.find(model.id) }

        it { expect(tree.children.size).to eq 1 }
        it { expect(new_child.id).to eq model.id }
      end
    end
  end

  describe '削除' do
    before { @ret = child1_1.destroy }
    it { expect(@ret).to eq child1_1 }
    it { expect(child1.children.size).to eq 2 }
    it { expect(child1.children.first).to eq child1_2 }
    it { expect(child1.dom_element(:children).find("li[data-id='#{child1_1.id}']")).to be_empty }
  end

  describe '前後ノード' do
    describe '兄' do
      it { expect(child1.brother.first).to eq nil }
      it { expect(child1_1.brother.first).to eq nil }
      it { expect(child1_2.brother.first).to eq child1_1 }
    end

    describe '弟' do
      it { expect(child1_1.brother.last).to eq child1_2 }
      it { expect(child1_3.brother.last).to eq nil }
    end

    describe '前' do
      describe '1-1が開いている場合、1-2の前は1-1-1' do
        it { expect(child1_2.visible_previous).to eq child1_1_1 }
      end

      describe '1-1が閉じている場合、1-2の前は1-1' do
        before { child1_1.open = false }
        it { expect(child1_2.visible_previous).to eq child1_1 }
      end

      describe '1-3の前は1-2' do
        it { expect(child1_3.visible_previous).to eq child1_2 }
      end

      describe '1-1の前はc1' do
        it { expect(child1_1.visible_previous).to eq child1 }
      end

      describe '1-1-1-1が存在する場合、1-2の前は1-1-1-1' do
        let(:child1_1_1_1) do
          model = Editor::Model::Node.new(
            "id"=>"1-1-1-1",
            "title"=>"1-1-1-1",
            "body"=>"body 1-1-1-1",
            "children"=>[],
            "metadatum" => {"tags" => []}
          )
          child1_1_1.add_child(0, model)
        end
        before { child1_1_1_1 }
        it { expect(child1_2.visible_previous).to eq child1_1_1_1 }
      end

      describe 'treeの前は存在しない' do
        it { expect(tree.visible_previous).to eq nil }
      end
    end

    describe '次' do
      describe '1-1が開いている場合、1-1の次は1-1-1' do
        it { expect(child1_1.visible_next).to eq child1_1_1 }
      end

      describe '1-1が閉じている場合、1-1の次は1-2' do
        before { child1_1.open = false }
        it { expect(child1_1.visible_next).to eq child1_2 }
      end

      describe '1-2の次は1-3' do
        it { expect(child1_2.visible_next).to eq child1_3 }
      end

      describe 'c2が存在する場合1-3の次はc2' do
        let(:child2) do
          model = Editor::Model::Node.new(
            "id"=>"c2",
            "title"=>"1-1-1-1",
            "body"=>"body 1-1-1-1",
            "children"=>[],
            "metadatum" => {"tags" => []}
          )
          tree.add_child(1, model)
        end
        before { child2 }
        it { expect(child1_3.visible_next.id).to eq child2.id }
      end

      describe '1-3の次は存在しない' do
        it { expect(child1_3.visible_next).to eq nil }
      end

      describe 'treeの次はc1' do
        it { expect(tree.visible_next).to eq child1 }
      end
    end
  end

  context 'ツリービューへのフォーカス' do
    let(:dom_element) { tree.dom_element.find('.tree') }

    describe 'フォーカスが当たっている' do
      before { tree.focused = true }
      it { expect(dom_element.has_class?('focused')).to eq true }
    end

    describe 'フォーカスが当たっていない' do
      before { tree.focused = false }
      it { expect(dom_element.has_class?('focused')).to eq false }
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
