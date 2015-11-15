require 'mousetrap'
require 'native'

module Mousetrap
  class Binding
    def initialize(selector = nil)
      if selector
        @trap = `Mousetrap(document.querySelector(#{selector}))`
      else
        @trap = `Mousetrap`
      end
    end

    def bind(keys, &block)
      %x{
        var wrapper = function(evt) {
          if (evt.preventDefault) {
            evt = #{Event.new `evt`};
          }
          return block.apply(null, arguments);
        };
        #{@trap}.bind(#{keys}, wrapper);
      }
    end

    def unbind(keys)
      `#{@trap}.unbind(#{keys})`
    end

    def trigger(keys)
      `#{@trap}.trigger(#{keys})`
    end

    def reset
      `#{@trap}.reset()`
    end

    def set_stop_callback
      %x{
        var wrapper = function(evt) {
          if (evt.preventDefault) {
            evt = #{Event.new `evt`};
          }
          return block.apply(null, arguments);
        };
        #{@trap}.stopCallback = function(e, element, combo) {
          #{yield(e, element, combo)};
        }
      }
    end
  end
end
