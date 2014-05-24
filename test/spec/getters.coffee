Model = null

describe "getters", ->

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

  it "should get attribute as-is when there is no getter", ->
    Model = clazzMix
      defaults: ->
        answer: 42
      computed:
        answer:
          set: ->

    model = new Model
    expect(model.get "answer").is.equal 42

  describe "special dependencies", configurable ->

    beforeEach ->
      config.funcDepsPrefix = "="
      config.propDepsPrefix = "."

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

    it "should call functional dependencies in model context with field name as single argument", ->
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
      expect(callback.alwaysCalledWithExactly "field").is.true

    it "should allow model's properties in dependencies", ->
      Model = clazzMix
        property: "prop"
        method: -> "func"
        computed:
          prop:
            depends: ".property"
            get: _.identity
          func:
            depends: ".method"
            get: _.identity

      model = new Model
      expect(model.get "prop").is.equal model.property
      expect(model.get "func").is.a("function").that.is.equal model.method
