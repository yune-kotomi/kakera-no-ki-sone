class Metadatum < ActiveRecord::Base
  belongs_to :document
  validate :body_validation

  def body
    YAML.load(body_yaml)
  end

  def body=(value)
    self.body_yaml = value.to_yaml
  end

  private
  def body_validation
    unless (body.map{|node| valid_node?(node) }.uniq - [true]).blank?
      errors.add(:body, 'invalid node(s)')
    end
  end

  def valid_node?(target)
    target.keys.sort == ['id', 'data', 'children'].sort &&
      target['data'].class == Hash &&
      (target['children'].map{|c| valid_node?(c) }.uniq - [true]).blank?
  end
end
