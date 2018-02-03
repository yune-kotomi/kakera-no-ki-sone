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
    assert_equal @user.documents.count, assigns(:documents).size

    titles = @user.documents.map{|d| d.title}.sort
    assert_equal titles, assigns(:documents).map(&:title).sort
  end

  test "#showは404" do
    get :show,
      :params => {:id => @public.id}

    assert_response :missing
  end

  test "#showはユーザでも404" do
    get :show,
      :params => {:id => @public.id},
      :session => {:user_id => @user.id}

    assert_response :missing
  end

  test "#showはオーナーでも404" do
    get :show,
      :params => {:id => @public.id},
      :session => {:user_id => @owner.id}

    assert_response :missing
  end
end
