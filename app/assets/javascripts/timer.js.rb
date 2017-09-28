module Timer
  class Timer
    def initialize(interval, &block)
      @interval = interval
      @proc = block
    end

    def start
      unless @timer
        @timer = `setInterval(function(){#{@proc.call}}, #{@interval * 1000})`
      end
    end

    def stop
      `clearInterval(#{@timer})`
      @timer = nil
    end

    def execute
      @proc.call
    end
  end
end
