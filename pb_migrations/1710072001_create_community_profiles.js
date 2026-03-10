migrate((app) => {
  const collection = new Collection({
    name: "community_profiles",
    type: "base",
    schema: [
      { name: "user", type: "relation", required: true, options: { collectionId: "_pb_users_auth_", cascadeDelete: true, minSelect: null, maxSelect: 1, displayFields: ["email"] } },
      { name: "display_name", type: "text", required: true, options: { min: 1, max: 100 } },
      { name: "avatar_url", type: "url", required: false, options: {} },
      { name: "bio", type: "text", required: false, options: { max: 500 } },
      { name: "apps", type: "json", required: false, options: { maxSize: 2000 } },
      { name: "preferences", type: "json", required: false, options: { maxSize: 5000 } }
    ],
    indexes: ["CREATE UNIQUE INDEX idx_cp_user ON community_profiles (user)"],
    createRule: '@request.auth.id != ""',
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    updateRule: '@request.auth.id != "" && user = @request.auth.id',
    deleteRule: null
  });
  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("community_profiles");
  return app.delete(collection);
});
