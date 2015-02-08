class User < ActiveRecord::Base
  validates :default_markup, :inclusion => ['plaintext', 'hatena', 'markdown']
end
