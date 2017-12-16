module Editor2
  module Loader
    class Xhr
      def load(id, version = nil)
        uri = "/documents/#{id}.json"
        uri += "?version=#{version}" if version
        HTTP.get(uri) do |response|
          if response.status_code == 200
            yield(self.class.response_to_doc(response))
          else
            p response
          end
        end
      end

      def self.response_to_doc(response)
        {
          :id => response.json['id'],
          :title => response.json['title'],
          :body => response.json['description'],
          :children => response.json['body'],
          :markup => response.json['markup'],
          :published => response.json['public'],
          :version => response.json['version']
        }
      end
    end
  end
end
