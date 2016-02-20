require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'opal-jquery'
require 'mousetrap_rb'
require 'juso/models/base'
require 'juso/views/base'
require 'editor'
require 'editor/models/node'
require 'editor/views/tree'
require 'editor/fixtures'

describe 'Editor::View::Tree' do
  document_source

  let(:tree) do
    r = Element.new('div')
    r.css('width', '600px')
    t = Editor::View::Tree.new(Editor::Model::Root.new(source))
    r.append(t.dom_element)
    t
  end
  let(:leaf1) { tree.find('c1') }
  let(:leaf1_1) { tree.find('1-1') }
  let(:leaf1_1_1) { tree.find('1-1-1') }
  let(:leaf1_2) { tree.find('1-2') }
  let(:leaf1_3) { tree.find('1-3') }

  describe 'トップレベル' do
    let(:parental_tree) { leaf1_1_1.parental_tree }
    it { expect(parental_tree).to eq tree }
  end

  describe '上位の葉一覧' do
    let(:parents) { leaf1_1_1.parents }
    it { expect(parents).to eq [leaf1_1, leaf1, tree] }
  end

  describe '編集対象の指定' do
    let(:current) do
      ret = nil
      tree.observe(:current_target) {|v| ret = v }
      leaf1_1.dom_element(:title).trigger(:click)
      ret
    end
    it { expect(current).to eq leaf1_1.id }
    it { current; expect(leaf1_1.dom_element(:content).has_class?('selected')).to eq true }

    describe '前の編集対象からremove_class' do
      before do
        leaf1_1.dom_element(:title).trigger(:click)
        leaf1_3.dom_element(:title).trigger(:click)
      end
      it { expect(leaf1_1.dom_element(:content).has_class?('selected')).to eq false }
      it { expect(leaf1_3.dom_element(:content).has_class?('selected')).to eq true }
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
          leaf1_1_1.target = true
          leaf1_1.open = false
        end
        it { expect(leaf1_1.target).to eq true }
        it { expect(leaf1_1_1.target).not_to eq true }
      end

      describe '他のノードを開閉してもtargetに変更はない' do
        before do
          leaf1_2.target = true
          leaf1_1.open = false
        end
        it { expect(leaf1_2.target).to eq true }
        it { expect(leaf1_1.target).not_to eq true }
      end

      describe '閉じたノードにフォーカスすると開く' do
        before do
          leaf1.open = false
          leaf1_1.open = false
          leaf1_1_1.target = true
        end

        it { expect(leaf1.open).to eq true }
        it { expect(leaf1_1.open).to eq true }
      end
    end
  end

  describe '前後ノード' do
    describe '兄' do
      it { expect(leaf1.brother.first).to eq nil }
      it { expect(leaf1_1.brother.first).to eq nil }
      it { expect(leaf1_2.brother.first).to eq leaf1_1 }
    end

    describe '弟' do
      it { expect(leaf1_1.brother.last).to eq leaf1_2 }
      it { expect(leaf1_3.brother.last).to eq nil }
    end

    describe '前' do
      describe '1-1が開いている場合、1-2の前は1-1-1' do
        it { expect(leaf1_2.visible_previous).to eq leaf1_1_1 }
      end

      describe '1-1が閉じている場合、1-2の前は1-1' do
        before { leaf1_1.open = false }
        it { expect(leaf1_2.visible_previous).to eq leaf1_1 }
      end

      describe '1-3の前は1-2' do
        it { expect(leaf1_3.visible_previous).to eq leaf1_2 }
      end

      describe '1-1の前はc1' do
        it { expect(leaf1_1.visible_previous).to eq leaf1 }
      end

      describe '1-1-1-1が存在する場合、1-2の前は1-1-1-1' do
        let(:leaf1_1_1_1) do
          model = Editor::Model::Node.new(
            "id"=>"1-1-1-1",
            "title"=>"1-1-1-1",
            "body"=>"body 1-1-1-1",
            "children"=>[],
            "metadatum" => {"tags" => []}
          )
          leaf1_1_1.add_child(0, model)
        end
        before { leaf1_1_1_1 }
        it { expect(leaf1_2.visible_previous).to eq leaf1_1_1_1 }
      end

      describe 'treeの前は存在しない' do
        it { expect(tree.visible_previous).to eq nil }
      end
    end

    describe '次' do
      describe '1-1が開いている場合、1-1の次は1-1-1' do
        it { expect(leaf1_1.visible_next).to eq leaf1_1_1 }
      end

      describe '1-1が閉じている場合、1-1の次は1-2' do
        before { leaf1_1.open = false }
        it { expect(leaf1_1.visible_next).to eq leaf1_2 }
      end

      describe '1-2の次は1-3' do
        it { expect(leaf1_2.visible_next).to eq leaf1_3 }
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
        it { expect(leaf1_3.visible_next.id).to eq child2.id }
      end

      describe '1-3の次は存在しない' do
        it { expect(leaf1_3.visible_next).to eq nil }
      end

      describe 'treeの次はc1' do
        it { expect(tree.visible_next).to eq leaf1 }
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
