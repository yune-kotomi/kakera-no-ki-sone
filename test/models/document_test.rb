require 'test_helper'

class DocumentTest < ActiveSupport::TestCase
  setup do
    @document1 = documents(:document1)
    @document2 = documents(:document2)
    @document5 = documents(:document5)

    @orig_timestamp = @document2.content_updated_at.clone
  end

  test "markupはplaintext, hatena, markdownの三種のみ" do
    document = Document.new
    ['plaintext', 'hatena', 'markdown'].each do |m|
      document.markup = m
      assert document.valid?
    end

    document.markup = 'hoge'
    assert !document.valid?
  end

  test "#bodyの構造が正しければ保存可能" do
    @document1.body = @document2.body
    assert @document1.valid?
  end

  test "#bodyが空配列の場合保存可能" do
    @document2.body = []
    assert @document2.valid?
  end

  test "#bodyの要素に欠落したキーがある場合保存できない" do
    @document1.body = [{'title' => 'title', 'body' => 'body', 'children' => 'children'}]
    assert !@document1.valid?
  end

  test '新規作成できる' do
    document = Document.new
    assert_nothing_raised do
      document.save
    end
  end

  test '新規作成したのが更新できる' do
    document = Document.new
    document.save
    assert_nothing_raised do
      document.update_attribute(:body, @document2.body)
    end
  end

  test 'title変更でcontent_updated_atを更新' do
    @document2.update_attribute(:title, 'new')
    assert_not_equal @orig_timestamp, @document2.content_updated_at
  end

  test 'description変更でcontent_updated_atを更新' do
    @document2.update_attribute(:description, 'new')
    assert_not_equal @orig_timestamp, @document2.content_updated_at
  end

  test 'Leaf#title変更でcontent_updated_atを更新' do
    body = @document2.body
    body.first['title'] = 'new'
    @document2.update_attribute(:body, body)
    assert_not_equal @orig_timestamp, @document2.content_updated_at
  end

  test 'Leaf#content変更でcontent_updated_atを更新' do
    body = @document2.body
    body.first['body'] = 'new'
    @document2.update_attribute(:body, body)
    assert_not_equal @orig_timestamp, @document2.content_updated_at
  end

  test 'Leaf追加でcontent_updated_atを更新' do
    body = @document2.body
    body.push(body.first.clone)
    @document2.update_attribute(:body, body)
    assert_not_equal @orig_timestamp, @document2.content_updated_at
  end

  test 'tag変更でcontent_updated_atを更新' do
    body = @document2.body
    body.first['metadatum'] = {'tags' => ['tag1']}
    @document2.update_attribute(:body, body)
    assert_not_equal @orig_timestamp, @document2.content_updated_at
  end

  test '開閉状態の変更はタイムスタンプに影響しない' do
    body = @document2.body
    body.first['metadatum'] = {'open' => false}
    assert_no_difference('DocumentHistory.count') do
      @document2.update_attribute(:body, body)
    end
    assert_equal @orig_timestamp, @document2.content_updated_at
  end

  test '変更で一つhistoryを生成' do
    assert_difference('DocumentHistory.count') do
      @document2.update_attribute(:title, 'new')
    end

    history = @document2.document_histories.first
    assert_equal 'new', history.title
    assert_equal @document2.description, history.description
    assert_equal @document2.body, history.body
  end

  # test '全文検索' do
  #   actual = Document.fts('日本語 タイトル').order('id')
  #   assert_equal [documents(:document1), documents(:document4)].sort{|a, b| a.id <=> b.id }, actual
  # end

  test 'パスワードなし' do
    assert @document1.password.nil?
  end

  test 'パスワードの比較' do
    assert @document5.password == 'password'
    assert @document5.password != 'password2'
  end

  test 'パスワードの設定' do
    @document1.password = 'password'
    assert_equal BCrypt::Password, @document1.password.class
  end

  test 'nilでパスワード削除' do
    @document1.password = nil
    assert @document1.password.nil?
  end

  test '空文字列でパスワード削除' do
    @document1.password = ''
    assert @document1.password.nil?
  end

  test '階層付きテキストがインポートできる' do
    src = open("#{Rails.root}/test/fixtures/structured_text_1root.txt").read
    @document = Document.load(src)

    assert_equal '.top level', @document.title
    assert_equal "body 1\n.body 1\n", @document.description

    assert_equal '1-1-1', @document.body[0]['children'][0]['children'][0]['title']
    assert_equal "body 1-1-1\n", @document.body[0]['children'][0]['children'][0]['body']
    assert_equal '2', @document.body[1]['title']
    assert_equal '2-1', @document.body[1]['children'][0]['title']
    assert_equal '3', @document.body[2]['title']
    assert_equal '3-1', @document.body[2]['children'][0]['title']
    assert_equal '3-2', @document.body[2]['children'][1]['title']
  end

  test 'トップレベルノードが複数ある階層付きテキストがインポートできる' do
    src = open("#{Rails.root}/test/fixtures/structured_text_noroot.txt").read
    @document = Document.load(src)

    assert_equal '', @document.title
    assert_equal "", @document.description

    assert_equal 'Aタイトル', @document.body[0]['children'][0]['children'][0]['title']

    assert_equal '.Bタイトル', @document.body[1]['title']

    assert_equal 'Cタイトル', @document.body[1]['children'][0]['children'][0]['children'][0]['title']
  end

  test '階層付きテキストに変換できる' do
    actual = @document2.to_structured_text
    expected = open("#{Rails.root}/test/fixtures/structured_text_document2.txt").read.strip
    assert_equal expected, actual
  end
end
