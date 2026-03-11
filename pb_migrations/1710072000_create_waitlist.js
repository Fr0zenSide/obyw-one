migrate((app) => {
  const collection = new BaseCollection()
  collection.name = "waitlist"
  collection.type = "base"
  collection.listRule = null
  collection.viewRule = null
  collection.createRule = ""
  collection.updateRule = null
  collection.deleteRule = null

  collection.fields.add(new EmailField({
    name: "email",
    required: true,
  }))

  collection.fields.add(new TextField({
    name: "source",
    required: true,
    min: 1,
    max: 50,
  }))

  collection.fields.add(new SelectField({
    name: "status",
    required: true,
    maxSelect: 1,
    values: ["pending", "invited", "joined"],
  }))

  collection.fields.add(new TextField({
    name: "notes",
    required: false,
  }))

  // Save collection first, then add index
  app.save(collection)

  // Reload and add index
  const saved = app.findCollectionByNameOrId("waitlist")
  saved.indexes = ["CREATE UNIQUE INDEX idx_waitlist_email ON waitlist (email)"]
  return app.save(saved)
}, (app) => {
  const collection = app.findCollectionByNameOrId("waitlist")
  return app.delete(collection)
})
