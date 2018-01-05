require 'test_helper'

class DocumentsControllerTest < ActionController::TestCase
  setup do
    @owner = users(:user1)
    @user = users(:user2)

    @public = documents(:document1)
    @private = documents(:document3)
    @locked = documents(:document5)

    @drive_document = documents(:drive_document1)
  end

  test 'indexはゲストに表示不可' do
    get :index
    assert_response :forbidden
  end

  test "indexはユーザの文書一覧" do
    get :index, :session => {:user_id => @user.id}

    assert_response :success
    assert_equal @user.documents.where(:archived => false).count, assigns(:documents).size

    titles = @user.documents.where(:archived => false).map{|d| d.title}.sort
    assert_equal titles, assigns(:documents).map(&:title).sort
  end

  # test "キーワードを与えると全文検索" do
  #   get :index, {:keywords => '日本語 タイトル'}, {:user_id => @owner.id}
  #
  #   assert_response :success
  #   assert_equal [documents(:document1), documents(:document4)].sort{|a, b| a.id <=> b.id }, assigns(:documents).sort{|a, b| a.id <=> b.id }
  # end

  test 'index アーカイブ表示' do
    get :index,
      :params => {:archived => true},
      :session => {:user_id => @user.id}

    assert_equal @user.documents.where(:public => true, :archived => true).count, assigns(:documents).size

    titles = @user.documents.where(:public => true, :archived => true).map{|d| d.title}.sort
    assert_equal titles, assigns(:documents).map(&:title).sort
  end

  test "ゲストは文書を生成できない" do
    assert_no_difference('Document.count') do
      post :create,
        :params => {:document => @public.attributes}
    end

    assert_response :forbidden
  end

  test "ユーザは文書を作成できる" do
    assert_difference('Document.count') do
      post :create,
        :session => {:user_id => @user.id}
    end

    assert_redirected_to edit_document_path(assigns(:document))
    assert_equal @user, assigns(:document).user
    assert_equal @user.default_markup, assigns(:document).markup
  end

  test "template=IDを指定すると文書をコピーする" do
    assert_difference('Document.count') do
      post :create,
        :params => {:template => @public.id},
        :session => {:user_id => @owner.id}
    end

    assert_redirected_to edit_document_path(assigns(:document))
    assert_equal "#{@public.title} のコピー", assigns(:document).title
  end

  test '階層付きテキストファイルを送信するとインポートされる' do
    assert_difference('Document.count') do
      post :create,
        :params => {:import => fixture_file_upload("structured_text_1root.txt", 'text/plain')},
        :session => {:user_id => @user.id}
    end

    assert_redirected_to edit_document_path(assigns(:document))
    assert_equal @user, assigns(:document).user
    assert_equal '.top level', assigns(:document).title
    assert_equal '2', assigns(:document).body[1]['title']
  end

  test 'トップノードのない階層付きテキストファイルを送信するとタイトルはファイル名' do
    assert_difference('Document.count') do
      post :create,
        :params => {:import => fixture_file_upload("structured_text_noroot.txt", 'text/plain')},
        :session => {:user_id => @user.id}
    end

    assert_equal 'structured_text_noroot.txt', assigns(:document).title
  end

  test '別のユーザの文書はコピーできない' do
    assert_no_difference('Document.count') do
      post :create,
        :params => {:template => @public.id},
        :session => {:user_id => @user.id}
    end

    assert_redirected_to documents_path
  end

  test "ゲストは公開文書を閲覧できる" do
    get :show,
      :params => {:id => @public.id}

    assert_response :success
    assert_equal @public, assigns(:document)
  end

  test "ユーザは公開文書を閲覧できる" do
    get :show,
      :params => {:id => @public.id},
      :session => {:user_id => @user.id}

    assert_response :success
    assert_equal @public, assigns(:document)
  end

  test "オーナーは公開文書を閲覧できる" do
    get :show,
      :params => {:id => @public.id},
      :session => {:user_id => @owner.id}

    assert_response :success
    assert_equal @public, assigns(:document)
  end

  test '指定したバージョンが最新であれば304で応答する' do
    get :show,
      :params => {:id => @public.id, :version => @public.version},
      :session => {:user_id => @owner.id}

      assert_response 304
  end

  test '指定したバージョンが現在と違えば通常応答' do
    get :show,
      :params => {:id => @public.id, :version => 0, :format => :json},
      :session => {:user_id => @owner.id}

    assert_response :success
    assert_equal @public, assigns(:document)
    expected = @public.attributes.select{|k, v| ["id", "title", "description", "body", "version", "markup", "public"].include?(k) }.to_h.to_json
    assert_equal expected, response.body.strip
  end

  test 'typeにstructured_textを指定すると階層付きテキストでダウンロードされる' do
    get :show,
      :params => {:id => @public.id, :format => :text, :type => 'structured_text'},
      :session => {:user_id => @owner.id}

    assert_response :success
    assert_equal @public, assigns(:document)
    assert_equal 'text/plain', response.content_type
    assert_equal @public.to_structured_text, response.body
    assert_equal 'attachment; filename="document 1.txt"', response.header['Content-Disposition']
  end

  test "ゲストは非公開文書を閲覧できない" do
    get :show,
      :params => {:id => @private.id}

    assert_response :forbidden
  end

  test "ユーザは非公開文書を閲覧できない" do
    get :show,
      :params => {:id => @private.id},
      :session => {:user_id => @user.id}

    assert_response :forbidden
  end

  test "オーナーは非公開文書を閲覧できる" do
    get :show,
      :params => {:id => @private.id},
      :session => {:user_id => @owner.id}

    assert_response :success
    assert_equal @private, assigns(:document)
  end

  test "ゲストは編集画面を開けない" do
    get :edit,
      :params => {:id => @public.id}

    assert_response :forbidden
  end

  test "ユーザは編集画面を開けない" do
    get :edit,
      :params => {:id => @public.id},
      :session => {:user_id => @user.id}

    assert_response :forbidden
  end

  test "オーナーは編集画面を開ける" do
    get :edit,
      :params => {:id => @public.id},
      :session => {:user_id => @owner.id}

    assert_response :success
    assert_equal @public, assigns(:document)
  end

  test "デモモードはデモ用文書を読み込む" do
    Sone::Application.config.stub(:demo_document_id, @private.id) do
      get :demo
      assert_response :success
      assert_equal @private, assigns(:document)
    end
  end

  test "ゲストは更新できない" do
    patch :update,
      :params => {:id => @public.id, :document => @public.attributes, :format => :json}

    assert_response :forbidden
  end

  test "ユーザは更新できない" do
    patch :update,
      :params => {:id => @public.id, :document => @public.attributes, :format => :json},
      :session => {:user_id => @user.id}

    assert_response :forbidden
  end

  test "オーナーは更新できる" do
    patch :update,
      :params => {:id => @public.id, :document => @public.attributes, :format => :json},
      :session => {:user_id => @owner.id}

    assert_response :success
  end

  test "ゲストは削除できない" do
    assert_no_difference('Document.count') do
      delete :destroy,
        :params => {:id => @public.id}
    end

    assert_response :forbidden
  end

  test "ユーザは削除できない" do
    assert_no_difference('Document.count') do
      delete :destroy,
        :params => {:id => @public.id},
        :session => {:user_id => @user.id}
    end

    assert_response :forbidden
  end

  test "オーナーは削除できる" do
    assert_difference('Document.count', -1) do
      delete :destroy,
        :params => {:id => @public.id},
        :session => {:user_id => @owner.id}
    end

    assert_redirected_to :controller => :documents,
      :action => :index
  end

  test '保存記録から削除した場合保存記録に戻す' do
    @public.update_attribute(:archived, true)

    assert_difference('Document.count', -1) do
      delete :destroy,
        :params => {:id => @public.id},
        :session => {:user_id => @owner.id}
    end

    assert_redirected_to :controller => :documents,
      :action => :index, :archived => true
  end

  test 'アーカイブへ移動' do
    patch :update,
      :params => {:id => @public.id, :document => {:archived => true}},
      :session => {:user_id => @owner.id}

    assert_redirected_to :controller => :documents,
      :action => :index
    assert assigns(:document).archived
    assert_not assigns(:document).body.blank?
  end

  test 'アーカイブ解除' do
    patch :update,
      :params => {:id => @public.id, :document => {:archived => false}},
      :session => {:user_id => @owner.id}

    assert_redirected_to :controller => :documents,
      :action => :index, :archived => true
  end

  test 'バージョン情報が一致すれば更新受け入れ、新バージョンを応答' do
    patch :update,
      :params => {:id => @public.id, :document => @public.attributes, :format => :json},
      :session => {:user_id => @owner.id}

    assert_response :success
    assert_equal assigns(:document).version, JSON.parse(response.body)['version']
  end

  test 'バージョン情報が不一致の場合、現在のバージョンと内容を付けて応答' do
    payload = @public.attributes.merge('version' => 0)
    patch :update,
      :params => {:id => @public.id, :document => payload, :format => :json},
      :session => {:user_id => @owner.id}

    assert_response 409
    expected = @public.attributes.select{|k, v| ["id", "title", "description", "body", "version", "markup", "public"].include?(k) }.to_h.to_json
    assert_equal expected, response.body.strip
  end

  def mock_drive_service
    token = GoogleToken.new(:token_id => session.id, :token => '{}')
    token.save

    drive_service = Minitest::Mock.new
    2.times{ drive_service.expect(:'authorization=', nil, [Google::Auth::UserRefreshCredentials]) }

    drive_service
  end

  test '#drive_newはトークンが有効の場合、新規文書を指定されたフォルダへ生成して編集画面へ' do
    drive_service = mock_drive_service

    folder_id = 'folder-id'
    ret = Minitest::Mock.new
    ret.expect(:id, 'document-id')
    metadata =
      {
        :name => '新しい文書.html',
        :parents => [folder_id]
      }
    drive_service.expect(:create_file, ret, [metadata, Hash])

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      get :drive_new, :params => {:state => ({ 'folderId' => folder_id}).to_json}
      assert_redirected_to :action => :drive_show, :id => 'document-id'
    end
  end

  test '#drive_newで指定されたフォルダが存在しない場合は404応答' do
    drive_service = mock_drive_service

    folder_id = 'folder-id'
    drive_service.expect(:create_file, nil){ raise Google::Apis::ClientError.new('', :status_code => 404) }

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      get :drive_new, :params => {:state => ({ 'folderId' => folder_id}).to_json}
      assert_response :missing
    end
  end

  test '#drive_newはトークンが存在しない場合、新規文書を作らず認可アクションへ' do
    state = ({'folderId' => 'folder-id'}).to_json
    get :drive_new, :params => {:state => state}

    assert_equal "/drive/documents/new?state=#{ERB::Util.url_encode(state)}", session[:redirect_to]
    assert_redirected_to :controller => :users, :action => :authorize
  end

  test '#drive_newはトークンが無効な場合、新規文書を作らず認可アクションへ' do
    drive_service = mock_drive_service
    drive_service.expect(:create_file, nil){ raise Google::Apis::AuthorizationError.new('') }

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      get :drive_new, :params => {:state => ({ 'folderId' => 'folder-id'}).to_json}
      assert_redirected_to :controller => :users, :action => :authorize
    end
  end

  test '#drive_showはトークンが有効の場合編集画面を返す' do
    drive_service = mock_drive_service
    drive_service.expect(:get_file, {}, [@drive_document.drive_id])

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      get :drive_show, :params => {:id => @drive_document.drive_id}
      assert_response :success
    end
  end

  test '#drive_showはトークンが存在しない場合、編集画面を返さず認可アクションへ' do
    get :drive_show, :params => {:id => @drive_document.drive_id}

    assert_equal "/drive/documents/#{@drive_document.drive_id}", session[:redirect_to]
    assert_redirected_to :controller => :users, :action => :authorize
  end

  test '#drive_showはトークンが無効の場合、編集画面を返さず認可アクションへ' do
    [Google::Apis::AuthorizationError, Signet::AuthorizationError].each do |klass|
      drive_service = mock_drive_service
      drive_service.expect(:get_file, nil){ raise klass.new('') }

      Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
        get :drive_show, :params => {:id => @drive_document.drive_id}

        assert_equal "/drive/documents/#{@drive_document.drive_id}", session[:redirect_to]
        assert_redirected_to :controller => :users, :action => :authorize
      end
    end
  end

  test '#showはトークンが有効の場合、文書内容を200応答' do
    drive_service = mock_drive_service
    drive_service.expect(:get_file, {}, [@drive_document.drive_id])

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      get :show, :params => {:id => @drive_document.id}
      assert_response :success
    end
  end

  test '#showはトークンが存在しない場合、401応答' do
    get :show, :params => {:id => @drive_document.id}
    assert_response 401
    assert_equal '{}', response.body
  end

  test '#showはトークンが無効の場合、401応答' do
    drive_service = mock_drive_service
    drive_service.expect(:get_file, nil){ raise Google::Apis::AuthorizationError.new('') }

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      get :show, :params => {:id => @drive_document.id}
      assert_response 401
      assert_equal '{}', response.body
    end
  end

  test '#showはDriveに文書が存在しない場合404' do
    drive_service = mock_drive_service
    drive_service.expect(:get_file, nil){ raise Google::Apis::ClientError.new('', :status_code => 404) }

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      get :drive_show, :params => {:id => @drive_document.drive_id}
      assert_response :missing
    end
  end

  test '#updateはDriveの文書を更新する' do
    drive_service = mock_drive_service
    drive_service.expect(:get_file, {}, [@drive_document.drive_id])
    drive_service.expect(:update_file, {}, [@drive_document.drive_id, {:name => "#{@drive_document.title}.html"}, Hash])

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      patch :update,
        :params =>
          {
            :id => @drive_document.id,
            :document => @drive_document.attributes,
            :format => :json
          }
      assert_response :success
    end
  end

  test '#updateはトークンが存在しない場合422応答' do
    patch :update,
      :params =>
        {
          :id => @drive_document.id,
          :document => @drive_document.attributes,
          :format => :json
        }
    assert_response 422
    assert_equal '{}', response.body
  end

  test '#updateはトークンが無効の場合401応答' do
    drive_service = mock_drive_service
    drive_service.expect(:get_file, {}, [@drive_document.drive_id])
    drive_service.expect(:update_file, {}){ raise Google::Apis::AuthorizationError.new('') }

    Google::Apis::DriveV3::DriveService.stub(:new, drive_service) do
      patch :update,
        :params =>
          {
            :id => @drive_document.id,
            :document => @drive_document.attributes,
            :format => :json
          }
      assert_response 401
      assert_equal '{}', response.body
    end
  end
end
