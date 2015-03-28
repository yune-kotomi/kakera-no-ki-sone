require 'test_helper'
require 'rss'

class UsersControllerTest < ActionController::TestCase
  def sign(message)
    OpenSSL::HMAC::hexdigest(
      OpenSSL::Digest::SHA256.new,
      Sone::Application.config.authentication.key,
      message
    )
  end

  setup do
    WebMock.reset!
    @user = users(:user1)
  end

  test "loginは認証サービスへリダイレクトする" do
    get :login
    assert_response :redirect

    uri = URI @response.header['Location']
    params = CGI.parse uri.query

    assert_equal Sone::Application.config.authentication.service_id,
      params['id'].first.to_i

    signature = sign([params['id'].first, params['timestamp'].first, 'authenticate'].join)
    assert_equal params['signature'].first, signature
  end

  test "login_completeは認証情報を取得し、問題なければユーザを生成する" do
    t = Time.now
    params = {
      :id => Sone::Application.config.authentication.service_id,
      :key => 'key',
      :timestamp => t.to_i
    }
    params[:signature] = sign([params[:id], params[:key], params[:timestamp], 'deliver'].join)

    new_user = {
      :profile_id => 0,
      :domain_name => 'www.example.com',
      :screen_name => 'screen_name',
      :nickname => 'nickname',
      :profile_text => 'profile',
      :openid_url => 'http://www.example.com/screen_name',
      :timestamp => Time.now.to_i
    }
    new_user[:signature] = sign(
      [
        Sone::Application.config.authentication.service_id, new_user[:profile_id],
        new_user[:domain_name], new_user[:screen_name], new_user[:nickname],
        new_user[:profile_text], new_user[:openid_url], new_user[:timestamp],
        'retrieved'
      ].join
    )

    WebMock.stub_request(:get, /http:\/\/kitaguchi.yumenosora.net\/profile\/retrieve\?.*/).to_return(
      :body => new_user.to_json
    )
  end

  test "login_completeは既存ユーザをログインさせる" do
    t = Time.now
    params = {
      :id => Sone::Application.config.authentication.service_id,
      :key => 'key',
      :timestamp => t.to_i
    }
    params[:signature] = sign([params[:id], params[:key], params[:timestamp], 'deliver'].join)

    user_data = {
      :profile_id => @user.kitaguchi_profile_id,
      :domain_name => @user.domain_name,
      :screen_name => @user.screen_name,
      :nickname => @user.nickname,
      :profile_text => @user.profile_text,
      :openid_url => 'http://example.com/screen_name'
    }
    user_data[:signature] = sign(
      [
        Sone::Application.config.authentication.service_id, user_data[:profile_id],
        user_data[:domain_name], user_data[:screen_name], user_data[:nickname],
        user_data[:profile_text], user_data[:openid_url], user_data[:timestamp],
        'retrieved'
      ].join
    )
    WebMock.stub_request(:get, /#{Sone::Application.config.authentication.entry_point}\/retrieve\?.*/).to_return(
      :body => user_data.to_json
    )

    assert_no_difference  'User.count' do
      get :login_complete, params
    end
    assert_redirected_to :controller => :users, :action => :show, :domain_name => @user.domain_name, :screen_name => @user.screen_name
    assert_not_nil assigns(:user)
    assert_equal @user.id, session[:user_id]

    WebMock.reset!
  end

  test "login_completeに不正な署名が来たら蹴る" do
    t = Time.now
    params = {
      :id => Sone::Application.config.authentication.service_id,
      :key => 'key',
      :timestamp => t.to_i,
      :signature => 'invalid'
    }

    get :login_complete, params
    assert_response :forbidden
  end

  test "login_completeは引き渡された認証情報が不正なら蹴る" do
    t = Time.now
    params = {
      :id => Sone::Application.config.authentication.service_id,
      :key => 'key',
      :timestamp => t.to_i
    }
    params[:signature] = sign([params[:id], params[:key], params[:timestamp], 'deliver'].join)

    new_user = {
      :profile_id => 0,
      :domain_name => 'www.example.com',
      :screen_name => 'screen_name',
      :nickname => 'nickname',
      :profile_text => 'profile',
      :openid_url => 'http://www.example.com/screen_name',
      :timestamp => Time.now.to_i
    }
    new_user[:signature] = 'invalid signature'

    WebMock.stub_request(:get, /#{Sone::Application.config.authentication.entry_point}\/retrieve\?.*/).to_return(
      :body => new_user.to_json
    )

    assert_no_difference  'User.count' do
      get :login_complete, params
    end
    assert_response :forbidden

    WebMock.reset!
  end

  test "logoutはセッションのログイン情報を消し、認証サービスからもログアウトさせる" do
    get :logout, {}, {:user_id => @user.id}
    assert_response :redirect
    assert @response.header['Location'] =~ /logout/
  end

  test "updateは署名が正当ならその内容でuserを更新する(Kitugachi認証サービスからのPOST)" do
    params = {
      'id' => Sone::Application.config.authentication.service_id,
      'profile_id' => @user.kitaguchi_profile_id,
      'nickname' => 'new nickname',
      'profile_text' => 'new profile text',
      'timestamp' => Time.now.to_i
    }
    message = [params['id'], params['profile_id'], params['nickname'], params['profile_text'], params['timestamp'], 'update'].join
    params['signature'] = sign(message)

    post :update, params

    assert_response :success
    assert_not_nil assigns(:user)
    assert_equal 'new nickname', assigns(:user).nickname
  end

  test "updateは署名が不正なら蹴る(Kitugachi認証サービスからのPOST)" do
    params = {
      'id' => Sone::Application.config.authentication.service_id,
      'profile_id' => @user.kitaguchi_profile_id,
      'nickname' => 'new nickname',
      'profile_text' => 'new profile text',
      'timestamp' => Time.now.to_i,
      'signature' => 'invalid'
    }

    post :update, params

    assert_response :forbidden
  end

  test "セッションが有効なら署名チェックせずに更新する(設定画面からのPOST)" do
    params = {:user => {:default_markup => 'hatena'}, :format => :json}
    patch :update, params, {:user_id => @user.id}
    assert_response :success
    assert 'hatena', assigns(:login_user).default_markup
  end

  test "show(format=rss)は公開文書のみを含むvalidなRSSを返す" do
    get :show,
      {:domain_name => @user.domain_name, :screen_name => @user.screen_name, :format => :rss}

    assert_response :success

    assert_nothing_raised RSS::NotWellFormedError do
      rss = RSS::Parser.parse(@response.body)
      assert_not_nil rss

      assert_equal @user.documents.where(:private => false).count, rss.items.size

      titles = @user.documents.where(:private => false).map{|d| d.title}.sort
      assert_equal titles, rss.items.map{|item| item.title }.sort
    end
  end

  test "存在しないユーザを叩いたら404" do
    get :show, :domain_name => 'non-exists', :screen_name => 'non-exists'
    assert_response :missing
  end
end
