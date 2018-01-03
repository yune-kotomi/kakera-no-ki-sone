class DocumentsController < ApplicationController
  before_action :set_document, :except => [:index, :create, :demo, :drive_new]

  before_action :check_login, :except => [:show, :demo, :drive_new, :drive_show]
  before_action :owner_required, :except => [:index, :show, :create, :demo, :drive_new]

  # GET /documents
  # GET /documents.json
  def index
    @documents = @login_user.documents.
      order("content_updated_at desc").
      page(params[:page])

    if params[:keywords].present?
      @documents = @documents.fts(params[:keywords])
    else
      @documents = @documents.where(:archived => params[:archived].present?)
    end
  end

  # GET /documents/1
  # GET /documents/1.json
  def show
    if !@document.public && @document.user != @login_user
      forbidden
      return
    end

    if params[:type] == 'structured_text'
      send_data(@document.to_structured_text, :type => 'text/plain', :filename => "#{@document.title}.txt")
    end

    if params[:version] && @document.version.to_s == params[:version].to_s
      render :plain => 'not modified', :status => 304
    end
  end

  def histories
  end

  def diff
    from = @document.document_histories.find(params[:from])
    @from = "#{from.title}\n#{from.description}\n" +
      render_to_string(:partial => 'documents/show/content.text.erb',
        :collection => from.body,
        :formats => [:text],
        :locals => {:parent_index => ''})

    to = @document.document_histories.find(params[:to])
    @to = "#{to.title}\n#{to.description}\n" +
      render_to_string(:partial => 'documents/show/content.text.erb',
        :collection => to.body,
        :formats => [:text],
        :locals => {:parent_index => ''})

    render :content_type => "text/html"
  end

  # GET /documents/1/edit
  def edit
  end

  def demo
    @document = Document.find(Sone::Application.config.demo_document_id)
    render :edit
  end

  # POST /documents
  # POST /documents.json
  def create
    @document = @login_user.documents.build(:markup => @login_user.default_markup)

    if params[:template]
      begin
        template = @login_user.documents.find(params[:template])
        @document = template.dup
        @document.title = "#{@document.title} のコピー"
      rescue ActiveRecord::RecordNotFound
        redirect_to documents_path
        return
      end
    elsif params[:import]
      src = params[:import].read
      encode = CharlockHolmes::EncodingDetector.detect(src)[:encoding]
      @document = Document.load(src.encode('UTF-8', encode))
      @document.user = @login_user
      @document.markup = @login_user.default_markup
      @document.title = params[:import].original_filename if @document.title.blank?
    end

    respond_to do |format|
      if @document.save
        format.html { redirect_to edit_document_path(@document), notice: 'Document was successfully created.' }
        format.json { render :show, status: :created, location: @document }
      else
        format.html { render :new }
        format.json { render json: @document.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /documents/1
  # PATCH/PUT /documents/1.json
  def update
    respond_to do |format|
      if document_params[:version].nil? || @document.version == document_params[:version].to_i
        begin
          # バージョンが指定されていない(互換性保持用)か指定されたバージョンが現状と
          # 合致する場合のみ更新を許容する
          if save_document(document_params)
            format.html do
              case document_params[:archived].to_s
              when 'true'
                redirect_to documents_path
              when 'false'
                redirect_to documents_path(:archived => true)
              else
                redirect_to @document, notice: 'Document was successfully updated.'
              end
            end
            format.json { render :json => {:version => @document.version} }
          else
            format.html { render :edit }
            format.json { render json: @document.errors, status: :unprocessable_entity }
          end
        rescue Google::Apis::AuthorizationError => e
          format.json { render json: {}, status: 401 }
        end
      else
        # 指定されたバージョンが現状と異なる場合は409で応答
        format.json { render 'show.json.erb', status: 409 }
      end
    end
  end

  # DELETE /documents/1
  # DELETE /documents/1.json
  def destroy
    @document.destroy
    back_to =
      if @document.archived
        documents_path(:archived => true)
      else
        documents_path
      end

    respond_to do |format|
      format.html { redirect_to back_to }
      format.json { head :no_content }
    end
  end

  def drive_new
    state = JSON.parse(params[:state])
    metadata = {
      :name => '新しい文書.html',
      :parents => [state['folderId']]
    }
    ret =
      drive_service.create_file(
        metadata,
        :upload_source => StringIO.new(''),
        :content_type => 'text/html'
      )
    redirect_to :action => :drive_show, :id => ret.id
  end

  def drive_show
    @document = drive_document
    render :action => :edit
  rescue => e
    session[:redirect_to] = url_for
    redirect_to :controller => :users, :action => :authorize
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_document
      @document = Document.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def document_params
      params.require(:document).permit(:title, :description, :body, :public, :archived, :markup, :version)
    end

    def owner_required
      forbidden unless @document.user == @login_user
    end

    def check_login
      if @document.nil? || @document.drive_id.nil?
        login_required
      else
        true
      end
    end

    def drive_service
      token = GoogleToken.where(:token_id => session.id).first
      if token.nil?
        raise DriveNotAuthorizedError.new
      else
        drive = Google::Apis::DriveV3::DriveService.new
        drive.authorization = token.credential
        drive
      end
    end

    def drive_document
      drive = drive_service

      begin
        drive_file = drive.get_file(params[:id])
        document = Document.where(:drive_id => params[:id]).first
        if document.nil?
          document = Document.new(:drive_id => params[:id])
          document.save
        end

        document
      rescue => e
        raise DriveNotAuthorizedError.new
      end
    end

    def save_document(document_params)
      Document.transaction do
        save_result = @document.update(document_params)
        if @document.drive_id.nil?
          save_result
        else
          drive = drive_service
          html = render_to_string :partial => 'drive_document.html'
          begin
            ret =
              drive.update_file(
                @document.drive_id,
                {:name => "#{@document.title}.html"},
                :upload_source => StringIO.new(html))
          rescue Google::Apis::ClientError => e
            case e.status_code
            when 404
              ret =
                drive_service.create_file(
                  {:name => "#{@document.title}.html"},
                  :upload_source => StringIO.new(html),
                  :content_type => 'text/html'
                )
              @document.update_attribute(:drive_id, ret.id)
            end
          end
          true
        end
      end
    rescue DriveNotAuthorizedError
      false
    end

    class DriveNotAuthorizedError < StandardError; end
end
