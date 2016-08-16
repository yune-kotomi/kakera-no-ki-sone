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
      dialog = Element.find('#dialog-confirm')
      dialog.find('.mdl-dialog__title').html = @title
      dialog.find('.mdl-dialog__content').html = @message

      dialog.find('.mdl-button.ok').tap do |b|
        b.html = @ok_label
        b.off(:click)
        b.on(:click) do
          @ok.call if @ok
          %x{ #{dialog}.get(0).close() }
        end
      end

      dialog.find('.mdl-button.cancel').tap do |b|
        b.html = @cancel_label
        b.off(:click)
        b.on(:click) do
          @cancel.call if @cancel
          %x{ #{dialog}.get(0).close() }
        end
      end

      %x{
        #{dialog}.get(0).showModal()
      }
    end
  end
end
