class Document < ActiveRecord::Base
  belongs_to :user
  validates :markup, :inclusion => ['plaintext', 'hatena', 'markdown']
  validate :body_validation
  before_save :update_content_timestamp
  before_create { self.content_updated_at = Time.now }

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

  def update_content_timestamp
    self.content_updated_at = Time.now if (['title', 'description'] & changed).present?

    if body_changed?
      node_contents = body_change.map{|b| extract_content(b) }
      self.content_updated_at = Time.now unless node_contents.first == node_contents.last
    end
  end

  def extract_content(src)
    src.map do |leaf|
      if leaf['metadatum'].present?
        leaf['metadatum'] = leaf['metadatum'].reject{|k, _| ['open'].include?(k) }
      end
      if leaf['children'].present?
        leaf['children'] = extract_content(leaf['children'])
      end

      leaf
    end
  end
end
