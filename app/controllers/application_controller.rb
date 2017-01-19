class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :retrieve_login_user

  def retrieve_login_user
    @login_user = User.find(session[:user_id]) if session[:user_id].present?
  rescue
    session[:user_id] = nil
  end

  def login_required
    forbidden if @login_user.blank?
  end

  def missing
    render :plain => 'Not Found', :status => 404
  end

  def forbidden
    render :plain => 'Forbidden', :status => 403
  end

  def bad_request
    render :plain => 'Bad Request', :status => 400
  end

  def offset
    offset = 0
    if params[:page].present?
      offset = (params[:page].to_i - 1) * 40
    end

    offset
  end
end
