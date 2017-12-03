module Editor2
  class HostedWriter
    def initialize(editor, interval = 5)
      @editor = editor
      @save = false
      @sent_data = current_document
      @timer =
        Timer::Timer.new(interval) do
          transmit if @save
        end
      @timer.start
    end

    def write
      unless current_document == @sent_data
        @save = true
        @editor.indicate_save(:on)
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

        HTTP.patch("/documents/#{@editor.store.document.id}.json", :payload => {'document' => data}) do |request|
          if request.ok?
            @save = false
            @sent_data = data
            @editor.indicate_save(:off)
          else
          end
        end
      end
    end

    def current_document
      doc = @editor.store.stored_document
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
