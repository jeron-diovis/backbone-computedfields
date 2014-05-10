Model = null

describe "computed config", ->

  it "for each field should require at least getter or setter", ->
    init = -> clazzMixInit computed: useless: {}
    expect(init).to.throw /useless/


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

      prevConfig = null

      before ->
        {config} = Plugin
        prevConfig = _.clone config
        config.funcDepsPrefix = "="

      after -> Plugin.config = prevConfig

      it "should distinguish method-dependencies and attributes, and do not recognize them as circular dependencies", ->
        Model = clazz
          theMethod: -> "some value"
          computed:
            "=theMethod":
              get: -> 42
              depends: "=theMethod"

        expect(initializer).to.not.throw Error, "Method-dependency is not distinguished from attribute"
        expect(Model::computed["=theMethod"].depends).to.not.have.ownProperty "proxyIndex", "Method-dependency is recognized as proxy field"


  describe "parsing", ->

    prevConfig = null

    before ->
      {config} = Plugin
      prevConfig = _.clone config
      # set config locally to do not depend from plugin defaults in test
      _.extend config,
        funcDepsPrefix: "="
        stringDepsSplitter: /\s+/,
        proxyFieldPattern: /^&$/
        shortDepsNameSeparator: /\s+<\s+/,
        shortDepsSplitter: /\s+/,

    after -> Plugin.config = prevConfig


    describe "basics", ->

      field = null
      externalFunc = -> "some external value"

      before ->
        Model = clazzMixInit
          theMethod: -> "some value"
          computed:
            answer:
              get: -> 42
              depends: ["answer", "someAnotherAttr", "=theMethod", externalFunc]

        field = Model::computed.answer

      it "should modify computed config with parsed data", ->
        expect(field).has.property "name", "answer"
        expect(field.depends).is.an "object", "Dependencies are not parsed"

      it "should properly parse different types of dependencies", ->
        expect(Object.keys(field.depends)).have.members ["common", "attrs", "proxyIndex"]

        expect(field.depends.attrs).is.an("array").and.have.members(["someAnotherAttr"], "Attribute dependency is not parsed properly")

        expect(field.depends.common)
          .is.an("array")
          .and.include.members([Model::theMethod, externalFunc], "Functional dependencies are not parsed properly")

        expect(field.depends.proxyIndex).is.equal 0, "Proxy field is not parsed properly"


    describe "advanced", ->

      deps = null

      # shortcut, to quickly redefine just desired field params
      defField = (name, config) ->
        field = {}
        field[name] = _.extend { get: -> 42 }, config

        Model = clazzMixInit computed: field

        deps = -> Model::computed[name].depends

      beforeEach -> Model = null; deps = null

      it "should allow to define dependencies as a string", ->
        defField "answer", depends: "someAttr someAnotherAttr"
        expect(deps().attrs).has.members ["someAttr", "someAnotherAttr"]

      it "should allow to define single callback dependency", ->
        callback = -> "some value"
        defField "answer", depends: callback
        expect(deps().common).has.members [callback]

      it "should support short proxy-field syntax", ->
        defField "answer", depends: "&"
        expect(deps()).has.property "proxyIndex", 0