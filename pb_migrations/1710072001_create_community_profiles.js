migrate((app) => {
  const collection = new BaseCollection()
  collection.name = "community_profiles"
  collection.type = "base"
  collection.createRule = '@request.auth.id != ""'
  collection.listRule = '@request.auth.id != ""'
  collection.viewRule = '@request.auth.id != ""'
  collection.updateRule = '@request.auth.id != "" && user = @request.auth.id'
  collection.deleteRule = null

  collection.fields.add(new RelationField({
    name: "user",
    required: true,
    collectionId: "_pb_users_auth_",
    cascadeDelete: true,
    maxSelect: 1,
  }))

  collection.fields.add(new TextField({
    name: "display_name",
    required: true,
    min: 1,
    max: 100,
  }))

  collection.fields.add(new URLField({
    name: "avatar_url",
    required: false,
  }))

  collection.fields.add(new TextField({
    name: "bio",
    required: false,
    max: 500,
  }))

  collection.fields.add(new JSONField({
    name: "apps",
    required: false,
    maxSize: 2000,
  }))

  collection.fields.add(new JSONField({
    name: "preferences",
    required: false,
    maxSize: 5000,
  }))

  collection.indexes = ["CREATE UNIQUE INDEX idx_cp_user ON community_profiles (user)"]

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("community_profiles")
  return app.delete(collection)
})
