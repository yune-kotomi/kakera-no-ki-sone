module Drive
  class DocumentsController < ApplicationController
    def show
      @document = Drive::Document.find(params[:id], token)

      if params[:version] && @document.body['version'].to_s == params[:version].to_s
        render :plain => 'not modified', :status => 304
      end
    end

    def new
      state = JSON.parse(params[:state])
      @document = Drive::Document.new(:parent => state['folderId'])
      @document.save(token)

      redirect_to :action => :show, :id => @document.id
    end

    def update
      @document = Drive::Document.find(params[:id], token)

      if @document.writable?
        respond_to do |format|
          if @document.body['version'] == document_params[:version].to_i
            @document.body =
            {
              'title' => document_params[:title],
              'body' => document_params[:description],
              'children' => JSON.parse(document_params[:body]),
              'markup' => document_params[:markup]
            }
            @document.save(token)
            format.json { render :json => {:version => @document.body['version']} }
          else
            # 指定されたバージョンが現状と異なる場合は409で応答
            format.json { render 'show.json.erb', status: 409 }
          end
        end
      else
        forbidden
      end
    end

    class DriveNotAuthorizedError < StandardError; end

    rescue_from DriveNotAuthorizedError, Google::Apis::AuthorizationError, Signet::AuthorizationError do |e|
      respond_to do |format|
        format.html do
          session[:redirect_to] = request.fullpath
          redirect_to :controller => '/users', :action => :authorize
        end

        format.json { render json: {}, status: 401 }
      end
    end

    rescue_from Google::Apis::ClientError do |e|
      case e.status_code
      when 403
        forbidden
      when 404
        missing
      end
    end

    private
    def document_params
      params.require(:document).permit(:title, :description, :body, :public, :archived, :markup, :version)
    end

    def token
      token = GoogleToken.where(:token_id => session.id).first
      raise DriveNotAuthorizedError.new if token.nil?
      token
    end
  end
end
