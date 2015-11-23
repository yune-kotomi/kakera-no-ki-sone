require 'test_helper'

class DocumentTest < ActiveSupport::TestCase
  setup do
    @document1 = documents(:document1)
    @document2 = documents(:document2)
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
end
