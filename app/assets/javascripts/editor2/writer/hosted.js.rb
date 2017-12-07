module Editor2
  class HostedWriter
    def initialize(doc, editor, interval = 5)
      @editor = editor
      @save = false
      @in_progress = false
      @current_doc = doc
      @sent_data = current_document
      @before_save_actions = [] # 未保存のアクション
      @pending_actions = [] # 保存中の文書に適用済みのアクション
      @timer =
        Timer::Timer.new(interval) do
          transmit if @save && !@in_progress
        end
      @timer.start
    end

    def apply(doc, actions)
      @current_doc = doc
      unless current_document == @sent_data
        @save = true
        @editor.indicate_save(:on)
        @before_save_actions.push(actions).flatten!
      end
    end

    private
    # PATCH /documents/ID.jsonを発行する
    def transmit
      data = current_document

      if data == @sent_data
        # 内容が更新されていなければ保存しない
        @editor.indicate_save(:off)
      else
        @editor.indicate_save(:progress)
        @in_progress = true
        @pending_actions.push(@before_save_actions).flatten!
        @before_save_actions.clear

        HTTP.patch("/documents/#{@current_doc[:id]}.json", :payload => {'document' => data}) do |request|
          @in_progress = false
          if request.ok?
            @sent_data = data
            @pending_actions.clear
            if current_document == @sent_data
              @save = false
              @editor.indicate_save(:off)
            end
          else
          end
        end
      end
    end

    def current_document
      doc = @current_doc

      {
        :title => doc[:title],
        :description => doc[:body],
        :body => doc[:children].to_json,
        :public => (doc[:published] == true),
        :markup => doc[:markup]
      }
    end
  end
end
