migrate((app) => {
  const collection = new Collection({
    name: "waitlist",
    type: "base",
    fields: [
      { name: "email", type: "email", required: true },
      { name: "source", type: "text", required: true, min: 1, max: 50 },
      { name: "status", type: "select", required: true, maxSelect: 1, values: ["pending", "invited", "joined"] },
      { name: "notes", type: "text", required: false },
    ],
    createRule: "",
    listRule: null,
    viewRule: null,
    updateRule: null,
    deleteRule: null,
  })
  app.save(collection)

  const saved = app.findCollectionByNameOrId("waitlist")
  saved.indexes = ["CREATE UNIQUE INDEX idx_waitlist_email ON waitlist (email)"]
  return app.save(saved)
}, (app) => {
  const collection = app.findCollectionByNameOrId("waitlist")
  return app.delete(collection)
})
