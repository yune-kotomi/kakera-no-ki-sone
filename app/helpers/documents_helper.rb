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
      parser = Text::Hatena.new(:sectionanchor => "■")
      parser.parse(node['body'])
      parser.html.force_encoding('UTF-8')

    when 'markdown'
      processor = Qiita::Markdown::Processor.new
      rendered = processor.call(node['body'])
      rendered[:output].to_s
    else
      # fallback
      node['body']
    end

    Sanitize.clean(ret, Sanitize::Config::RELAXED).html_safe
  end

  def password_prompt?(document, login_user)
    if document.public
      false
    else
      if document.user == login_user
        false
      else
        if request.post? && document.password && document.password == params[:password]
          false
        else
          true
        end
      end
    end
  end
end
