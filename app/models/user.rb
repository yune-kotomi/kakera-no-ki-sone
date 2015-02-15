class User < ActiveRecord::Base
  has_many :documents
  validates :default_markup, :inclusion => ['plaintext', 'hatena', 'markdown']
end
