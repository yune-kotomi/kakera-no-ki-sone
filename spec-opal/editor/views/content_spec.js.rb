require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'opal-jquery'
require 'mousetrap_rb'
require 'juso/models/base'
require 'juso/views/base'
require 'editor/models/node'
require 'editor/views/content'
require 'editor/views/contents'
require 'editor/fixtures'

describe 'Editor::View::Contents' do
  document_source
  let(:contents) { Editor::View::Contents.new(source) }
  let(:content_1) { contents.find('c1') }
  let(:content_1_1) { contents.find('1-1') }
  let(:content_1_1_1) { contents.find('1-1-1') }
  let(:content_1_2) { contents.find('1-2') }
  let(:content_1_3) { contents.find('1-3') }

  describe '走査' do
    it { expect(contents.previous).to eq nil }
    it { expect(contents.next_content).to eq content_1 }
    it { expect(content_1.previous).to eq contents }
    it { expect(content_1_1.previous).to eq content_1 }
    it { expect(content_1_1_1.next_content).to eq content_1_2 }
    it { expect(content_1_2.previous).to eq content_1_1_1 }
    it { expect(content_1_2.next_content).to eq content_1_3 }
    it { expect(content_1_3.next_content).to eq nil }
  end

  before { @order = contents.children.map(&:id) }
  it '初期orderのチェック' do
    expect(@order).to eq ['c1', '1-1', '1-1-1', '1-2', '1-3']
  end

  describe '並び替え' do
    before do
      contents.rearrange(expected)
      @order = contents.children.map(&:id)
      @dom_order = contents.dom_element(:children).find('span.title').to_a.map(&:text)
    end
    let(:dom_expected) { expected.map{|s| s.to_s } }

    describe '1-2を1-1の子に' do
      let(:expected) { ['c1', '1-1', '1-1-1', '1-2', '1-3'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-1を1の前に' do
      let(:expected) { ['1-1', '1-1-1', 'c1', '1-2', '1-3'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-2を1の後ろに' do
      let(:expected) { ['c1', '1-1', '1-1-1', '1-3', '1-2'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-3を1-1の前に' do
      let(:expected) { ['c1', '1-3', '1-1', '1-1-1', '1-2'] }

      it { expect(@order).to eq expected }

      context 'DOM' do
        it { expect(@dom_order).to eq dom_expected }
      end
    end

    describe '1-1-1を1-1の後に' do
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
    before { content_1_1.destroy }
    let(:dom_1_1) { contents.dom_element(:children).find("[data-id='#{content_1_1.id}']") }
    it { expect(dom_1_1).to be_empty }
  end

  context '編集対象' do
    before do
      contents.focused = true
      content_1_1.target = true
    end

    it { expect(content_1_1.dom_element.has_class?('mdl-shadow--4dp')).to eq true }
    it { expect(content_1_2.target).to eq false }
    it { expect(contents.current_target).to eq content_1_1.id }

    describe '別のノードをターゲットにすると前のターゲットは解除' do
      before { content_1_2.target = true }
      it { expect(content_1_1.dom_element.has_class?('mdl-shadow--4dp')).to eq false }
      it { expect(content_1_2.dom_element.has_class?('mdl-shadow--4dp')).to eq true }
      it { expect(content_1_1.target).to eq false }
      it { expect(contents.current_target).to eq content_1_2.id }
    end
  end

  context '編集モードの排他制御' do
    describe '通常ノード' do
      describe '編集に入ると本文領域にフォーカスが当たる' do
        before { content_1_1.edit }
        it { expect(contents.focused).to eq true }

        describe '本文領域からフォーカスを外すと編集も終了' do
          before { contents.focused = false }
          it { expect(content_1_1.dom_element.find('.editor-container').css('display')).to eq 'none' }
          it { expect(content_1_1.dom_element(:display).css('display')).to eq 'block' }
        end

        describe '別のノードを編集開始したら前のノードは編集終了' do
          before { content_1_2.edit }
          it { expect(content_1_1.dom_element.find('.editor-container').css('display')).to eq 'none' }
          it { expect(content_1_1.dom_element(:display).css('display')).to eq 'block' }
          it { expect(content_1_2.dom_element.find('.editor-container').css('display')).to eq 'block' }
          it { expect(content_1_2.dom_element(:display).css('display')).to eq 'none' }
        end

        describe 'ルートノードを編集開始したら前のノードは編集終了' do
          before { contents.edit }
          it { expect(content_1_1.dom_element.find('.editor-container').css('display')).to eq 'none' }
          it { expect(content_1_1.dom_element(:display).css('display')).to eq 'block' }
        end
      end
    end

    describe 'ルートノード' do
      describe '編集に入ると本文領域にフォーカスが当たる' do
        before { contents.edit }
        it { expect(contents.focused).to eq true }

        describe '本文領域からフォーカスを外すと編集も終了' do
          before { contents.focused = false }
          it { expect(contents.dom_element(:editor).css('display')).to eq 'none' }
          it { expect(contents.display.dom_element.css('display')).to eq 'block' }
        end

        describe '別のノードを編集開始したら前のノードは編集終了' do
          before { content_1_2.edit }
          it { expect(contents.dom_element(:editor).css('display')).to eq 'none' }
          it { expect(contents.display.dom_element.css('display')).to eq 'block' }
        end
      end
    end
  end
end
