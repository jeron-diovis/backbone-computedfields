describe "environment", ->
  it "should use Chai assertions", ->
    expect(yes).is.ok

  it "should load all scripts", ->
    expect(_).is.a "function", "Underscore"
    expect(Backbone).is.an "object", "Backbone"
    expect(Backbone.ComputedFields).is.an "object", "Computed fields plugin"
    expect(clazz).is.a "function", "Helper 'clazz' function"
    expect(mixin).is.a "function", "Helper 'mixin' function"
