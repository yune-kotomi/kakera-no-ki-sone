module Document
  class Node
    attr_accessor :id
    attr_accessor :title
    attr_accessor :description
    attr_accessor :tags
    attr_accessor :children

    def initialize(src)
      @id = src['id']
      @title = src['title']
      @description = src['description']
      @tags = src['tags']

      @children = src['children'].map{|src| Node.new(src) }
    end
  end

  class Document < Node
    attr_accessor :private
    attr_accessor :markup

    def initialize(src)
      super(src)

      @private = src['private']
      @markup = src['markup']
    end
  end
end
