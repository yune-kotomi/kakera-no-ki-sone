class DocumentsController < ApplicationController
  before_action :set_document, :except => [:index, :create, :demo]

  before_filter :login_required, :except => [:show, :demo]
  before_filter :owner_required, :except => [:index, :show, :create, :demo]

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
      if @document.password
        if request.post? && @document.password != params[:password]
          flash[:notice] = 'パスワードが違います'
          redirect_to @document
          return
        end
      else
        forbidden
        return
      end
    end

    if params[:type] == 'structured_text'
      send_data(@document.to_structured_text, :type => 'text/plain', :filename => "#{@document.title}.txt")
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
      if @document.update(document_params)
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
        format.json { render :json => true }
      else
        format.html { render :edit }
        format.json { render json: @document.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /documents/1
  # DELETE /documents/1.json
  def destroy
    @document.destroy
    respond_to do |format|
      format.html { redirect_to documents_path }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_document
      @document = Document.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def document_params
      params.require(:document).permit(:title, :description, :body, :public, :archived, :password, :markup)
    end

    def owner_required
      forbidden unless @document.user == @login_user
    end
end
