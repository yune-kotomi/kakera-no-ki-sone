module Editor
  module Model
    class Node < Juso::Model::Base
      attribute :id
      attribute :chapter_number, :default => ''
      attribute :title
      attribute :body
      attribute :metadatum, :default => {}
      attribute :children, :default => [], :type => Node

      def initialize(data = {}, parent = nil)
        super(data)
        @parent = parent

        observe(:chapter_number) { update_chapter_number }.call
        observe(:children) { update_chapter_number }
        observe { @parent.trigger(nil, :document_update) unless parent.nil? }
        observe(nil, :event => :document_update) { @parent.trigger(nil, :document_update) unless parent.nil? }
      end

      def ==(v)
        if v.is_a?(self.class)
          self.id == v.id
        end
      end

      def scan(&block)
        ret = [block.call(self)]
        ret.push children.map {|c| c.scan(&block) }
        ret.flatten
      end

      def find(target_id)
        if id == target_id
          self
        else
          children.map{|c| c.find(target_id) }.compact.first
        end
      end

      def add_child(position, init_data = {})
        new_child = Node.new(init_data.merge(:id => UUID.generate), self)
        old_children = children.dup
        children.insert(position, new_child)
        trigger(:children, :change, children, old_children)
        new_child
      end

      def last_child
        if children.empty?
          # 子がなければ自分自身が最後
          self
        else
          children.last.last_child
        end
      end

      def destroy
        @parent.children = @parent.children.reject{|c| c == self }
        trigger(nil, :destroy)
        self
      end

      def update_chapter_number
        children.each_with_index do |child, index|
          child.chapter_number = [chapter_number, index + 1].reject{|s| s == '' }.join('.')
        end
      end

      def root
        if self.parent.is_a?(Root)
          self.parent
        else
          self.parent.root
        end
      end
    end

    class Root < Node
      attribute :public, :default => false
      attribute :archived, :default => false
      attribute :markup, :default => 'plaintext'
      attribute :tags, :default => []

      def initialize(data = {}, parent = nil)
        super

        observe(nil, :event => :document_update) do
          self.tags = children.map {|c| c.scan {|n| n.metadatum['tags'] } }.flatten.uniq.compact.sort
        end.call
      end

      def save
        HTTP.post("/documents/#{self.id}.json", :payload => self.attributes.to_json) do |response|
          yield(response)
        end
      end

      def rearrange(target_id, from_id, to_id, position)
        target = find(target_id)
        from = find(from_id)
        to = find(to_id)

        from.children = from.children.reject{|c| c == target }

        children = to.children.clone
        children.insert(position, target)
        to.children = children

        target.parent = to
      end
    end
  end
end
