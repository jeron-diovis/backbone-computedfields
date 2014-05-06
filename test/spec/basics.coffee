describe "mixing", ->

  Model = null
  methods = ["initialize", "get", "set"]

  # Backbone.Model.extend() and Backbone.ComputedFields.mixin are used only in this test, to show what exactly we do.
  # In other tests 'clazz()' shortcut will be used to create new class with already attached mixin
  beforeEach ->
    Model = Backbone.Model.extend()

  it "should override methods in prototype", ->
    Backbone.ComputedFields.mixin Model::
    for method in methods
      expect(Model::[method]).is.not.equal Backbone.Model::[method], "Method #{method} is not overridden in prototype"

  it "should override methods in particular instance", ->
    model = new Model
    Backbone.ComputedFields.mixin model
    for method in methods
      expect(model[method]).is.not.equal Model::[method], "Method '#{method}' is not overridden in instance"
      expect(Model::[method]).is.equal Backbone.Model::[method], "Method '#{method}' is overridden in prototype"
