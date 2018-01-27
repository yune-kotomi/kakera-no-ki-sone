module DocumentsHelper
  def title(node)
    if node['title'].present?
      node['title']
    else
      if node['body'].present?
        node['body'].split("\n").first
      else
        ''
      end
    end
  end

  def body(node, markup)
    ret = case markup
    when 'plaintext'
      h(node['body']).gsub("\n", '<br>').html_safe

    when 'hatena'
      begin
        parser = Text::Hatena.new(:sectionanchor => "■")
        parser.parse(node['body'])
        parser.html.force_encoding('UTF-8')
      rescue => e
        ExceptionNotifier.notify_exception(e)
        node['body']
      end

    when 'markdown'
      processor = Qiita::Markdown::Processor.new(hostname: request.host_with_port)
      rendered = processor.call(node['body'])
      rendered[:output].to_s
    else
      # fallback
      node['body']
    end

    Sanitize.clean(ret, Sanitize::Config::RELAXED).html_safe
  end
end
