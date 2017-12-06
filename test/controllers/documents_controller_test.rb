require 'test_helper'

class DocumentsControllerTest < ActionController::TestCase
  setup do
    @owner = users(:user1)
    @user = users(:user2)

    @public = documents(:document1)
    @private = documents(:document3)
    @locked = documents(:document5)
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
  end

  test 'バージョン情報が不一致の場合、現在のバージョンと内容を付けて応答' do
    payload = @public.attributes.merge('version' => 0)
    patch :update,
      :params => {:id => @public.id, :document => payload, :format => :json},
      :session => {:user_id => @owner.id}

    assert_response 409
    assert_equal @public.attributes.to_json, response.body
  end
end
