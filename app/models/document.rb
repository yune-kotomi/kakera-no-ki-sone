class Document < ActiveRecord::Base
  belongs_to :user
  validates :markup, :inclusion => ['plaintext', 'hatena', 'markdown']
  validate :body_validation

  def body_validation
    if body.present? && (body.map{|node| valid_node?(node) }.uniq - [true]).present?
      errors.add(:body, 'invalid node(s)')
    end
  end

  private
  def valid_node?(target)
    target.keys.sort == ['id', 'title', 'body', 'children', 'metadatum'].sort &&
      (target['children'].map{|c| valid_node?(c) }.uniq - [true]).blank?
  end
end
