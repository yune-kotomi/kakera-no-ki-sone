module Editor2
  class Dispatcher
    attr_reader :stores

    def initialize
      @stores = []
    end

    def dispatch(*actions)
      @stores.each {|s| s.dispatch(*actions) }
    end
  end
end
