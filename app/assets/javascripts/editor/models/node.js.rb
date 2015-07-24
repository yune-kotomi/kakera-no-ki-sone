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
    end
  end
end
