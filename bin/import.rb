def leaves(src)
  src.map do |s|
    {
      'id' => s['id'],
      'body' => s['body'],
      'title' => s['title'],
      'metadatum' => {
        'open' => s['is_open'],
        'tags' => s['tags']
      },
      'children' => leaves(s['children'])
    }
  end
end

def license_leaf(license, nickname)
  t = <<EOS
<div id="license">
  <a rel="license" href="http://creativecommons.org/licenses/#{license}/3.0/deed.ja">
    <img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/#{license}/3.0/88x31.png" />
  </a>
  <br />この
  <span xmlns:dc="http://purl.org/dc/elements/1.1/" href="http://purl.org/dc/dcmitype/Text" rel="dc:type">文書</span>は、
  #{nickname}より
  <a rel="license" href="http://creativecommons.org/licenses/#{license}/3.0/deed.ja">クリエイティブ・コモンズ・ライセンス</a>の下でライセンスされています。
</div>
EOS

  {
    'id' => 'e8598bbd-466d-431d-8ce4-69b78018bb30',
    'body' => t,
    'title' => 'ライセンス',
    'metadatum' => {
      'open' => true,
      'tags' => []
    },
    'children' => []
  }
end

Dir.chdir(ARGV[0]) do
  puts 'users'
  # ユーザ
  (1..Dir.glob('user_*').map{|f|f.split('_').last}.map(&:to_i).sort.last).each do |i|
    user = User.new(:default_markup => 'hatena')
    user.save

    if File.exists?("user_#{i}.json")
      src = JSON.parse(open("user_#{i}.json").read)['user']
      user.update_attributes(
        :domain_name => src['domain_name'],
        :screen_name => src['screen_name'],
        :nickname => src['name'],
        :profile_text => src['profile'],
        :kitaguchi_profile_id => src['kitaguchi_profile_id']
      )
    else
      user.destroy
    end
  end

  puts 'documents'
  # 文書
  (1..Dir.glob('document_*').map{|f|f.split('_').last}.map(&:to_i).sort.last).each do |i|
    document = Document.new(:markup => 'hatena')
    document.save

    if File.exists?("document_#{i}.json")
      src = JSON.parse(open("document_#{i}.json").read)
      begin
        body = src['body']['children']
      rescue => e
        binding.pry
      end

      document.update_columns(
        :title => src['name'].to_s,
        :description => src['excerpt'],
        :body => leaves(body).tap{|l| l.push(license_leaf(src['license'], User.find(src['user_id']).nickname)) if src['license'].present? },
        :public => src['publish'],
        :archived => src['archived'],
        :user_id => src['user_id'],
        :content_updated_at => Time.parse(src['updated_at']),
        :updated_at => Time.parse(src['updated_at']),
        :created_at => Time.parse(src['created_at'])
      )
    else
      document.destroy
    end
  end
end
