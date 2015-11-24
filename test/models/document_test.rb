require 'test_helper'

class DocumentTest < ActiveSupport::TestCase
  setup do
    @document1 = documents(:document1)
    @document2 = documents(:document2)

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
    @document2.update_attribute(:body, body)
    assert_equal @orig_timestamp, @document2.content_updated_at
  end
end
