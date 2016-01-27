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
    get :index, {}, {:user_id => @user.id}

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
    get :index, {:archived => true}, {:user_id => @user.id}

    assert_equal @user.documents.where(:public => true, :archived => true).count, assigns(:documents).size

    titles = @user.documents.where(:public => true, :archived => true).map{|d| d.title}.sort
    assert_equal titles, assigns(:documents).map(&:title).sort
  end

  test "ゲストは文書を生成できない" do
    assert_no_difference('Document.count') do
      post :create,
        {:document => @public.attributes}
    end

    assert_response :forbidden
  end

  test "ユーザは文書を作成できる" do
    assert_difference('Document.count') do
      post :create,
        {},
        {:user_id => @user.id}
    end

    assert_redirected_to edit_document_path(assigns(:document))
    assert_equal @user, assigns(:document).user
    assert_equal @user.default_markup, assigns(:document).markup
  end

  test "template=IDを指定すると文書をコピーする" do
    assert_difference('Document.count') do
      post :create,
        {:template => @public.id},
        {:user_id => @owner.id}
    end

    assert_redirected_to edit_document_path(assigns(:document))
    assert_equal "#{@public.title} のコピー", assigns(:document).title
  end

  test '階層付きテキストファイルを送信するとインポートされる' do
    assert_difference('Document.count') do
      post :create,
        {:import => fixture_file_upload("structured_text_1root.txt", 'text/plain')},
        {:user_id => @user.id}
    end

    assert_redirected_to edit_document_path(assigns(:document))
    assert_equal @user, assigns(:document).user
    assert_equal '.top level', assigns(:document).title
    assert_equal '2', assigns(:document).body[1]['title']
  end

  test 'トップノードのない階層付きテキストファイルを送信するとタイトルはファイル名' do
    assert_difference('Document.count') do
      post :create,
        {:import => fixture_file_upload("structured_text_noroot.txt", 'text/plain')},
        {:user_id => @user.id}
    end

    assert_equal 'structured_text_noroot.txt', assigns(:document).title
  end

  test '別のユーザの文書はコピーできない' do
    assert_no_difference('Document.count') do
      post :create,
        {:template => @public.id},
        {:user_id => @user.id}
    end

    assert_redirected_to documents_path
  end

  test "ゲストは公開文書を閲覧できる" do
    get :show,
      {:id => @public.id}

    assert_response :success
    assert_equal @public, assigns(:document)
  end

  test "ユーザは公開文書を閲覧できる" do
    get :show,
      {:id => @public.id},
      {:user_id => @user.id}

    assert_response :success
    assert_equal @public, assigns(:document)
  end

  test "オーナーは公開文書を閲覧できる" do
    get :show,
      {:id => @public.id},
      {:user_id => @owner.id}

    assert_response :success
    assert_equal @public, assigns(:document)
  end

  test 'typeにstructured_textを指定すると階層付きテキストでダウンロードされる' do
    get :show,
      {:id => @public.id, :format => :text, :type => 'structured_text'},
      {:user_id => @owner.id}

    assert_response :success
    assert_equal @public, assigns(:document)
    assert_equal 'text/plain', response.content_type
    assert_equal @public.to_structured_text, response.body
    assert_equal 'attachment; filename="document 1.txt"', response.header['Content-Disposition']
  end

  test "ゲストは非公開文書を閲覧できない" do
    get :show,
      {:id => @private.id}

    assert_response :forbidden
  end

  test "ユーザは非公開文書を閲覧できない" do
    get :show,
      {:id => @private.id},
      {:user_id => @user.id}

    assert_response :forbidden
  end

  test "オーナーは非公開文書を閲覧できる" do
    get :show,
      {:id => @private.id},
      {:user_id => @owner.id}

    assert_response :success
    assert_equal @private, assigns(:document)
  end

  test "ゲストがパスワード付き非公開文書を開くとプロンプトが出る" do
    get :show,
      {:id => @locked.id }

    assert_response :success
    assert_equal @locked, assigns(:document)
    assert_select 'title', 'パスワードで保護された文書です: カケラの樹'
  end

  test "ユーザがパスワード付き非公開文書を開くとプロンプトが出る" do
    get :show,
      {:id => @locked.id },
      {:user_id => @user.id}

    assert_response :success
    assert_equal @locked, assigns(:document)
    assert_select 'title', 'パスワードで保護された文書です: カケラの樹'
  end

  test "オーナーがパスワード付き非公開文書を開くとそのまま表示される" do
    get :show,
      {:id => @locked.id },
      {:user_id => @owner.id}

    assert_response :success
    assert_equal @locked, assigns(:document)
    assert_select 'title', "#{@locked.title}: カケラの樹"
  end

  test "ゲストが正しいパスワードを送出するとパスワード付き非公開文書が開く" do
    post :show,
      {:id => @locked.id, :password => 'password'}

    assert_response :success
    assert_equal @locked, assigns(:document)
    assert_select 'title', "#{@locked.title}: カケラの樹"
  end

  test "ゲストが不正なパスワードを送出するとプロンプトにリダイレクト" do
    post :show,
      {:id => @locked.id, :password => 'wrong password'}

    assert_redirected_to document_path(@locked)
  end

  test "ユーザが正しいパスワードを送出するとパスワード付き非公開文書が開く" do
    post :show,
      {:id => @locked.id, :password => 'password'},
      {:user_id => @user.id}

    assert_response :success
    assert_equal @locked, assigns(:document)
    assert_select 'title', "#{@locked.title}: カケラの樹"
  end

  test "ユーザが不正なパスワードを送出するとプロンプトにリダイレクト" do
    post :show,
      {:id => @locked.id, :password => 'wrong password'},
      {:user_id => @user.id}

    assert_redirected_to document_path(@locked)
  end

  test "ゲストは編集画面を開けない" do
    get :edit,
      {:id => @public.id}

    assert_response :forbidden
  end

  test "ユーザは編集画面を開けない" do
    get :edit,
      {:id => @public.id},
      {:user_id => @user.id}

    assert_response :forbidden
  end

  test "オーナーは編集画面を開ける" do
    get :edit,
      {:id => @public.id},
      {:user_id => @owner.id}

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
      {:id => @public.id, :document => @public.attributes, :format => :json}

    assert_response :forbidden
  end

  test "ユーザは更新できない" do
    patch :update,
      {:id => @public.id, :document => @public.attributes, :format => :json},
      {:user_id => @user.id}

    assert_response :forbidden
  end

  test "オーナーは更新できる" do
    patch :update,
      {:id => @public.id, :document => @public.attributes, :format => :json},
      {:user_id => @owner.id}

    assert_response :success
  end

  test "ゲストは削除できない" do
    assert_no_difference('Document.count') do
      delete :destroy,
        {:id => @public.id}
    end

    assert_response :forbidden
  end

  test "ユーザは削除できない" do
    assert_no_difference('Document.count') do
      delete :destroy,
        {:id => @public.id},
        {:user_id => @user.id}
    end

    assert_response :forbidden
  end

  test "オーナーは削除できる" do
    assert_difference('Document.count', -1) do
      delete :destroy,
        {:id => @public.id},
        {:user_id => @owner.id}
    end

    assert_redirected_to :controller => :documents,
      :action => :index
  end
end
