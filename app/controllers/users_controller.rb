class UsersController < ApplicationController
  def show
    missing
  end

  def login
    redirect_to Sone::Application.config.authentication.start_authentication
  end

  def login_complete
    begin
      user_data = Sone::Application.config.authentication.retrieve(params[:token])
      @user = User.where(:kitaguchi_profile_id => user_data['profile_id']).first
      if @user.nil?
        @user = User.new(
          :nickname => user_data['nickname'],
          :profile_text => user_data['profile_text'],
          :profile_image => user_data['profile_image']
        )
        @user.kitaguchi_profile_id = user_data['profile_id']
        @user.domain_name = user_data['domain_name']
        @user.screen_name = user_data['screen_name']
        @user.save

      else
        @user.update_attributes(
          :nickname => user_data['nickname'],
          :profile_text => user_data['profile_text'],
          :profile_image => user_data['profile_image']
        )
      end

      session[:user_id] = @user.id
      redirect_to documents_path

    rescue Hotarugaike::Profile::Client::InvalidProfileExchangeError
      flash[:notice] = "ログインできませんでした"
      forbidden
    end
  end

  def logout
    if session.delete(:user_id)
      redirect_to Sone::Application.config.authentication.logout
    else
      reset_session
      redirect_to root_path
    end
  end

  def authorize
    s = [:redirect_to, :user_id].map{|k| [k, session[k]] }.to_h
    reset_session
    s.each{|k, v| session[k] = v }
    redirect_to authorizer.get_authorization_url(:login_hint => session.id, :request => request)
  end

  def authorize_callback
    authorizer.handle_auth_callback(session.id, request)
    if session[:redirect_to]
      redirect_to session.delete(:redirect_to)
    else
      redirect_to :controller => :welcome, :action => :installed
    end
  end

  def authorizer
    client_id = Google::Auth::ClientId.from_hash(Sone::Application.config.google)
    token_store = GoogleToken::TokenStore.new
    scope = [Google::Apis::DriveV3::AUTH_DRIVE_FILE,
      'https://www.googleapis.com/auth/drive.install']
    Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, url_for(:action => 'authorize_callback', :only_path => true))
  end
end
