class Document < ActiveRecord::Base
  belongs_to :user
  has_many :document_histories,
    -> { order 'created_at desc' },
    :dependent => :destroy

  validates :markup, :inclusion => ['plaintext', 'hatena', 'markdown']
  validate :body_validation
  before_save :update_content_timestamp
  after_save :create_history
  before_create { self.content_updated_at = Time.now }

  scope :fts, -> query {
    sql = ActiveRecord::Base.send(
      :sanitize_sql_array,
      [
        '/*+ IndexScan(documents) */ select id from documents where body @@ ?',
        "query(\"paths\", \"title OR body\") && query(\"string\", \"#{query}\")"
      ]
    )
    ids = ActiveRecord::Base.connection.select_all(sql).map{|r| r['id'] }

    where('title @@ ? OR description @@ ? OR id in (?)', query, query, ids)
  }

  def body_validation
    if body.present? && (body.map{|node| valid_node?(node) }.uniq - [true]).present?
      errors.add(:body, 'invalid node(s)')
    end
  end

  def password
    if bcrypt_password
      BCrypt::Password.new(bcrypt_password)
    else
      nil
    end
  end

  def password=(value)
    if value.present?
      self.bcrypt_password = BCrypt::Password.create(value)
    else
      self.bcrypt_password = nil
    end
  end

  def self.load(src)
    nodes = src.split(/(^\.+)/).reduce([]) do |ret, line|
      if line.match(/\A\.+\z/)
        ret.push(:level => line.size - 1)
      else
        ret.last.update(:body => line) if ret.last
      end

      ret
    end.map{|line| line.update(:body => line[:body].gsub(/^ ./, '.')) }

    nodes.each do |node|
      title, body = node[:body].match(/\A(.*?)\n(.*?)\z/m).to_a.values_at(1,2)
      node[:leaf] = new_leaf(title, body)
    end

    if nodes.select{|n| n[:level] == 0 }.size == 1 && nodes.first[:level] == 0
      # トップレベルノードが単数かつ先頭のものがそれだった場合、
      # title, descriptionをそのノードで賄い他のノードを１段上げる
      title = nodes.first[:leaf]['title']
      description = nodes.first[:leaf]['body']
      nodes.shift
      nodes = nodes.map{|n| n[:level] -= 1; n }
    else
      title = ''
      description = ''
    end

    document = Document.new(:title => title, :description => description, :body => [])

    # 階層が飛んでいるものを修正
    prev_level = 0
    nodes = nodes.map do |node|
      if prev_level + 1 < node[:level]
        dummy = ((prev_level + 1)..(node[:level] - 1)).map{|i|
          {
            :level => i,
            :leaf => new_leaf('', '')
          }
        }
        prev_level = node[:level]
        [dummy, node]
      else
        prev_level = node[:level]
        node
      end
    end.flatten
    if nodes.first && nodes.first[:level] > 0
      nodes.insert(0, {
        :level => 0,
        :leaf => new_leaf('', '')
      })
    end

    nodes.each do |node|
      document.children_of(node[:level]).push(node[:leaf])
    end

    document
  end

  def self.new_leaf(title, body)
    {
      'id' => UUIDTools::UUID.random_create.to_s,
      'title' => title,
      'body' => body,
      'children' => [],
      'metadatum' => {}
    }
  end

  def children_of(level)
    children = body
    level.times do
      children = children.last['children']
    end
    children
  end

  def to_structured_text
    root = {
      'title' => title,
      'body' => description,
      'children' => body
    }

    structured_text_leaf(1, root)
  end

  private
  def valid_node?(target)
    target.keys.sort == ['id', 'title', 'body', 'children', 'metadatum'].sort &&
      (target['children'].map{|c| valid_node?(c) }.uniq - [true]).blank?
  end

  def update_content_timestamp
    self.content_updated_at = Time.now if content_changed?
    true
  end

  def create_history
    if content_changed?
      DocumentHistory.transaction do
        if document_histories.count > 100
          document_histories.last.destroy
        end

        document_histories.create(
          :title => title,
          :description => description,
          :body => body
        )
      end
    end

    true
  end

  def content_changed?
    return true if (['title', 'description'] & changed).present?

    if body_changed?
      node_contents = body_change.map{|b| extract_content(b) }
      return true unless node_contents.first == node_contents.last
    end

    false
  end

  def extract_content(src)
    (src.deep_dup || []).map do |leaf|
      if leaf['metadatum'].present?
        leaf['metadatum'] = leaf['metadatum'].reject{|k, _| ['open'].include?(k) }
      end
      if leaf['children'].present?
        leaf['children'] = extract_content(leaf['children'])
      end

      leaf
    end
  end

  def self.body_fts(query)
  end

  def structured_text_leaf(level, leaf)
    title = leaf['title'].to_s.sub(/\A\./, ' .')
    body = leaf['body'].to_s.gsub(/^\./, ' .')
    text = ['.' * level + title + "\n#{body}"]

    if leaf['children'].present?
      leaf['children'].each do |child|
        text.push(structured_text_leaf(level + 1, child))
      end
    end

    text.join("\n")
  end
end
