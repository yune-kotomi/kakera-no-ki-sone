require 'test_helper'
require 'rss'

class UsersControllerTest < ActionController::TestCase
  setup do
    WebMock.reset!
    @user = users(:user1)
    @user2 = users(:user2)
  end

  test "loginは認証サービスへリダイレクトする" do
    get :login
    assert_response :redirect

    uri = URI @response.header['Location']
    params = CGI.parse uri.query

    assert_equal Sone::Application.config.authentication.service_id,
      params['id'].first.to_i
    assert params['token'].first.present?
  end

  test "login_completeは認証情報を取得し、問題なければユーザを生成する" do
    new_user = {
      :profile_id => 0,
      :domain_name => 'www.example.com',
      :screen_name => 'screen_name',
      :nickname => 'nickname',
      :profile_text => 'profile',
      :openid_url => 'http://www.example.com/screen_name',
      :exp => 5.minutes.from_now.to_i
    }

    WebMock.stub_request(:get, /#{Sone::Application.config.authentication.entry_point}\/retrieve\?.*/).to_return(
      :body => JWT.encode(new_user, Sone::Application.config.authentication.key)
    )

    payload = {'key' => 'auth key', 'exp' => 5.minutes.from_now.to_i}
    token = JWT.encode(payload, Sone::Application.config.authentication.key)
    assert_difference 'User.count' do
      get :login_complete,
        :params => {
          :id => Sone::Application.config.authentication.service_id,
          :token => token
        }
    end
    assert_redirected_to :controller => :documents, :action => :index
    assert_not_nil assigns(:user)
    assert_equal assigns(:user).id, session[:user_id]
  end

  test "login_completeは既存ユーザをログインさせる" do
    new_user = {
      :profile_id => @user.kitaguchi_profile_id,
      :domain_name => @user.domain_name,
      :screen_name => @user.screen_name,
      :nickname => @user.nickname,
      :profile_text => @user.profile_text,
      :openid_url => 'http://example.com/screen_name',
      :exp => 5.minutes.from_now.to_i
    }

    WebMock.stub_request(:get, /#{Sone::Application.config.authentication.entry_point}\/retrieve\?.*/).to_return(
      :body => JWT.encode(new_user, Sone::Application.config.authentication.key)
    )

    payload = {'key' => 'auth key', 'exp' => 5.minutes.from_now.to_i}
    token = JWT.encode(payload, Sone::Application.config.authentication.key)
    assert_no_difference  'User.count' do
      get :login_complete,
        :params => {
          :id => Sone::Application.config.authentication.service_id,
          :token => token
        }
    end
    assert_redirected_to :controller => :documents, :action => :index
    assert_not_nil assigns(:user)
    assert_equal @user.id, session[:user_id]
  end

  test "login_completeに不正な署名が来たら蹴る" do
    get :login_complete,
      :params => {:id => Sone::Application.config.authentication.service_id}
    assert_response :forbidden
  end

  test "login_completeは引き渡された認証情報が不正なら蹴る" do
    WebMock.stub_request(:get, /#{Sone::Application.config.authentication.entry_point}\/retrieve\?.*/).to_return(
      :body => 'invalid data'
    )

    payload = {'key' => 'auth key', 'exp' => 5.minutes.from_now.to_i}
    token = JWT.encode(payload, Sone::Application.config.authentication.key)
    assert_no_difference  'User.count' do
      get :login_complete,
        :params => {
          :id => Sone::Application.config.authentication.service_id,
          :token => token
        }
    end
    assert_response :forbidden

    WebMock.reset!
  end

  test "logoutはセッションのログイン情報を消し、認証サービスからもログアウトさせる" do
    get :logout,
      :session => {:user_id => @user.id}
    assert_response :redirect
    assert @response.header['Location'] =~ /logout/
  end

  test "updateは署名が正当ならその内容でuserを更新する(Kitugachi認証サービスからのPOST)" do
    payload = {
      'id' => Sone::Application.config.authentication.service_id,
      'profile_id' => @user.kitaguchi_profile_id,
      'nickname' => 'new nickname',
      'profile_text' => 'new profile text',
      'profile_image' => 'http://www.hatena.ne.jp/users/ha/hatena/profile.gif',
      'exp' => 5.minutes.from_now.to_i
    }

    post :update,
      :params => {:token => JWT.encode(payload, Sone::Application.config.authentication.key)}

    assert_response :success
    assert_not_nil assigns(:user)
    assert_equal 'new nickname', assigns(:user).nickname
    assert_equal payload['profile_image'], assigns(:user).profile_image
  end

  test "updateは署名が不正なら蹴る(Kitugachi認証サービスからのPOST)" do
    payload = {
      'id' => Sone::Application.config.authentication.service_id,
      'profile_id' => @user.kitaguchi_profile_id,
      'nickname' => 'new nickname',
      'profile_text' => 'new profile text',
      'exp' => 5.minutes.from_now.to_i
    }

    post :update,
      :params => {:token => JWT.encode(payload, 'wrong key')}

    assert_response :forbidden
  end

  test "セッションが有効なら署名チェックせずに更新する(設定画面からのPOST)" do
    params = {:user => {:default_markup => 'hatena'}, :format => :json}
    patch :update,
      :params => params,
      :session => {:user_id => @user.id}
    assert_response :success
    assert 'hatena', assigns(:login_user).default_markup
  end

  test "show(format=rss)は公開文書のみを含むvalidなRSSを返す" do
    get :show,
      :params => {
        :domain_name => @user.domain_name,
        :screen_name => @user.screen_name,
        :format => :rss
      }

    assert_response :success

    assert_nothing_raised do
      rss = RSS::Parser.parse(@response.body)
      assert_not_nil rss

      assert_equal @user.documents.where(:public => true).count, rss.items.size

      titles = @user.documents.where(:public => true).map{|d| d.title}.sort
      assert_equal titles, rss.items.map{|item| item.title }.sort
    end
  end

  test "存在しないユーザを叩いたら404" do
    get :show,
      :params => {:domain_name => 'non-exists', :screen_name => 'non-exists'}
    assert_response :missing
  end

  test "showはゲストに公開文書のみを表示" do
    get :show,
      :params => {
        :domain_name => @user.domain_name,
        :screen_name => @user.screen_name
      }

    assert_equal @user.documents.where(:public => true).count, assigns(:documents).size

    titles = @user.documents.where(:public => true).map{|d| d.title}.sort
    assert_equal titles, assigns(:documents).map(&:title).sort
  end

  test "showは他のユーザに公開文書のみを表示" do
    get :show,
      :params => {
        :domain_name => @user.domain_name,
        :screen_name => @user.screen_name
      },
      :session => {:user_id => @user2.id}

      assert_equal @user.documents.where(:public => true).count, assigns(:documents).size

      titles = @user.documents.where(:public => true).map{|d| d.title}.sort
      assert_equal titles, assigns(:documents).map(&:title).sort
  end

  test "showはオーナーにも公開文書のみを表示" do
    get :show,
      :params => {
        :domain_name => @user.domain_name,
        :screen_name => @user.screen_name
      },
      :session => {:user_id => @user.id}

      assert_equal @user.documents.where(:public => true).count, assigns(:documents).size

      titles = @user.documents.where(:public => true).map{|d| d.title}.sort
      assert_equal titles, assigns(:documents).map(&:title).sort
  end

  test '#authorizeはGoogleへリダイレクトさせてOAuth認可を得る' do
    authorizer = Minitest::Mock.new
    authorizer.expect(:get_authorization_url, 'https://example.com/', [Hash])

    Google::Auth::WebUserAuthorizer.stub(:new, authorizer) do
      get :authorize
      assert_response :redirect
    end
  end

  test '#authorize_callbackはセッションに戻り先があればそこに戻す' do
    authorizer = Minitest::Mock.new
    authorizer.expect(:handle_auth_callback, nil, [session.id, ActionController::TestRequest])
    r = 'https:/example.com'

    Google::Auth::WebUserAuthorizer.stub(:new, authorizer) do
      get :authorize_callback, :session => {:redirect_to => r}
      assert_redirected_to r
    end
  end

  test '#authorize_callbackはセッションに戻り先が無ければインストール完了画面に飛ばす' do
    authorizer = Minitest::Mock.new
    authorizer.expect(:handle_auth_callback, nil, [session.id, ActionController::TestRequest])

    Google::Auth::WebUserAuthorizer.stub(:new, authorizer) do
      get :authorize_callback
      assert_redirected_to :controller => :welcome, :action => :installed
    end
  end
end
