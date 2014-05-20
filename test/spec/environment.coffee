describe "environment", ->
  it "should use Chai assertions", ->
    expect(yes).is.ok

  it "should load all scripts", ->
    expect(_).is.a "function", "Underscore"
    expect(Backbone).is.an "object", "Backbone"
    expect(mixin).is.a "function", "Helper 'mixin' function"
    expect(configurable).is.a "function", "Helper 'configurable' function"
    for name, func of {clazz, clazzMix, clazzMixInit}
      expect(func).is.a "function", "Helper '#{name}' function"
