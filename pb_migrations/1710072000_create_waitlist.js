migrate((app) => {
  const collection = new Collection({
    name: "waitlist",
    type: "base",
    schema: [
      { name: "email", type: "email", required: true, options: {} },
      { name: "source", type: "text", required: true, options: { min: 1, max: 50 } },
      { name: "status", type: "select", required: true, options: { maxSelect: 1, values: ["pending", "invited", "joined"] } },
      { name: "notes", type: "text", required: false, options: {} }
    ],
    indexes: ["CREATE UNIQUE INDEX idx_waitlist_email ON waitlist (email)"],
    createRule: "",
    listRule: null,
    viewRule: null,
    updateRule: null,
    deleteRule: null
  });
  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("waitlist");
  return app.delete(collection);
});
