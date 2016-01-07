module Editor
  module View
    class TagCheckBox < Juso::View::Base
      template <<-EOS
        <li class="tag">
          <label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect">
            <input type="checkbox" class="mdl-checkbox__input">
            <span class="mdl-checkbox__label">{{>value}}</span>
          </label>
        </li>
      EOS

      element :value, :selector => 'label'
      element :checked, :selector => 'input[type="checkbox"]', :default => false
    end

    # タグ指定UI
    # チェックを入れたタグでノードをハイライト
    class Tags < Juso::View::Base
      template <<-EOS
        <div>
          <div class="mdl-typography--subhead tag-list-title">タグ</div>
          <div class="editor-view-tags">
            <ul></ul>
          </div>
          <hr>
        </div>
      EOS

      element :tag_list, :selector => 'ul', :type => TagCheckBox, :default => []
      attribute :selected_tags, :default => []

      def initialize(data = {}, parent = nil)
        super
        self.tags = data[:tags]
        observe(:tag_list) do |list|
          if list.size == 0
            dom_element.hide
          else
            dom_element.show
          end
        end.call(tag_list)
      end

      def tags=(value)
        self.tag_list = value.map do |v|
          tag = tag_list.find{|e| e.value == v }

          if tag.nil?
            tag = TagCheckBox.new(:value => v)
            tag.observe(:checked) do
              if tag.checked
                self.selected_tags = [selected_tags, tag.value].flatten
              else
                self.selected_tags = selected_tags.reject{|t| t == tag.value }
              end
            end
          end

          tag
        end
      end
    end
  end
end
