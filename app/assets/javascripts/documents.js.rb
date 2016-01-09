Document.ready? do
  # 文書一覧
  # 設定ダイアログ
  user_config = Element.find('.user-config')
  unless user_config.empty?
    markup_selector = user_config.find('[name="markup"]')
    markup_selector.on(:click) do |e|
      markup = markup_selector.to_a.find{|e| e.prop('checked') }.value

      payload = {:user => {:default_markup => markup}}
      HTTP.patch("/users/update.json", :payload => payload) do |request|
        unless request.ok?
          puts 'user update error'
        end
      end
    end
  end

  # インポートダイアログ
  import_dialog = Element.find('#import-dialog')
  unless import_dialog.empty?
    file_input = import_dialog.find('input[type="file"]')
    display = import_dialog.find('.filename-display')
    file_input.on('change') do |e|
      display.value = `#{e.current_target.get(0)}.files[0].name`
    end
  end

  # 編集履歴
  # 履歴のラジオボタン処理
  history_list = Element.find('ol.histories')
  unless history_list.empty?
    from_buttons = history_list.find('input[name="diff_from"]')
    to_buttons = history_list.find('input[name="diff_to"]')
    histories = from_buttons.to_a.map(&:value)

    history_list.find('input').on(:click) do |e|

    end

    from_buttons.on(:click) do |e|
      r = e.current_target
      split_point = histories.index(r.value)
      to_buttons.to_a.each_with_index do |b, i|
        if i < split_point
          b.parent.show
        else
          b.parent.hide
        end
      end
    end

    to_buttons.on(:click) do |e|
      r = e.current_target
      split_point = histories.index(r.value)
      from_buttons.to_a.each_with_index do |b, i|
        if i > split_point
          b.parent.show
        else
          b.parent.hide
        end
      end
    end

    from_buttons.to_a[1].trigger(:click)
    to_buttons.to_a.first.trigger(:click)
  end
end
