require 'mousetrap'
require 'native'
require 'singleton'

module Mousetrap
  class Pool
    include Singleton

    def initialize
      @pool = {}
    end

    def get(key, selector = nil)
      binding = @pool[key]
      if binding.nil?
        binding = Binding.new(selector)
        @pool[key] = binding
      else
        binding.reset
      end

      binding
    end
  end

  class Handler
    attr_reader :keys

    def initialize(keys, options = {})
      @keys = keys
      @options = ({:prevented_check => true, :prevent_after_exec => true}).merge(options)

      yield(self)

      self
    end

    def condition(&block)
      @condition = block
    end

    def procedure(&block)
      @proc = block
    end

    def exec(event)
      enable = @condition.call
      enable = false if `#{event}.native.defaultPrevented` && @options[:prevented_check]

      if enable
        event.prevent if @proc.call(event) && @options[:prevent_after_exec]
      end
    end
  end

  class Binding
    def initialize(selector = nil)
      if selector
        @trap = `new Mousetrap(document.querySelector(#{selector}))`
      else
        @trap = `new Mousetrap()`
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

    def bind_handler(handler)
      bind(handler.keys) {|e| handler.exec(e) }
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

    def set_stop_callback(&block)
      %x{
        var wrapper = function(evt) {
          if (evt.preventDefault) {
            evt = #{Event.new `evt`};
          }
          return block.apply(null, arguments);
        };
        #{@trap}.stopCallback = wrapper;
      }
    end
  end
end
