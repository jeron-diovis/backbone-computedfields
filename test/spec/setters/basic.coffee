Model = null

describe "setters", ->

  describe "when field has no attribute dependencies", ->

    it "by default should trigger 'change' event on setting virtual attributes, but not store them in 'attributes' hash", ->
      Model = clazzMix
        computed:
          answer:
            get: -> 42

      model = new Model
      newValue = 0
      callback = sinon.spy()

      model.on "change:answer", callback
      model.set "answer", newValue

      expect(callback.called).is.true
      expect(callback.firstCall.args[1]).is.equal newValue
      expect(model.attributes).not.has.property "answer"

    it "should store proxy attributes by default", ->
      Model = clazzMix
        computed:
          answer:
            depends: "answer"
            get: String

      model = new Model
      newValue = 42

      model.set "answer", newValue

      expect(model.attributes).has.property "answer", newValue

    it "should store virtual attributes when explicitly allowed", ->
      Model = clazzMix
        computed:
          answer:
            get: -> 42
            set: true

      model = new Model
      newValue = 0

      model.set "answer", newValue

      expect(model.attributes).has.property "answer", newValue

    it "should store virtual attributes when setter is a function", ->
      Model = clazzMix
        computed:
          answer:
            depends: ->
            get: -> 42
            set: _.identity

      model = new Model
      newValue = 0

      model.set "answer", newValue

      expect(model.attributes).has.property "answer", newValue

    it "should neither trigger 'change' nor store even proxy attributes when explicitly disallowed", ->
      Model = clazzMix
        computed:
          answer:
            depends: "answer"
            get: String
            set: false

      model = new Model
      callback = sinon.spy()

      model.on "change:answer", callback
      model.set "answer", 42

      expect(callback.called).is.false
      expect(model.get "answer").is.equal "undefined"


    describe "default attributes, when proxy-setters are explicitly disabled", configurable ->

      before ->
        Model = clazzMix
          defaults: ->
            answer: 42
          computed:
            answer:
              get: String
              depends: "answer"
              set: false

      it "should not be affected when plugin is initialized after construction", ->
        config.initInConstructor = false
        model = new Model
        expect(model.attributes).has.property "answer", 42

      it "should be affected when plugin is initialized during construction", ->
        config.initInConstructor = true
        model = new Model
        expect(model.attributes).not.has.property "answer"

  it "should call setters only with value and options, no matter to dependencies", ->
    setter = sinon.spy()

    Model = clazzMix
      computed:
        answer:
          depends: ["someAttr", ->]
          get: -> 42
          set: setter

    model = new Model
    newValue = 0
    options = { silent: true }

    model.set "answer", newValue, options

    expect(setter.calledWithExactly newValue, options).is.true