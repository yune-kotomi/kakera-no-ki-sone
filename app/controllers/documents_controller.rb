class DocumentsController < ApplicationController
  before_action :set_token
  before_action :login_required, :except => [:show, :demo]

  # GET /documents
  # GET /documents.json
  def index
    @documents = @login_user.documents.
      order("content_updated_at desc").
      page(params[:page])
    @remainings = @login_user.documents.where('google_document_id is null').count
  end

  def authorize
    session[:redirect_to] = url_for(:action => :index)
    redirect_to :controller => '/users', :action => :authorize
  end

  def migrate
    unless @login_user.migration_started
      @login_user.documents.each do |document|
        DocumentMigrationJob.perform_later(
          document_id: document.id,
          token: @token,
          host: "#{request.protocol}#{request.host_with_port}"
        ) unless document.google_document_id
      end
      @login_user.update_attribute(:migration_started, true)
    end

    redirect_to :action => :index
  end

  # GET /documents/1
  # GET /documents/1.json
  def show
    render :status => 404
  end

  private
    def set_token
      @token = GoogleToken.where(:token_id => session.id).first
      true
    end
end
