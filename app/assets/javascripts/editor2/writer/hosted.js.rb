module Editor2
  class HostedWriter
    def initialize(editor, interval = 5000)
      @editor = editor
      @save = false
      @sent_data = editor.store.stored_document
      `setInterval(function(){#{save_loop}}, #{interval})`
    end

    def write
      @save = true
      @editor.indicate_save(:on)
    end

    private
    # 保存ループの処理実体
    def save_loop
      transmit if @save
    end

    # PATCH /documents/ID.jsonを発行する
    def transmit
      data = @editor.store.stored_document
      data = {
        :title => data[:title],
        :description => data[:body],
        :body => data[:children].to_json,
        :public => (data[:published] == true),
        :markup => data[:markup]
      }

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
  end
end
