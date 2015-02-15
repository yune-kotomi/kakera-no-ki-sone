class Document < ActiveRecord::Base
  belongs_to :user
  validates :markup, :inclusion => ['plaintext', 'hatena', 'markdown']
  validate :body_validation

  def body
    YAML.load(body_yaml)
  end

  def body=(value)
    self.body_yaml = value.to_yaml
  end

  def body_validation
    unless (body.map{|node| valid_node?(node) }.uniq - [true]).blank?
      errors.add(:body, 'invalid node(s)')
    end
  end

  private
  def valid_node?(target)
    target.keys.sort == ['id', 'name', 'body', 'children'].sort &&
      (target['children'].map{|c| valid_node?(c) }.uniq - [true]).blank?
  end
end
