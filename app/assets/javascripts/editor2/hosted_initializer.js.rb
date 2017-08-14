Document.ready? do
  unless Element.find('#document-editor').empty?
    Element.find('footer').remove
    Element.find('.right-bottom-fab').css('bottom', '16px')

    loader = Editor2::DomLoader.new
    editor = Editor2::Editor.new(loader)
    editor.load

    unless Element.find('#document-demo-mode').value == 'true'
      editor.writer = Editor2::HostedWriter.new(editor)
    end
  end
end
