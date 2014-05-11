Model = null

describe "getters", ->

  after -> Model = null

  describe "context", ->

    it "should call getters in sandbox context", ->
      getter = sinon.spy()

      Model = clazzMix
        computed:
          field:
            get: getter

      model = new Model
      model.get "field"

      context = getter.thisValues[0]
      expect(getter.calledOn model).is.false
      expect(context).has.property "isSandboxContext", true

    if Object.freeze?
      it "should deny to modify getters context", ->
        getter = sinon.spy ->
          @newProperty = "modified!"
          @isSandboxContext = false

        Model = clazzMix
          computed:
            field:
              get: getter

        model = new Model
        model.get "field"

        expect(getter.called).is.true
        context = getter.thisValues[0]
        expect(context).not.has.property "newProperty"
        expect(context).has.property "isSandboxContext", true

    it "should call functional dependencies in context of model", ->
      callback = sinon.spy()

      Model = clazzMix
        method: callback
        computed:
          field:
            depends: ["=method", callback]
            get: ->

      model = new Model
      model.get "field"

      expect(callback.calledTwice).is.true
      expect(callback.alwaysCalledOn model).is.true


  beforeEach -> Model = null

  it "should get simplest virtual attribute", ->
    Model = clazzMix
      computed:
        answer:
          get: -> 42

    model = new Model
    expect(model.get "answer").is.equal 42
    expect(model.attributes).not.has.property "answer"

  it "should get attribute with simple dependency", ->
    Model = clazzMix
      defaults: ->
        question: "The meaning of life?"
      computed:
        answer:
          depends: "question"
          get: (question) -> "For question '#{question}' answer is '42'"

    model = new Model
    expect(model.get "answer").is.equal "For question 'The meaning of life?' answer is '42'"

  it "should resolve multiple dependencies in proper order", ->
    Model = clazzMix
      defaults: ->
        question: "The meaning of life?"
      computed:
        answer:
          get: -> 42
        report:
          depends: ["question", "answer"]
          get: (question, answer) -> "For question '#{question}' answer is '#{answer}'"
        formatted:
          depends: "report"
          get: (report) -> "Formatted: #{report}"

    model = new Model
    expect(model.get "formatted").is.equal "Formatted: For question 'The meaning of life?' answer is '42'"

  it "should get proxy attribute as modified real attribute", ->
    Model = clazzMix
      defaults: ->
        answer: 42
      computed:
        answer:
          depends: "answer"
          get: String
        unexisting:
          depends: "unexisting"
          get: (real) -> "--#{real}--"

    model = new Model
    expect(model.get "answer").is.a("string").that.is.equal("42").and.is.not.equal(model.attributes.answer)
    expect(model.get "unexisting").is.equal "--undefined--"

  describe "functional dependencies", ->
    prevConfig = null

    before ->
      {config} = Plugin
      prevConfig = _.clone config
      config.funcDepsPrefix = "="

    after -> Plugin.config = prevConfig

    it "should allow model's methods in dependencies", ->
      Model = clazzMix
        method: -> "some value"
        computed:
          field:
            depends: "=method"
            get: (val) -> "Method returns #{val}"

      model = new Model
      expect(model.get "field").is.equal "Method returns some value"

    it "should allow callbacks in dependencies", ->
      Model = clazzMix
        computed:
          field:
            depends: -> "value from callback"
            get: (val) -> "Field returns #{val}"

      model = new Model
      expect(model.get "field").is.equal "Field returns value from callback"

    it "should call functional dependencies with field name as single argument", ->
      callback = sinon.spy()

      Model = clazzMix
        method: callback
        computed:
          field:
            depends: ["=method", callback]
            get: ->

      model = new Model
      model.get "field"

      expect(callback.calledTwice).is.true
      expect(callback.alwaysCalledWithExactly "field").is.true