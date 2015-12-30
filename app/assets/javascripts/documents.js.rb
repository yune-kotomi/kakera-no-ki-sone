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
end
