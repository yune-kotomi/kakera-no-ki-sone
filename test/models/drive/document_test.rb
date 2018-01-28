require 'test_helper'

module Drive
  class DocumentTest < ActiveSupport::TestCase
    setup do
      @token = GoogleToken.new(:token_id => 'sessionid', :token => '{}')
      @token.save

      @drive_service = Minitest::Mock.new
      2.times{ @drive_service.expect(:'authorization=', nil, [Google::Auth::UserRefreshCredentials]) }

      @id = 'document-id'
    end

    test 'findで文書を取得できる' do
      doc = open('test/fixtures/drive_document.html')
      metadata =
        Google::Apis::DriveV3::File.new.tap do |f|
          f.capabilities =
            Google::Apis::DriveV3::File::Capabilities.new.tap do |c|
              c.can_edit = true
            end
        end
      @drive_service.expect(:get_file, metadata) {|id, options| id == @id && options[:fields] == 'capabilities' }

      @drive_service.expect(:get_file, doc) {|id, options| id == @id && options[:download_dest].is_a?(StringIO) }

      Google::Apis::DriveV3::DriveService.stub(:new, @drive_service) do
        document = Drive::Document.find(@id, @token)
        assert_equal document.id, @id
        assert_equal document.body['title'], '新しい文書'
        assert_equal document.writable?, true
      end
    end

    test '初回の#saveでは文書を新規作成する' do
      ret = Minitest::Mock.new
      ret.expect(:id, @id)
      metadata = {:name => '新しい文書'}
      @drive_service.expect(:create_file, ret, [metadata, Hash])

      document = Drive::Document.new
      Google::Apis::DriveV3::DriveService.stub(:new, @drive_service) do
        assert document.save(@token)
        assert_equal document.id, @id
      end
    end

    test '２回め以降の#saveでは文書を更新する' do
      metadata = {:name => '新しい文書'}
      @drive_service.expect(:update_file, {}, [@id, metadata, Hash])

      document = Drive::Document.new(:id => @id)
      Google::Apis::DriveV3::DriveService.stub(:new, @drive_service) do
        assert document.save(@token)
        assert_equal document.id, @id
      end
    end
  end
end
