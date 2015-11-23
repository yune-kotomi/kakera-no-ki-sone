def document_source
  let(:children) {
    [{"id"=>'c1',
      "title"=>"c1",
      "body"=>"body 1",
      "children"=>
       [{
          "id"=>"1-1",
          "title"=>"1-1",
          "body"=>"body 1-1",
          "children"=>
          [{
              "id"=>"1-1-1",
              "title"=>"1-1-1",
              "body"=>"body 1-1-1",
              "children"=>[],
              "metadatum" => {"tags" => ['t1', 't11', 't111']}
            }
          ],
          "metadatum" => {"tags" => ['t1', 't11']}},
        {
          "id"=>"1-2",
          "title"=>"1-2",
          "body"=>"body 1-2",
          "children"=>[],
          "metadatum" => {"tags" => ['t1', 't12']}
        },
        {
          "id"=>"1-3",
          "title"=>"1-3",
          "body"=>"body 1-3",
          "children"=>[],
          "metadatum" => {"tags" => ['t1', 't13']}
        }],
      "metadatum" => {"tags" => ['t1']}}]

  }
  let(:source) {
    {
      :id => 'id',
      :title => 'title',
      :body => 'description',
      :children => children,
      :public => true,
      :archived => false,
      :markup => 'plaintext'
    }
  }
end
