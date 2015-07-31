require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'jquery.nestable'
require 'opal-jquery'
require 'juso/models/base'
require 'juso/views/base'
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
      @dom_order = contents.dom_element.find('span.title').to_a.map(&:text)
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
end
