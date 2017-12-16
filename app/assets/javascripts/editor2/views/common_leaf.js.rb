module Editor2
  module CommonLeaf
    def index
      parent.attribute_instances[:children].index(self)
    end

    def root
      parent.root
    end

    def elder_brother
      parent.attribute_instances[:children][index - 1] if index > 0
    end

    def younger_brother
      parent.attribute_instances[:children][index + 1] if index < parent.attribute_instances[:children].size - 1
    end

    # 自分と同じか自分より上の階層で次に位置する葉
    def next_leaf_not_below
      younger_brother || parent.next_leaf_not_below
    end

    # 自分を頂点とした部分木の一番下
    def last_child
      c = attribute_instances[:children].last
      if c
        c.last_child
      else
        self
      end
    end

    def find(id)
      if @id == id
        self
      else
        attribute_instances[:children].
          map{|c1| c1.find(id) }.
          compact.
          first
      end
    end

    def update_chapter_number(attr)
      (attr[:children] || []).each_with_index do |c, i|
        c[:chapter_number] =
          if attr[:chapter_number]
            "#{attr[:chapter_number]}.#{i + 1}"
          else
            i + 1
          end
      end
      attr
    end
  end
end
