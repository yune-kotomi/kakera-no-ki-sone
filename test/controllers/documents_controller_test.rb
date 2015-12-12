require 'test_helper'

class DocumentsControllerTest < ActionController::TestCase
  setup do
    @owner = users(:user1)
    @user = users(:user2)

    @public = documents(:document1)
    @private = documents(:document3)
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

    assert_redirected_to :controller => :users,
      :action => :show,
      :domain_name => @owner.domain_name,
      :screen_name => @owner.screen_name
  end
end
