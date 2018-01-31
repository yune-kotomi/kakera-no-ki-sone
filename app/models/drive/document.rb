module Drive
  class Document
    attr_accessor :id
    attr_accessor :parent

    attr_accessor :body

    def initialize(src = {}, options = {})
      @body = {
        'title' => '新しい文書',
        'body' => '',
        'children' => [],
        'markup' => 'plaintext'
      }
      ([:id, :parent, :body] & src.keys).each{|c| self.send("#{c}=".to_sym, src[c]) }

      @created_at = src[:created_at]
      @updated_at = src[:updated_at]

      @writable = options[:writable]
      @host = options[:host] || 'example.com'

      self
    end

    def save(token)
      if @id.nil?
        # 新規作成
        metadata = {:name => @body['title']}
        metadata[:parents] = [@parent] if @parent
        metadata[:created_time] = @created_at.iso8601 if @created_at
        metadata[:modified_time] = @updated_at.iso8601 if @updated_at

        body['version'] = new_version

        ret =
          service(token).create_file(
            metadata,
            :upload_source => StringIO.new(to_html),
            :content_type => 'text/html'
          )
        @id = ret.id

      else
        # 更新
        body['version'] = new_version

        ret =
          service(token).update_file(
            @id,
            {:name => @body['title']},
            :upload_source => StringIO.new(to_html)
          )
      end
      true
    end

    def to_html
      Drive::DocumentsController.render(
        :partial => 'documents/drive_document.html.erb',
        :assigns => {:document => self},
        :locals => {:host => @host}
      )
    end

    def markup
      body['markup']
    end

    def new_version
      ActiveRecord::Base.connection.select_one("SELECT nextval('document_version_seq')")['nextval']
    end

    def writable?
      @writable
    end

    def self.find(id, token, host: '')
      metadata = service(token).get_file(id, :fields => 'capabilities')
      content = service(token).get_file(id, :download_dest => StringIO.new)
      content.rewind
      content = Nokogiri::HTML(content.read)
      body = JSON.parse(content.css('#document-body').first['value'])

      Document.new(
        {:id => id, :body => body},
        :writable => metadata.capabilities.can_edit,
        :host => host
      )
    end

    def service(token)
      self.class.service(token)
    end

    def self.service(token)
      drive = Google::Apis::DriveV3::DriveService.new
      drive.authorization = token.credential
      drive
    end
  end
end
