class UsersController < ApplicationController
  protect_from_forgery :except => :update

  def show
    @user = User.where(
      :domain_name => params[:domain_name],
      :screen_name => params[:screen_name]
    ).first

    @documents = @user.documents.
      where(:archived => params[:archived].present?).
      order("updated_at desc").
      page(params[:page])

    @documents = @documents.where(:private => false) unless @user == @login_user
  end

  def login
    redirect_to Sone::Application.config.authentication.start_authentication
  end

  def login_complete
    begin
      user_data = Sone::Application.config.authentication.retrieve(params[:key], params[:timestamp], params[:signature])
      @user = User.where(:kitaguchi_profile_id => user_data['profile_id']).first
      if @user.nil?
        @user = User.new(
          :nickname => user_data['nickname'],
          :profile_text => user_data['profile_text']
        )
        @user.kitaguchi_profile_id = user_data['profile_id']
        @user.domain_name = user_data['domain_name']
        @user.screen_name = user_data['screen_name']
        @user.save

      else
        @user.update_attributes(
          :nickname => user_data['nickname'],
          :profile_text => user_data['profile_text']
        )
      end

      session[:user_id] = @user.id
      redirect_to :controller => :users, :action => :show, :domain_name => @user.domain_name, :screen_name => @user.screen_name

    rescue Hotarugaike::Profile::InvalidProfileExchangeError
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
      render :text => ({:status => 'ok'}).to_json
    else
      data = Sone::Application.config.authentication.updated_profile(params)
      @user = User.where(:kitaguchi_profile_id => data['profile_id']).first
      if @user.present?
        @user.update_attributes(
          :nickname => data[:nickname],
          :profile_text => data[:profile_text]
        )
      end
      render :text => "success"
    end
  rescue Hotarugaike::Profile::InvalidProfileExchangeError
    forbidden
  end
end
