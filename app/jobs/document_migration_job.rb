class DocumentMigrationJob < ApplicationJob
  queue_as :default

  def perform(document_id:, token:, host:)
    drive_service = Drive::Document.service(token)
    # 移行先フォルダを取得
    folder_name = 'カケラの樹文書'
    list = drive_service.list_files(:q => "name = '#{folder_name}'")
    folder =
      if list.files.blank?
        metadata =
          {
            :name => folder_name,
            :mime_type => 'application/vnd.google-apps.folder'
          }
        drive_service.create_file(metadata, fields: 'id')
      else
        list.files.first
      end

    hosted_doc = Document.find(document_id)
    drive_doc =
      Drive::Document.new(
        {
          :parent => folder.id,
          :body => {
            'title' => hosted_doc.title,
            'body' => hosted_doc.description,
            'children' => hosted_doc.body,
            'markup' => hosted_doc.markup
          }
        },
        {:host => host}
      )

    drive_doc.save(token)

    hosted_doc.update_attribute(:google_document_id, drive_doc.id)
  end
end
