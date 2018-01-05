class UsersController < ApplicationController
  protect_from_forgery :except => :update

  def show
    @user = User.where(
      :domain_name => params[:domain_name],
      :screen_name => params[:screen_name]
    ).first

    if @user.present?
      @documents = @user.documents.where(:public => true).page(params[:page])
    else
      missing
    end
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
    session.delete(:user_id)

    redirect_to Sone::Application.config.authentication.logout
  end

  def update
    if @login_user.present? && verify_authenticity_token.nil?
      @login_user.update(params[:user].permit(:default_markup))
      render :plain => ({:status => 'ok'}).to_json
    else
      data = Sone::Application.config.authentication.updated_profile(params[:token])
      @user = User.where(:kitaguchi_profile_id => data['profile_id']).first
      if @user.present?
        @user.update_attributes(
          :nickname => data['nickname'],
          :profile_text => data['profile_text'],
          :profile_image => data['profile_image']
         )
      end
      render :plain => "success"
    end
  rescue Hotarugaike::Profile::Client::InvalidProfileExchangeError
    forbidden
  end

  def authorize
    redirect_to authorizer.get_authorization_url(:login_hint => session.id, :request => request)
  end

  def authorize_callback
    redirect_to session[:redirect_to]
    c, _ = authorizer.handle_auth_callback(session.id, request)
    token = GoogleToken.where(:token_id => session.id).first

    reset_session
    token.update_attribute(:token_id, session.id)
  end

  def authorizer
    client_id = Google::Auth::ClientId.from_hash(Sone::Application.config.google)
    token_store = GoogleToken::TokenStore.new
    scope = [Google::Apis::DriveV3::AUTH_DRIVE_FILE,
      'https://www.googleapis.com/auth/drive.install']
    Google::Auth::WebUserAuthorizer.new(client_id, scope, token_store, url_for(:action => 'authorize_callback', :only_path => true))
  end
end
