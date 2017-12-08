Document.ready? do
  unless Element.find('#document-editor').empty?
    Element.find('footer').remove
    Element.find('.right-bottom-fab').css('bottom', '16px')

    editor = Editor2::Editor.new
    Editor2::DomLoader.new.load do |doc|
      editor.dispatcher.dispatch(
        Editor2::Action.new(:operation => :load, :payload => doc)
      )
    end

    unless Element.find('#document-demo-mode').value == 'true'
      writer = Editor2::HostedWriter.new(editor.store.stored_document, editor)
      writer.dispatcher = editor.dispatcher
      editor.store.subscribers.push(writer)
    end
  end
end
