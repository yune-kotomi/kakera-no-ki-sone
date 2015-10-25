require 'spec_helper'
require 'markdown'

describe 'Markdown::Parser' do
  let(:src) { '#hello, markdown!' }
  let(:option) { {} }
  let(:parser) do
    pa = Markdown::Parser.new(option)
    pa.parse(src)
    pa
  end
  let(:html) { parser.to_html.gsub("\t", '').gsub("\n", '') }
  let(:expected) { '<h1 id="hellomarkdown">hello, markdown!</h1>' }

  it { expect(html).to eq expected }
end
