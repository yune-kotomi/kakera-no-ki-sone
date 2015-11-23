require 'diff'

module JsDiff
  class Diff
    attr_accessor :count
    attr_accessor :value

    def added?
      @added == true
    end

    def removed?
      @removed == true
    end

    def initialize(values)
      @count = values['count']
      @value = values['value']
      @added = true if values['added']
      @removed = true if values['removed']
    end
  end

  def self.diff(a, b)
    result = JSON.parse(`JSON.stringify(JsDiff.diffLines(#{a}, #{b}))`)
    result.map {|v| Diff.new(v) }
  end
end
