module Editor2
  module CommonContent
    def show
      @emit_input_timer.stop
      @emit_input_timer.execute # 滞留しているactionを実行

      dom_element(:display).show
      dom_element(:editor).hide
      apply_body(attributes[:body])

      `history.back()` if ::Editor2::Editor.phone? && `history.state` == 'edit'
    end

    def edit(focus = :title)
      @emit_input_timer.start

      dom_element(:display).hide
      dom_element(:editor).show
      emit(Action.new(
        :operation => :select,
        :target => @id
      ))

      if focus == :title
        dom_element(:title).focus
      else
        dom_element(:body).focus
      end

      %x{ history.pushState('edit', null, '#edit') } if ::Editor2::Editor.phone? && `history.state` == 'contents'
    end

    # 全ての本文を強制更新
    def refresh!
      apply_body(attributes[:body])
      attribute_instances[:children].each{|c| c.refresh! }
    end

    def apply_body(src)
      unless dom_element(:display).css(:display) == 'none'
        html = root.render(src)
        dom_element(:body_display).html = html
      end
    end

    def visible?
      container = root.dom_element(:container)
      min = container.offset.top
      max = min + container.height.to_i
      d = dom_element(:display)

      min < d.offset.top && d.offset.top + d.outer_height < max
    end
  end
end
