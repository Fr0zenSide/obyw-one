/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = new Collection({
    name: "activity_photos",
    type: "base",
    fields: [
      { name: "activity_id", type: "relation", required: true, collectionId: "activities", cascadeDelete: true, maxSelect: 1 },
      { name: "user_id", type: "relation", required: true, collectionId: "_pb_users_auth_", cascadeDelete: false, maxSelect: 1 },
      { name: "s3_key", type: "text", required: true, min: 1, max: 1024 },
      { name: "bucket", type: "text", required: true, min: 1, max: 100 },
      { name: "mime_type", type: "text", required: true, min: 1, max: 100 },
      { name: "file_size", type: "number" },
      { name: "latitude", type: "number" },
      { name: "longitude", type: "number" },
      { name: "captured_at", type: "date" },
      { name: "metadata_json", type: "json" },
      { name: "uploaded_at", type: "autodate", onCreate: true, onUpdate: false },
    ],
    indexes: [
      "CREATE INDEX idx_activity_photos_activity ON activity_photos (activity_id)",
      "CREATE INDEX idx_activity_photos_user ON activity_photos (user_id)",
      "CREATE UNIQUE INDEX idx_activity_photos_s3_key ON activity_photos (bucket, s3_key)",
    ],
    listRule: "@request.auth.id = user_id",
    viewRule: "@request.auth.id = user_id",
    createRule: "@request.auth.id = user_id",
    updateRule: null,
    deleteRule: "@request.auth.id = user_id",
  })
  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("activity_photos")
  return app.delete(collection)
})
