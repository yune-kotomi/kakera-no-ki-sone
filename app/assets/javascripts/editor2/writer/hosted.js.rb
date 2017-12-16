module Editor2
  class HostedWriter
    attr_accessor :dispatcher

    def initialize(doc, editor, interval = 5)
      @editor = editor
      @save = false
      @in_progress = false
      @current_doc = doc
      @sent_data = current_document
      @before_save_actions = [] # 未保存のアクション
      @pending_actions = [] # 保存中の文書に適用済みのアクション
      @timer =Timer::Timer.new(interval) { transmit_if_can }
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

        HTTP.patch("/documents/#{@current_doc[:id]}.json", :payload => {'document' => data}) do |response|
          @in_progress = false
          if response.ok?
            version = response.json['version']
            @sent_data = data
            @pending_actions.clear
            if current_document == @sent_data
              @save = false
              @editor.indicate_save(:off)
            end
            # サーバ側と同一バージョンにしておく
            @sent_data['version'] = version

            @dispatcher.dispatch(
              Action.new(
                :operation => :change,
                :payload => {:version => version}
              )
            )
          else
            case response.status_code
            when 409
              # サーバ側とバージョン不一致
              # データ構造の読み替え
              doc = Editor2::Loader::Xhr.response_to_doc(response)
              # 送り返されてきたものに対して現在滞留しているアクションを適用させる
              actions =
                [
                  Action.new(:operation => :load, :payload => doc),
                  @pending_actions
                ].flatten
              @dispatcher.dispatch(*actions)
              transmit_if_can
            else
              raise response
            end
          end
        end
      end
    end

    def transmit_if_can
      transmit if @save && !@in_progress
    end

    def current_document
      doc = @current_doc

      {
        :title => doc[:title],
        :description => doc[:body],
        :body => doc[:children].to_json,
        :public => (doc[:published] == true),
        :markup => doc[:markup],
        :version => doc[:version]
      }
    end
  end
end
