describe "simplest test ever", ->
  it "should works", ->
    expect(yes).is.ok

describe "environment", ->
  it "should load all scripts", ->
    expect(_).is.a "function"
    expect(Backbone).is.an "object"
    expect(Backbone.ComputedFields).is.an "object"