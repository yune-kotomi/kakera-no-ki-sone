require 'test_helper'

module Drive
  class DocumentsControllerTest < ActionController::TestCase
    setup do
      @document_id = 'document-id'
    end

    def mock_drive_service
      token = GoogleToken.new(:token_id => session.id, :token => '{}')
      token.save

      drive_service = Minitest::Mock.new
      3.times{ drive_service.expect(:'authorization=', nil, [Google::Auth::UserRefreshCredentials]) }

      drive_service
    end

    def expect_document_get(service, document_id, writable = true)
      metadata =
        Google::Apis::DriveV3::File.new.tap do |f|
          f.capabilities =
            Google::Apis::DriveV3::File::Capabilities.new.tap do |c|
              c.can_edit = writable
            end
        end
      service.expect(:get_file, metadata) {|id, options| id == document_id && options[:fields] == 'capabilities' }

      service.expect(:get_file, open('test/fixtures/drive_document.html')) {|id, options| id == document_id && options[:download_dest].is_a?(StringIO) }
    end

    test '#newはトークンが有効の場合、新規文書を指定されたフォルダへ生成して編集画面へ' do
      drive_service = mock_drive_service

      folder_id = 'folder-id'
      ret = Minitest::Mock.new
      ret.expect(:id, 'document-id')
      metadata =
        {
          :name => '新しい文書',
          :parents => [folder_id]
        }
      drive_service.expect(:create_file, ret, [metadata, Hash])

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :new, :params => {:state => ({ 'folderId' => folder_id}).to_json}
        assert_redirected_to :action => :show, :id => 'document-id'
      end
    end

    test '#newで指定されたフォルダが存在しない場合は404応答' do
      drive_service = mock_drive_service

      folder_id = 'folder-id'
      drive_service.expect(:create_file, nil){ raise Google::Apis::ClientError.new('', :status_code => 404) }

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :new, :params => {:state => ({ 'folderId' => folder_id}).to_json}
        assert_response :missing
      end
    end

    test '#newはトークンが存在しない場合、新規文書を作らず認可アクションへ' do
      state = ({'folderId' => 'folder-id'}).to_json
      get :new, :params => {:state => state}

      assert_equal "/drive/documents/new?state=#{ERB::Util.url_encode(state)}", session[:redirect_to]
      assert_redirected_to :controller => '/users', :action => :authorize
    end

    test '#newはトークンが無効な場合、新規文書を作らず認可アクションへ' do
      drive_service = mock_drive_service
      drive_service.expect(:create_file, nil){ raise Google::Apis::AuthorizationError.new('') }

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :new, :params => {:state => ({ 'folderId' => 'folder-id'}).to_json}
        assert_redirected_to :controller => '/users', :action => :authorize
      end
    end

    test '#showはトークンが有効の場合編集画面を返す' do
      drive_service = mock_drive_service
      expect_document_get(drive_service, @document_id)

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :show, :params => {:id => @document_id}
        assert_response :success
      end
    end

    test '指定したバージョンが最新であれば304で応答する' do
      drive_service = mock_drive_service
      expect_document_get(drive_service, @document_id)

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :show,
          :params => {:id => @document_id, :version => 288}

        assert_response 304
      end
    end

    test '#showはトークンが存在しない場合、編集画面を返さず認可アクションへ' do
      get :show, :params => {:id => @document_id}

      assert_equal "/drive/documents/#{@document_id}", session[:redirect_to]
      assert_redirected_to :controller => '/users', :action => :authorize
    end

    test '#showはトークンが無効の場合、編集画面を返さず認可アクションへ' do
      [Google::Apis::AuthorizationError, Signet::AuthorizationError].each do |klass|
        drive_service = mock_drive_service
        drive_service.expect(:get_file, nil){ raise klass.new('') }

        Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
          get :show, :params => {:id => @document_id}

          assert_equal "/drive/documents/#{@document_id}", session[:redirect_to]
          assert_redirected_to :controller => '/users', :action => :authorize
        end
      end
    end

    test '#show.jsonはトークンが存在しない場合、401応答' do
      get :show, :params => {:id => @document_id}, :format => :json
      assert_response 401
      assert_equal '{}', response.body
    end

    test '#show.jsonはトークンが無効の場合、401応答' do
      drive_service = mock_drive_service
      drive_service.expect(:get_file, nil){ raise Google::Apis::AuthorizationError.new('') }

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :show, :params => {:id => @document_id}, :format => :json
        assert_response 401
        assert_equal '{}', response.body
      end
    end

    test '#showはDriveに文書が存在しない場合404' do
      drive_service = mock_drive_service
      drive_service.expect(:get_file, nil){ raise Google::Apis::ClientError.new('', :status_code => 404) }

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :show, :params => {:id => @document_id}
        assert_response :missing
      end
    end

    test '#updateはDriveの文書を更新する' do
      drive_service = mock_drive_service
      expect_document_get(drive_service, @document_id)

      drive_service.expect(:update_file, {}, [@document_id, {:name => "test"}, Hash])

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        patch :update,
          :params =>
            {
              :id => @document_id,
              :document => {:title => 'test', :version => 288, :body => '[]'},
              :format => :json
            }
        assert_response :success
      end
    end

    test 'バージョン情報が不一致の場合、現在のバージョンと内容を付けて応答' do
      drive_service = mock_drive_service
      expect_document_get(drive_service, @document_id)
      drive_service.expect(:update_file, {}, [@document_id, {:name => "test"}, Hash])

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        patch :update,
          :params =>
            {
              :id => @document_id,
              :document => {:title => 'test', :version => 287, :body => '[]'},
              :format => :json
            }

        assert_response 409
        actual = JSON.parse(response.body)
        assert_equal ["id", "title", "description", "body", "markup", "version", "public"], actual.keys
      end
    end

    test '#updateはトークンが存在しない場合401応答' do
      patch :update,
        :params =>
          {
            :id => @document_id,
            :document => {:title => ''},
            :format => :json
          }
      assert_response 401
      assert_equal '{}', response.body
    end

    test '#updateはトークンが無効の場合401応答' do
      drive_service = mock_drive_service
      drive_service.expect(:get_file, {}){ raise Google::Apis::AuthorizationError.new('') }

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        patch :update,
          :params =>
            {
              :id => @document_id,
              :document => {:title => ''},
              :format => :json
            }
        assert_response 401
        assert_equal '{}', response.body
      end
    end

    test '#updateは書き込み権限がなければ403' do
      drive_service = mock_drive_service
      expect_document_get(drive_service, @document_id, false)

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        patch :update,
          :params =>
            {
              :id => @document_id,
              :document => {:title => 'test', :version => 288, :body => '[]'},
              :format => :json
            }
        assert_response :forbidden
      end
    end
  end
end
