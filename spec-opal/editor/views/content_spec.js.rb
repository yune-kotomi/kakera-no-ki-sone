require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'jquery.nestable'
require 'opal-jquery'
require 'juso/models/base'
require 'juso/views/base'
require 'editor/models/node'
require 'editor/views/content'
require 'editor/fixtures'

describe 'Editor::View::Contents' do
  document_source
  let(:contents) { Editor::View::Contents.new(source) }

  before { @order = contents.children.map(&:id) }
  it '初期orderのチェック' do
    expect(@order).to eq ['c1', '1-1', '1-1-1', '1-2', '1-3']
  end

  describe '並び替え' do
    before do
      contents.rearrange(new_order)
      @order = contents.children.map(&:id)
      @dom_order = contents.dom_element(:children).find('span.title').to_a.map(&:text)
    end
    let(:dom_expected) { expected.map{|s| s.to_s } }

    describe '1-2を1-1の子に' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}, {"id"=>"1-2"}]}, {"id"=>"1-3"}]}] }
      let(:expected) { ['c1', '1-1', '1-1-1', '1-2', '1-3'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-1を1の前に' do
      let(:new_order) { [{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>'c1', "children"=>[{"id"=>"1-2"}, {"id"=>"1-3"}]}] }
      let(:expected) { ['1-1', '1-1-1', 'c1', '1-2', '1-3'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-2を1の後ろに' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-3"}]}, {"id"=>"1-2"}] }
      let(:expected) { ['c1', '1-1', '1-1-1', '1-3', '1-2'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-3を1-1の前に' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-3"}, {"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-2"}]}] }
      let(:expected) { ['c1', '1-3', '1-1', '1-1-1', '1-2'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-1-1を1-1の後に' do
      let(:new_order) { [{"id"=>'c1', "children"=>[{"id"=>"1-1"}, {"id"=>"1-1-1"}, {"id"=>"1-2"}, {"id"=>"1-3"}]}] }
      let(:expected) { ['c1', '1-1', '1-1-1', '1-2', '1-3'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end
  end

  describe 'Contentの追加' do
    let(:data) { {
        :id => '1-4',
        :number => '1.4',
        :title => 'child1-4',
        :body => 'child1-4 body'
      } }

    describe 'Modelで追加' do
      let(:new_model) { Editor::Model::Node.new(data) }
      before { contents.add_child('1-3', new_model) }
      let(:content_1_3) { contents.find('1-3') }

      it { expect(content_1_3.dom_element.next).not_to be_nil }
      it { expect(content_1_3.dom_element.next['data-id']).to eq '1-4' }

      describe 'Viewからの変更伝搬' do
        let(:content_1_4) { contents.find('1-4') }
        before do
          content_1_4.title = 'child1-4 edit'
          content_1_4.body = 'child1-4 body edit'
        end
        it { expect(new_model.title).to eq 'child1-4 edit' }
        it { expect(new_model.body).to eq 'child1-4 body edit' }
      end

      describe '空の状態で追加' do
        let(:contents2) { Editor::View::Contents.new(source.update(:children => [])) }
        before { contents2.add_child(nil, new_model) }
        it { expect(contents2.children.size).to eq 1 }
      end
    end
  end

  describe '削除' do
    let(:content_1_1) { contents.find('1-1') }
    let(:content_1_1_1) { contents.find('1-1-1') }
    before { content_1_1.destroy }
    let(:dom_1_1) { contents.dom_element(:children).find("[data-id='#{content_1_1.id}']") }
    it { expect(dom_1_1).to be_empty }
  end

  context '本文領域へのフォーカス' do
    let(:dom_element) { contents.dom_element.find('.contents') }
    describe 'focused' do
      before { contents.focused = true }
      it { expect(dom_element.has_class?('focused')).to eq true }
    end

    describe 'unfocused' do
      before { contents.focused = false }
      it { expect(dom_element.has_class?('focused')).to eq false }
    end
  end

  context '編集対象' do
    let(:content_1_1) { contents.find('1-1') }
    let(:content_1_2) { contents.find('1-2') }
    before { content_1_1.target = true }
    it { expect(content_1_1.dom_element.has_class?('target')).to eq true }
    it { expect(content_1_2.target).to eq false }
    it { expect(contents.current_target).to eq content_1_1.id }

    describe '別のノードをターゲットにすると前のターゲットは解除' do
      before { content_1_2.target = true }
      it { expect(content_1_1.dom_element.has_class?('target')).to eq false }
      it { expect(content_1_2.dom_element.has_class?('target')).to eq true }
      it { expect(content_1_1.target).to eq false }
      it { expect(contents.current_target).to eq content_1_2.id }
    end
  end
end
