require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "default_markupはplaintext, hatena, markdownの三種のみ" do
    user = User.new
    ['plaintext', 'hatena', 'markdown'].each do |m|
      user.default_markup = m
      assert user.valid?
    end

    user.default_markup = 'hoge'
    assert !user.valid?
  end
end
