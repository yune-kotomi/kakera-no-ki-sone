require 'test_helper'

class DocumentMigrationJobTest < ActiveJob::TestCase
  setup do
    @token = GoogleToken.new(:token_id => 'sessionid', :token => '{}')
    @token.save

    @document = documents(:document2)
    @job = DocumentMigrationJob.new

    @folder_name = 'カケラの樹文書'
    @folder_id = 'folder-id'
  end

  def mock_drive_service(auth_times)
    s = Minitest::Mock.new
    auth_times.times do
      s.expect(:'authorization=', nil, [Google::Auth::UserRefreshCredentials])
    end

    s
  end

  def mock_create_file(s)
    metadata =
      {
        :name => @document.title,
        :parents => [@folder_id]
      }
    ret = Google::Apis::DriveV3::File.new.tap{|f| f.id = 'document-id' }
    s.expect(:create_file, ret, [metadata, Hash])
  end

  test '移行先フォルダがなければ生成する' do
    @drive_service = mock_drive_service(2)

    list = Google::Apis::DriveV3::FileList.new.tap{|l| l.files = [] }
    @drive_service.expect(:list_files, list, [{:q => "name = '#{@folder_name}'"}])

    metadata =
      {
        :name => @folder_name,
        :mime_type => 'application/vnd.google-apps.folder'
      }
    options = {:fields => 'id'}
    folder = Google::Apis::DriveV3::File.new.tap{|f| f.id = @folder_id }
    @drive_service.expect(:create_file, folder, [metadata, options])

    mock_create_file(@drive_service)

    Google::Apis::DriveV3::DriveService.stub(:new, @drive_service) do
      @job.perform(document_id: @document.id, token: @token, host: 'https://example.com')
      assert @drive_service.verify
    end
  end

  test '移行先フォルダがあればそれを使う' do
    @drive_service = mock_drive_service(2)

    folder = Google::Apis::DriveV3::File.new.tap{|f| f.id = @folder_id }
    list = Google::Apis::DriveV3::FileList.new.tap{|l| l.files = [folder] }
    @drive_service.expect(:list_files, list, [{:q => "name = '#{@folder_name}'"}])

    mock_create_file(@drive_service)

    Google::Apis::DriveV3::DriveService.stub(:new, @drive_service) do
      @job.perform(document_id: @document.id, token: @token, host: 'https://example.com')
      assert @drive_service.verify
    end
  end

  test '文書の内容を変換してDriveに格納する' do
    @drive_service = mock_drive_service(2)

    folder = Google::Apis::DriveV3::File.new.tap{|f| f.id = @folder_id }
    list = Google::Apis::DriveV3::FileList.new.tap{|l| l.files = [folder] }
    @drive_service.expect(:list_files, list, [{:q => "name = '#{@folder_name}'"}])

    metadata =
      {
        :name => @document.title,
        :parents => [@folder_id]
      }
    ret = Google::Apis::DriveV3::File.new.tap{|f| f.id = 'document-id' }
    @drive_service.expect(:create_file, ret) do |metadata, options|
      # 保存された内容が元の文書と等価か検証する
      content = options[:upload_source].tap{|s| s.rewind }.read
      content = Nokogiri::HTML(content)
      body = JSON.parse(content.css('#document-body').first['value'])
      expected =
        {
          'title' => @document.title,
          'body' => @document.description,
          'children' => @document.body,
          'markup' => @document.markup
        }
      body.tap{|b| b.delete('version') } == expected
    end

    Google::Apis::DriveV3::DriveService.stub(:new, @drive_service) do
      @job.perform(document_id: @document.id, token: @token, host: 'https://example.com')
      assert @drive_service.verify
    end
  end
end
