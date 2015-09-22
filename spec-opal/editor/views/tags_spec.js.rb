require 'spec_helper'
require 'jquery'
require 'jquery_ujs'
require 'jquery-ui'
require 'opal-jquery'
require 'uuid.core'
require 'uuid'
require 'juso/models/base'
require 'juso/views/base'
require 'editor/views/tags'

describe 'Editor::View::Tags' do
  let(:src) { ['t1', 't11', 't111', 't12', 't13'] }
  let(:target) { Editor::View::Tags.new(:tags => src) }
  let(:labels) { target.dom_element(:tag_list).find('label').map(&:text).map(&:strip) }

  it { expect(labels).to eq src }

  describe '更新' do
    let(:src2) { ['t1', 't11', 't111', 't13', 't2'] }
    before { target.tags = src2 }
    it { expect(labels).to eq src2 }

    describe 'check' do
      let(:selected_tags) { ['t1', 't11', 't2'] }
      before do
        selected_tags.each do |t|
          checkbox = target.tag_list.find{|e| e.value == t }
          checkbox.checked = true
        end
      end

      it { expect(target.selected_tags).to eq selected_tags }

      describe 'uncheck' do
        let(:uncheck_tags) { ['t11', 't2'] }
        before do
          uncheck_tags.each do |t|
            checkbox = target.tag_list.find{|e| e.value == t }
            checkbox.checked = false
          end
        end

        it { expect(target.selected_tags).to eq (selected_tags - uncheck_tags) }
      end
    end
  end
end
