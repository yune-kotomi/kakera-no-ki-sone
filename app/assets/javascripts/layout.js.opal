Document.ready? do
  # 右下のFAB
  footer = Element.find('footer')
  footer.ex_resize do
    bottom = footer.outer_height + 16
    Element.find('.right-bottom-fab').css('bottom', "#{bottom}px")
  end

   # 設定ダイアログ
   config_dialog = Element.find('#config-dialog')
   Element.find('nav a.config').on('click') do
     config_dialog.effect(:fade_in)
     Element.find('.mdl-layout__drawer,.mdl-layout__obfuscator').remove_class('is-visible')
     false
   end

   config_dialog.find('button.close').on(:click) do
     config_dialog.effect(:fade_out)
   end
end
