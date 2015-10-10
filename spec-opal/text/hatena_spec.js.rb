require 'spec_helper'
require 'text/hatena'

describe 'Text::Hatena' do
  let(:src) { "*Hello\nworld" }
  let(:parser) do
    pa = Text::Hatena.new
    pa.parse(src)
    pa
  end
  let(:html) { parser.to_html.gsub("\t", '').gsub("\n", '') }
  let(:expected) do
    '<div class="section"><h3><a href="#p1" name="p1"><span class="sanchor">o-</span></a> Hello</h3><p>world</p></div>'
  end

  it { expect(html).to eq expected }
end
