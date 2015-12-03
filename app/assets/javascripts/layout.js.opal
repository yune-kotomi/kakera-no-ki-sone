Document.ready? do
  # 右下のFAB
  footer = Element.find('footer')
  footer.ex_resize do
    bottom = footer.outer_height + 16
    Element.find('.right-bottom-fab').css('bottom', "#{bottom}px")
  end
end
