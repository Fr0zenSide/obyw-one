migrate((app) => {
  const collection = new Collection({
    name: "community_profiles",
    type: "base",
    fields: [
      { name: "user", type: "relation", required: true, collectionId: "_pb_users_auth_", cascadeDelete: true, maxSelect: 1 },
      { name: "display_name", type: "text", required: true, min: 1, max: 100 },
      { name: "avatar_url", type: "url", required: false },
      { name: "bio", type: "text", required: false, max: 500 },
      { name: "apps", type: "json", required: false, maxSize: 2000 },
      { name: "preferences", type: "json", required: false, maxSize: 5000 },
    ],
    createRule: '@request.auth.id != ""',
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    updateRule: '@request.auth.id != "" && user = @request.auth.id',
    deleteRule: null,
  })
  app.save(collection)

  const saved = app.findCollectionByNameOrId("community_profiles")
  saved.indexes = ["CREATE UNIQUE INDEX idx_cp_user ON community_profiles (user)"]
  return app.save(saved)
}, (app) => {
  const collection = app.findCollectionByNameOrId("community_profiles")
  return app.delete(collection)
})
