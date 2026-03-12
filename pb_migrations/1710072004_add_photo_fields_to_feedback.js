/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = app.findCollectionByNameOrId("feedback")

  collection.fields.push(
    { name: "photo_s3_key", type: "text", required: false, max: 1024 },
    { name: "photo_bucket", type: "text", required: false, max: 100 },
  )

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("feedback")

  collection.fields = collection.fields.filter(
    (f) => !["photo_s3_key", "photo_bucket"].includes(f.name)
  )

  return app.save(collection)
})
