Document.ready? do
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

  import_dialog = Element.find('#import-dialog')
  if import_dialog
    file_input = import_dialog.find('input[type="file"]')
    display = import_dialog.find('.filename-display')
    file_input.on('change') do |e|
      display.value = `#{e.current_target.get(0)}.files[0].name`
    end
  end
end
