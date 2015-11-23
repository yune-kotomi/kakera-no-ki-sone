module JavascriptTestsView
  def self.execute
    ViewTest.execute
    puts '全テスト通過'
  end

  module ViewTest
    def self.execute
      tree_test
      display_test
      editor_test
      content_test
    end

    def self.tree_test
      children = [
        {:id => '1', :title => '1', :children =>
          [{:id => '1-1', :title => '1-1'}, {:id => '1-2', :title => '1-2'}]
        }
      ]

      tree = Editor::View::Tree.new(:id => 'test', :title => 'test', :children => children)
      Element.find('#test').append(tree.dom_element)
      tree.observe(:order) do |n|
        p n
      end

      Element.find('#set-children').on('click') do
        data = [
          {:id => '1', :title => '1', :children =>
            rand(10).times.map{|i| {:id => "1-#{i}", :title => "1-#{i}"} }
          }
        ]
        tree.children = data
      end
    end

    def self.display_test
      display = Editor::View::Display.new(
        :number => '1.1.1',
        :title => 'title',
        :body => "line1\nline2\n<tag>\nhogehoge",
        :tags => ['t1', 't2'].map{|s| {:str => s} }
      )
      raise 'bodyが不正' unless display.dom_element(:body_display).html == "line1<br>line2<br>&lt;tag&gt;<br>hogehoge"

      display2 = Editor::View::Display.new(:number => '1.1.2', :title => 'title')
      display2.body = "line1\nline2\n<tag>\nhogehoge"
      raise 'bodyが不正' unless display2.dom_element(:body_display).html == "line1<br>line2<br>&lt;tag&gt;<br>hogehoge"
    end

    def self.editor_test
      editor = Editor::View::Editor.new(
        :title => 'title',
        :body => "line1\nline2\n<tag>\nhogehoge",
        :tags => ['t1', 't2']
      )
      raise 'タグが不正' unless editor.dom_element(:tag_str).value == 't1 t2'
      editor.dom_element(:tag_str).value = 't3 t4'
      editor.dom_element(:tag_str).trigger(:input)
      raise 'タグが更新されていない' unless editor.tags == ['t3', 't4']
    end

    def self.content_test
      content = Editor::View::Content.new(
        :number => '1.1.1',
        :title => 'title',
        :body => "line1\nline2\n<tag>\nhogehoge",
        :tags => ['t1', 't2']
      )
      Element.find('#content').append(content.dom_element)
      Element.find('#edit').on(:click) { content.edit }
      Element.find('#show').on(:click) { content.show }
    end
  end
end

Document.ready? do
  JavascriptTestsView.execute unless Element.find('body.javascript_test').empty?
end
