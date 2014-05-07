Model = null

describe "computed config", ->

  describe "when defined as a function", ->

    beforeEach ->
      Model = clazzMix
        computed: ->
          answer:
            get: -> 42

    it "should still works", ->
      model = new Model
      expect(model.get "answer").is.equal 42

    it "should override function with parsed config object", ->
      new Model
      expect(Model::computed).is.an "object", "Computed config function was not overridden with parsed config"



  describe "should statically detect circular dependencies", ->

    initializer = -> mixin Model::, yes

    it "should detect direct dependencies", ->
      Model = clazz
        computed:
          answer:
            get: -> 42
            depends: "question"
          question:
            get: -> "Then meaning of life?"
            depends: "answer"

      expect(initializer).to.throw /circular dependency detected/, "Direct circular dependency is not detected"

    it "should detect non-direct dependencies", ->
      Model = clazz
        computed:
          human:
            get: -> "Adam"
            depends: "answer"
          answer:
            get: -> 42
            depends: "question"
          question:
            get: -> "Then meaning of life?"
            depends: "human"

      expect(initializer).to.throw /circular dependency detected/, "Non-direct circular dependency is not detected"

    it "should recognize self-references as proxy fields, not as circular dependencies", ->
      Model = clazz
        computed:
          answer:
            get: -> 42
            depends: "answer"

      expect(initializer).to.not.throw Error, "Proxy field self-reference is not recognized"

    describe "recognizing method-dependencies", ->

      {config} = Backbone.ComputedFields
      prevConfig = _.clone config

      before -> config.funcDepsPrefix = "="

      it "should distinguish method-dependencies and attributes, and do not recognize them as circular dependencies", ->
        Model = clazz
          theMethod: -> "some value"
          computed:
            "=theMethod":
              get: -> 42
              depends: "=theMethod"

        expect(initializer).to.not.throw Error, "Method-dependency is not distinguished from attribute"
        expect(Model::computed["=theMethod"].depends).to.not.have.ownProperty "proxyIndex", "Method-dependency is recognized as proxy field"

      after -> config = prevConfig



  it "should modify computed config with parsed data", ->
    Model = clazzMixInit
      theMethod: -> "some value"
      computed:
        answer:
          get: -> 42
          depends: ["answer", "someAnotherAttr", "=theMethod"]

    field = Model::computed.answer
    expect(field).to.have.property "name", "answer"
    expect(field.depends).is.an "object"
    expect(Object.keys(field.depends)).have.members ["common", "attrs", "proxyIndex"]
    expect(field.depends.attrs)
      .is.an("array")
      .and.include("someAnotherAttr")
      .and.not.include.members(["answer", "=theMethod"])
    expect(field.depends.common)
      .is.an("array")
      .and.have.deep.property("[1]", Model::theMethod)
