Document.ready? do
  # 右下のFAB
  footer = Element.find('footer')
  footer.ex_resize do
    bottom = footer.outer_height + 16
    Element.find('.right-bottom-fab').css('bottom', "#{bottom}px")
  end

   # 設定ダイアログ
   Element.find('nav a.modal-trigger').to_a.each do |trigger|
     modal = Element.find(trigger['data-modal-selector'])

     trigger.on('click') do
       modal.effect(:fade_in)
       Element.find('.mdl-layout__drawer,.mdl-layout__obfuscator').remove_class('is-visible')
       false
     end

     modal.find('button.close').on(:click) do
       modal.effect(:fade_out)
     end
   end
end
