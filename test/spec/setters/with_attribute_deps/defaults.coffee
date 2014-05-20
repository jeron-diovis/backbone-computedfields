# Ok, I know that tests should be as clear as possible, with no own logic
# But the following tests really the same things with minimal differences in config,
# so describing each of them as independent test would be too verbose and confusing
describe "setters", ->
  describe "when field has attribute dependencies", ->
    createTest = (config) -> ->
      Model = clazzMix
        defaults: ->
          realAttr: "some value"
        computed: ->
          computedAttr:
            depends: if config.isProxy then "computedAttr realAttr" else "realAttr"
            get: String
            set: config.set

      model = new Model
      newValue = 42
      callback = sinon.spy()

      model.on "change:computedAttr", callback
      model.set "computedAttr", newValue

      expect(callback.called).is.true
      expect(callback.firstCall.args[1]).is.equal newValue
      if config.shouldStoreAttr
        expect(model.attributes).has.property "computedAttr", newValue
      else
        expect(model.attributes).not.has.property "computedAttr"

    describe "proxy fields", ->
      it "should always work as default", ->
        for setter in [undefined, true, _.identity]
          do createTest {
            isProxy: yes
            shouldStoreAttr: yes
            set: setter
          }

    describe "virtual fields", ->
      it "should work as default when setter is not a function", ->
        do createTest {
          shouldStoreAttr: no
          set: undefined
        }

        do createTest {
          shouldStoreAttr: yes
          set: true
        }
