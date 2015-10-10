require 'text-hatena'

module Text
  class Hatena
    def parse(text)
      @html = `(new TextHatena()).parse(#{text})`
    end

    def to_html
      @html
    end
  end
end
