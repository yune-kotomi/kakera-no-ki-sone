Document.ready? do
  unless Element.find('#document-editor').empty?
    Element.find('footer').remove
    Element.find('.right-bottom-fab').css('bottom', '16px')

    editor = Editor2::Editor.new
    Editor2::Loader::Dom.new.load do |doc|
      editor.dispatcher.dispatch(
        Editor2::Action.new(:operation => :load, :payload => doc)
      )
    end

    unless Element.find('#document-demo-mode').value == 'true'
      writer = Editor2::HostedWriter.new(editor.store.stored_document, editor)
      writer.dispatcher = editor.dispatcher
      editor.store.subscribers.push(writer)

      # ウィンドウフォーカス監視
      last_blured = Time.now
      loader = Editor2::Loader::Xhr.new
      Window.on('blur') { last_blured = Time.now }
      Window.on('focus') do
        if Time.now - last_blured > 5 * 60
          # フォーカスが5分以上外れていた場合、現在のバージョンを確認する
          loader.load(editor.store.id, editor.store.version) do |doc|
            # 指定したバージョンとサーバ上のものが異なる場合のみyieldされる
            editor.dispatcher.dispatch(
              Editor2::Action.new(:operation => :load, :payload => doc)
            )
          end
        end
      end
    end
  end
end
