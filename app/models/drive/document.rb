module Drive
  class Document
    attr_accessor :id
    attr_accessor :parent

    attr_accessor :body

    def initialize(src = {})
      @body = {
        'title' => '新しい文書',
        'body' => '',
        'children' => [],
        'markup' => 'plaintext'
      }
      ([:id, :parent, :body] & src.keys).each{|c| self.send("#{c}=".to_sym, src[c]) }
      self
    end

    def save(token)
      if @id.nil?
        # 新規作成
        metadata = {:name => @body['title']}
        metadata[:parents] = [@parent] if @parent
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
      Drive::DocumentsController.render(:partial => 'documents/drive_document.html.erb', :assigns => {:document => self})
    end

    def markup
      body['markup']
    end

    def new_version
      ActiveRecord::Base.connection.select_one("SELECT nextval('document_version_seq')")['nextval']
    end

    def self.find(id, token)
      content = service(token).get_file(id, :download_dest => StringIO.new)
      content.rewind
      content = Nokogiri::HTML(content.read)
      body = JSON.parse(content.css('#document-body').first['value'])

      Document.new(
        :id => id,
        :body => body
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
