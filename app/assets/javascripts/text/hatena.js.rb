require 'text-hatena'
require 'native'

module Text
  class Hatena
    def initialize(option = {})
      @option = option
    end

    def parse(text)
      `var parser = new TextHatena(#{@option.to_n})`
      @html = `parser.parse(#{text.to_s})`
    end

    def to_html
      @html
    end
  end
end
