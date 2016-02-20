def init_footer_and_fab
  # 画面が大きい場合のみフッタを固定
  moving_footer = Element.find('main>footer')
  fixed_footer = Element.find('.mdl-layout>footer')
  page_content = Element.find('.page-content')
  main = Element.find('main')
  fab = Element.find('.right-bottom-fab')
  height = `$(window).innerHeight()`

  unless Element.find('body.welcome').empty?
    moving_footer.show
    return
  end

  if height > 667
    moving_footer.remove
    fixed_footer.ex_resize do
      bottom = fixed_footer.outer_height + 16
      fab.css('bottom', "#{bottom}px")
    end.call
  else
    if page_content.outer_height > height - Element.find('header').outer_height
      fixed_footer.remove
      moving_footer.show
      fab.css('bottom', "16px")
      main.on(:scroll) do |e|
        bottom = main.scroll_top + main.outer_height - page_content.outer_height
        if bottom >= 0
          # FAB移動
          fab.css('bottom', "#{bottom + 16}px")
        else
          fab.css('bottom', '16px')
        end
      end
    else
      moving_footer.remove
      fixed_footer.ex_resize do
        bottom = fixed_footer.outer_height + 16
        fab.css('bottom', "#{bottom}px")
      end.call
    end
  end unless fixed_footer.empty?
end

Document.ready? do
  init_footer_and_fab

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
