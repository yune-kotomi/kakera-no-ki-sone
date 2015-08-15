module Editor
  module Model
    class Node < Juso::Model::Base
      attribute :id
      attribute :title
      attribute :body
      attribute :metadatum, :default => {}
      attribute :children, :default => [], :type => Node

      def initialize(data = {}, parent = nil)
        super(data)
        @parent = parent
      end

      def scan(&block)
        block.call(self)
        children.each {|c| block.call(c) }
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
    end

    class Root < Node
      attribute :private, :default => true
      attribute :archived, :default => false
      attribute :password
      attribute :markup, :default => 'plaintext'

      def save
        HTTP.post("/documents/#{self.id}.json", :payload => self.attributes.to_json) do |response|
          yield(response)
        end
      end

      def find(target_id)
        if target_id.nil?
          self
        else
          children.map{|c| c.find(target_id) }.compact.first
        end
      end

      def rearrange(target_id, from_id, to_id, position)
        target = find(target_id)
        from = find(from_id)
        to = find(to_id)
        from.children.delete(target)
        to.children.insert(position, target)
      end
    end
  end
end
