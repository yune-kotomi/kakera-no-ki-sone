def document_source
  let(:children) {
    [{"id"=>'c1',
      "title"=>"c1",
      "body"=>"body 1",
      "children"=>
       [{"id"=>"1-1", "title"=>"1-1", "body"=>"body 1-1", "children"=>
         [{"id"=>"1-1-1", "title"=>"1-1-1", "body"=>"body 1-1-1", "children"=>[]}]},
        {"id"=>"1-2", "title"=>"1-2", "body"=>"body 1-2", "children"=>[]},
        {"id"=>"1-3", "title"=>"1-3", "body"=>"body 1-3", "children"=>[]}]}]

  }
  let(:source) {
    {
      :id => 'id',
      :title => 'title',
      :body => 'description',
      :children => children,
      :private => false,
      :archived => false,
      :markup => 'plaintext'
    }
  }
end
