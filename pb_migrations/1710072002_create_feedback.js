migrate((app) => {
  const collection = new BaseCollection()
  collection.name = "feedback"
  collection.type = "base"
  collection.createRule = ""
  collection.listRule = null
  collection.viewRule = null
  collection.updateRule = null
  collection.deleteRule = null

  collection.fields.add(new RelationField({
    name: "user",
    required: false,
    collectionId: "_pb_users_auth_",
    cascadeDelete: false,
    maxSelect: 1,
  }))

  collection.fields.add(new TextField({
    name: "app",
    required: true,
    min: 1,
    max: 50,
  }))

  collection.fields.add(new SelectField({
    name: "type",
    required: true,
    maxSelect: 1,
    values: ["bug", "feature", "general"],
  }))

  collection.fields.add(new TextField({
    name: "message",
    required: true,
    min: 10,
  }))

  collection.fields.add(new FileField({
    name: "screenshot",
    required: false,
    maxSelect: 1,
    maxSize: 10485760,
    mimeTypes: ["image/jpeg", "image/png", "image/webp"],
  }))

  collection.fields.add(new SelectField({
    name: "status",
    required: true,
    maxSelect: 1,
    values: ["new", "reviewed", "resolved"],
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("feedback")
  return app.delete(collection)
})
