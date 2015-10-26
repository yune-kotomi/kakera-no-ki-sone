require 'rickdom-0.2'
require 'native'

class RickDOM
  def initialize(allowings = nil)
    @rickdom = `new RickDOM()`
    `#{@rickdom}.allowings = #{allowings.to_n}` unless allowings.nil?
  end

  def build(src)
    %x{
      var elements = #{@rickdom}.build(#{src});
      var container = document.createElement('div');
      for( i = 0; i < elements.length; i++ ){
        container.appendChild(elements[i]);
      }
    }
    `container.innerHTML`
  end
end
