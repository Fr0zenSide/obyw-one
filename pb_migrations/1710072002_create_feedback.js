migrate((app) => {
  const collection = new Collection({
    name: "feedback",
    type: "base",
    schema: [
      { name: "user", type: "relation", required: false, options: { collectionId: "_pb_users_auth_", cascadeDelete: false, minSelect: null, maxSelect: 1, displayFields: ["email"] } },
      { name: "app", type: "text", required: true, options: { min: 1, max: 50 } },
      { name: "type", type: "select", required: true, options: { maxSelect: 1, values: ["bug", "feature", "general"] } },
      { name: "message", type: "text", required: true, options: { min: 10 } },
      { name: "screenshot", type: "file", required: false, options: { maxSelect: 1, maxSize: 10485760, mimeTypes: ["image/jpeg", "image/png", "image/webp"] } },
      { name: "status", type: "select", required: true, options: { maxSelect: 1, values: ["new", "reviewed", "resolved"] } }
    ],
    createRule: "",
    listRule: null,
    viewRule: null,
    updateRule: null,
    deleteRule: null
  });
  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("feedback");
  return app.delete(collection);
});
