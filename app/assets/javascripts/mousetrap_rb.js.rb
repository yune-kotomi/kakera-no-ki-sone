require 'mousetrap'
require 'native'

module Mousetrap
  module_function
  def bind(keys, &block)
    %x{
      var wrapper = function(evt) {
        if (evt.preventDefault) {
          evt = #{Event.new `evt`};
        }
        return block.apply(null, arguments);
      };
      Mousetrap.bind(#{keys}, wrapper);
    }
  end

  def unbind(keys)
    `Mousetrap.unbind(#{keys})`
  end

  def trigger(keys)
    `Mousetrap.trigger(#{keys})`
  end

  def reset
    `Mousetrap.reset()`
  end

  def set_stop_callback
    %x{
      var wrapper = function(evt) {
        if (evt.preventDefault) {
          evt = #{Event.new `evt`};
        }
        return block.apply(null, arguments);
      };
      Mousetrap.stopCallback = function(e, element, combo) {
        #{yield(e, element, combo)};
      }
    }
  end
end
