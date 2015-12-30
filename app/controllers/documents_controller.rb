class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  before_filter :login_required, :except => [:show]
  before_filter :owner_required, :except => [:index, :show, :create]

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
        end
      else
        forbidden
      end
    end
  end

  # GET /documents/1/edit
  def edit
  end

  # POST /documents
  # POST /documents.json
  def create
    @document = @login_user.documents.build(:markup => @login_user.default_markup)

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
      if @document.update(document_params.update(:body => JSON.parse(document_params[:body] || '[]')))
        format.html { redirect_to @document, notice: 'Document was successfully updated.' }
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
