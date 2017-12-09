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
      self.id.to_s == other.id.to_s
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

    def initialize
      @subscribers = []
    end

    def stored_document
      @document.to_h.update(
        :markup => @markup,
        :published => @published,
        :selected => @selected,
        :version => @version
      )
    end

    def dispatch(*actions)
      actions.each do |action|
        target =
          if action.target
            @document.find{|l| l.id.to_s == action.target.to_s }
          else
            nil
          end

        case action.operation
        when :load
          @markup = action.payload[:markup]
          @id = action.payload[:id]
          @selected = @id
          @document = Leaf.new(action.payload)
          @published = action.payload[:published]
          @version = action.payload[:version]

        when :add
          payload = Leaf.new(action.payload, target)
          # 追加先がない場合(他端末で削除?)はルートノードで代用
          (target || @document).children.insert(action.position, payload)

        when :move
          # 移動先がない場合(他端末で削除?)はルートノードで代用
          destination = @document.find{|l| l.id == action.destination } || @document
          # 移動対象が消えている場合は何もしない
          if target
            target.parent.children.delete(target)
            destination.children.insert(action.position, target)
            target.parent = destination
          end

        when :change
          if target
            target.update_attributes(action.payload)
          else
            @markup = action.payload[:markup] if action.payload.keys.include?(:markup)
            @published = action.payload[:published] if action.payload.keys.include?(:published)
            @version = action.payload[:version] if action.payload.keys.include?(:version)
          end

        when :remove
          if target
            if target.parent
              target.parent.children.delete(target)
            else
              raise "can't remove root"
            end
          end

        when :select
          @selected = action.target || @document.id

        else
          raise "unknown action: #{action.operation}"
        end
      end

      emit(actions)
    end

    def emit(processed_actions = [])
      # サブスクライバに変更済みの文書を与える
      @subscribers.each{|s| s.apply(stored_document, processed_actions) }
    end
  end
end
