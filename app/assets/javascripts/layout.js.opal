Document.ready? do
  # 右下のFAB
  %x{
    $('footer').exResize(function(){
      var bottom = $('footer').outerHeight() + 16;
      $('.right-bottom-fab').css('bottom', bottom + 'px');
    });
  }
end
