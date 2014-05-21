Model = null

describe "setters", -> \
describe "when field has attribute dependencies", -> \
describe "virtual fields", -> \
describe "when setter is a function", ->

  describe "should update attr deps instead of storing itself, and trigger 'change' for both", ->

    it "should not care about consistency when pure virtual fields depends from one another", ->
      Model = clazzMix
        computed:
          firstName:
            get: -> "John"
          lastName:
            get: -> "Smith"
          fullName:
            depends: "firstName lastName"
            set: (str) -> str.split " "

      model = new Model
      callback = sinon.spy()

      model.on "all", callback

      model.set "fullName", "Unknown Anonymous"

      for name in ["firstName", "lastName"]
        triggered = callback.withArgs("change:#{name}").args[1]
        expect(model.get name).is.not.equal triggered, "Wow, pure virtual field '#{name}' has been affected by setting dependent field"

    describe "when there is single dependency", ->

      it "should directly map setter's returned value to dependency value, no matter what that value is", ->
        Model = clazzMix
          defaults: ->
            realAttr: "some value"
          computed:
            answer:
              depends: "realAttr"
              get: String
              set: _.identity

        model = new Model

        newValues = [
          42
          ["array1", "array2"]
          { "someKey": "some new value" }
        ]

        callback = sinon.spy()
        callback.withArgs model, value for value in newValues

        model.on "change:answer", callback
        model.on "change:realAttr", callback

        for value in newValues
          model.set "answer", value
          expect(model.attributes.realAttr).is.equal value
          expect(model.attributes).not.has.property "answer"

          callbackForValue = callback.withArgs model, value
          expect(callbackForValue.calledTwice).is.true
          expect(callbackForValue.alwaysCalledWith model, value).is.true


    describe "when there are multiple dependencies", configurable ->

      beforeEach ->
        config.initInConstructor = no
        Model = null

      defField = (fieldConfig = {}) ->
        Model = clazzMix
          defaults: ->
            firstName: "John"
            lastName: "Smith"
          computed: ->
            fullName: _.extend {
              depends: ["firstName", "lastName"]
              get: (args...) -> args.join " "
            }, fieldConfig

      # template of test, suitable for most cases in this test suite
      expectAttributes = (expected) ->
        model = new Model
        callback = sinon.spy()

        callback.withArgs "change:#{attr}" for attr of expected

        model.on "all", callback

        model.set "fullName", expected.fullName

        expect(model.attributes).is.deep.equal { firstName: expected.firstName, lastName: expected.lastName }
        for attr, value of expected
          expect(callback.withArgs("change:#{attr}", model, value).calledOnce).is.true

      it "should not accept scalar values from setter", ->
        defField set: _.identity

        model = new Model
        setter = -> model.set "fullName", "Some Name"

        expect(setter).to.throw /Computed fields/

      describe "when setting array", ->

        beforeEach -> defField set: (fullName) -> fullName.split " "

        it "should automatically map arrays to dependencies", ->
          expectAttributes {
            fullName: "Some Name"
            firstName: "Some"
            lastName: "Name"
          }

        it "should set missed dependencies to undefined", ->
          expectAttributes {
            fullName: "Just"
            firstName: "Just"
            lastName: undefined
          }

      describe "when setting object", ->

        it "should map returned object's properties to dependencies", ->
          defField set: (fullName) ->
            [firstName, lastName] = fullName.split " "
            {firstName, lastName}

          expectAttributes {
            fullName: "Some Name"
            firstName: "Some"
            lastName: "Name"
          }

        it "should set missed dependencies to undefined", ->
          defField set: (fullName) ->
            [firstName] = fullName.split " "
            {firstName}

          expectAttributes {
            fullName: "New Name"
            firstName: "New"
            lastName: undefined
          }

        it "should silently omit properties which not matches to dependencies", ->
          defField set: (fullName) ->
            [firstName, lastName] = fullName.split " "
            {firstName, lastName, extraProperty: "useless value"}

          model = new Model
          callback = sinon.spy()
          model.on "all", callback

          model.set "fullName", "Some Value"

          expect(callback.withArgs("change:extraProperty").called).is.false
          expect(model.attributes).not.has.property "extraProperty"