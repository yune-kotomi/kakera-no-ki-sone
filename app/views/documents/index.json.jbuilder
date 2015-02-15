json.array!(@documents) do |document|
  json.extract! document, :id, :title, :description, :body, :private, :password, :markup
  json.url document_url(document, format: :json)
end
