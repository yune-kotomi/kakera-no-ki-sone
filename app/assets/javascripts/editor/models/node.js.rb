module Editor
  module Model
    class Node < Juso::Model::Base
      attribute :title
      attribute :body
      attribute :metadata, :default => {}
    end

    class Root < Node
      def save
      end
    end
  end
end
