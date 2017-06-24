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

    main = Element.find('main')
    # モバイルではmainのheightはコンテンツ長となるが
    # PCと同様、画面高さに固定する
    if Editor2::Editor.phone?
      Element.find('body').ex_resize do
        main_height = `$(window).innerHeight()` - Element.find('header').outer_height
        main.css('height', "#{main_height}px")
      end.call
    end

    main.ex_resize do
      height = main.height - 8*2 - 4*2
      editor.tree.dom_element(:container).css('height', "#{height}px")
      editor.contents.dom_element(:container).css('height', "#{height}px")
      editor.adjust_tree_size
    end.call
  end
end
