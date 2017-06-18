# 文書構造
# {
#   :id => 文書ID,
#   :title => 文書タイトル,
#   :body => 文書本文,
#   :children => [
#     {
#       :id => ノードID,
#       :title => タイトル,
#       :body => 本文,
#       :metadatum => {
#         :expanded => true/false, # 開閉状態
#         :target => true/false, # 編集対象かどうか
#         :tags => [TAG]
#       },
#       :children => [...]
#     }
#   ],
#   :focus => フォーカス対象のコンポーネントID, # 複数ツリー・本文を持てるようにUUIDを使用する
# }

module Editor2
  class Leaf
    attr_accessor :id
    attr_accessor :title
    attr_accessor :body
    attr_accessor :metadatum
    attr_accessor :children
    attr_accessor :parent

    def initialize(attributes, parent = nil)
      update_attributes(attributes)
      @parent = parent
    end

    def update_attributes(src)
      attributes = self.to_h.update(src)
      @id = attributes[:id]
      @title = attributes[:title]
      @body = attributes[:body]
      @metadatum = attributes[:metadatum] || {}
      @children = (attributes[:children] || []).map{|e| Leaf.new(e, self) }
    end

    def find(&block)
      if block.call(self)
        self
      else
        children.map{|c| c.find{|s| block.call(s) } }.compact.first
      end
    end

    def to_h
      {
        :id => @id,
        :title => @title,
        :body => @body,
        :metadatum => @metadatum,
        :children => (@children || []).map(&:to_h)
      }
    end

    def ==(other)
      self.id == other.id
    end

    def index
      return if @parent.nil?

      @parent.children.index(self)
    end

    def previous
      return if @parent.nil?

      @parent.children[index - 1]
    end

    def next
      return if @parent.nil?

      @parent.children[index + 1]
    end
  end

  class Store
    attr_reader :subscribers
    attr_reader :selected
    attr_reader :id
    attr_reader :document

    def initialize(src = {})
      @subscribers = []
      load(src)
    end

    def load(src)
      @markup = src[:markup]
      @id = src[:id]
      @document = Leaf.new(src)
      @selected = @id
      @published = src[:published]

      emit
    end

    def stored_document
      @document.to_h.update(
        :markup => @markup,
        :published => @published
      )
    end

    def dispatch(*actions)
      actions.each do |action|
        target =
          if action.target
            @document.find{|l| l.id == action.target }
          else
            nil
          end

        case action.operation
        when :add
          payload = Leaf.new(action.payload, target)
          target.children.insert(action.position, payload)
        when :move
          destination = @document.find{|l| l.id == action.destination }
          target.parent.children.delete(target)
          destination.children.insert(action.position, target)
          target.parent = destination
        when :change
          if target
            target.update_attributes(action.payload)
          else
            @markup = action.payload[:markup] if action.payload[:markup]
            @published = action.payload[:published] if action.payload[:published]
          end
        when :remove
          if target.parent
            target.parent.children.delete(target)
          else
            raise "can't remove root"
          end
        when :select
          @selected = action.target
        else
          raise "unknown action: #{action.operation}"
        end
      end

      emit
    end

    def emit
      # サブスクライバに変更済みの文書を与える
      doc = @document.to_h.update(:markup => @markup, :selected => @selected)
      @subscribers.each{|s| s.apply(doc) }
    end
  end
end
