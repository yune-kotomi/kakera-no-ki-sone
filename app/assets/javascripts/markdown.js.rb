require 'showdown'
require 'native'

module Markdown
  class Parser
    def initialize(option = {})
      @converter = `new showdown.Converter()`
    end

    def parse(text)
      @html = `#{@converter}.makeHtml(#{text.to_s})`
    end

    def to_html
      @html
    end
  end
end
