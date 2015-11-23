require 'spec_helper'
require 'rickdom'
require 'jquery'
require 'opal-jquery'

describe 'RickDOM' do
  let(:src) { '<img src=# onerror=alert(1)><a href="http://example.jp/">example.jp</a><br><a href="javascript:alert(1)">javascript</a>' }
  let(:rickdom) { RickDOM.new }
  let(:result) { rickdom.build(src) }
  let(:expected) { '<img src="#"><a href="http://example.jp/">example.jp</a><br><a>javascript</a>' }

  it { expect(result).to eq expected }
end
