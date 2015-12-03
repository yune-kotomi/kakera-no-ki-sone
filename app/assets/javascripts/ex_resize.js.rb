class Element
  def ex_resize(&block)
    %x{
      self.exResize(function(){
        #{block.call if block_given?}
      })
    }
  end
end
