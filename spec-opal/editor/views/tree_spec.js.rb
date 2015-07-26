require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'turbolinks'
require 'jquery.turbolinks'
require 'materialize-sprockets'
require 'jquery-ui'
require 'jquery.nestable'
require 'opal-jquery'
require 'juso/models/base'
require 'juso/views/base'
require 'editor/views/tree'

describe 'Editor::View::Tree' do
  let(:children) {
    [{"id"=>1,
      "title"=>"1",
      "body"=>"body 1",
      "children"=>
       [{"id"=>"1-1", "title"=>"1-1", "body"=>"body 1-1", "children"=>
         [{"id"=>"1-1-1", "title"=>"1-1-1", "body"=>"body 1-1-1", "children"=>[]}]},
        {"id"=>"1-2", "title"=>"1-2", "body"=>"body 1-2", "children"=>[]},
        {"id"=>"1-3", "title"=>"1-3", "body"=>"body 1-3", "children"=>[]}]}]

  }
  let(:source) {
    {
      :id => 'id',
      :title => 'title',
      :body => 'description',
      :children => children,
      :private => false,
      :archived => false,
      :markup => 'plaintext'
    }
  }
  let(:tree) { Editor::View::Tree.new(source) }

  it '初期orderのチェック' do
    expect(tree.order).to eq [{"id"=>1, "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-2"}, {"id"=>"1-3"}]}]
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
      let(:new_order) { [{"id"=>1, "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}, {"id"=>"1-2"}]}, {"id"=>"1-3"}]}] }

      it { expect(@target).to eq '1-2' }
      it { expect(@from).to eq 1 }
      it { expect(@to).to eq '1-1' }
      it { expect(@position).to eq 1 }
    end

    describe '1-1を1の前に' do
      let(:new_order) { [{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>1, "children"=>[{"id"=>"1-2"}, {"id"=>"1-3"}]}] }

      it do
        expect(@target).to eq '1-1'
        expect(@from).to eq 1
        expect(@to).to be_nil
        expect(@position).to eq 0
      end
    end

    describe '1-2を1の後ろに' do
      let(:new_order) { [{"id"=>1, "children"=>[{"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-3"}]}, {"id"=>"1-2"}] }

      it do
        expect(@target).to eq '1-2'
        expect(@from).to eq 1
        expect(@to).to be_nil
        expect(@position).to eq 1
      end
    end

    describe '1-3を1-1の前に' do
      let(:new_order) { [{"id"=>1, "children"=>[{"id"=>"1-3"}, {"id"=>"1-1", "children"=>[{"id"=>"1-1-1"}]}, {"id"=>"1-2"}]}] }

      it { expect(@target).to eq '1-3' }
      it { expect(@from).to eq 1 }
      it { expect(@to).to eq 1 }
      it { expect(@position).to eq 0 }
    end

    describe '1-1-1を1-1の後に' do
      let(:new_order) { [{"id"=>1, "children"=>[{"id"=>"1-1"}, {"id"=>"1-1-1"}, {"id"=>"1-2"}, {"id"=>"1-3"}]}] }

      it { expect(@target).to eq '1-1-1' }
      it { expect(@from).to eq '1-1' }
      it { expect(@to).to eq 1 }
      it { expect(@position).to eq 1 }
    end
  end
end
