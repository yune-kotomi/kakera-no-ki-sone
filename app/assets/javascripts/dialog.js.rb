module Dialog
  # YES/NO
  class Confirm
    def initialize(title, message, ok = 'OK', cancel = 'キャンセル')
      @title = title
      @message = message
      @ok_label = ok
      @cancel_label = cancel
      yield(self)

      self
    end

    def ok(&block)
      @ok = block
    end

    def cancel(&block)
      @cancel = block
    end

    def open
      %x{
        if(window.confirm(#{@message})){
          #{@ok.call if @ok};
        }else{
          #{@cancel.call if @cancel};
        }
      }
    end
  end
end
