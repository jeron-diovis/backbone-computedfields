Model = null

describe "startup", ->

  after -> Model = null

  describe "mixin", ->

    methods = ["get", "set", "initialize"]

    beforeEach -> Model = clazz()

    it "should override methods in prototype", ->
      mixin Model::
      for method in methods
        expect(Model::[method]).is.not.equal Backbone.Model::[method], "Method #{method} is not overridden in prototype"

    it "should override methods in particular instance", ->
      model = new Model
      mixin model
      for method in methods
        expect(model[method]).is.not.equal Model::[method], "Method '#{method}' is not overridden in instance"
        expect(Model::[method]).is.equal Backbone.Model::[method], "Method '#{method}' is overridden in prototype"



  describe "plugin initialization", ->

    propName = "_computedFieldsDependenciesMap"

    describe "when initializing with non-empty computed config", ->
      beforeEach ->
        Model = clazz
          computed:
            answer:
              get: -> 42

      it "should create dependencies config in prototype when attached to prototype", ->
        mixin Model::, yes
        expect(Model::).has.ownProperty propName

      it "still should create dependencies config in prototype, even when attached to instance", ->
        model = new Model
        mixin model, yes
        expect(Model::).has.ownProperty propName
        expect(model).not.has.ownProperty propName

      it "should create dependencies config in instance when instance have own computed config", ->
        model = new Model
        model.computed =
          question:
            get: -> "The meaning of life?"

        mixin model, yes
        expect(model).has.ownProperty propName
        expect(Model::).not.has.ownProperty propName

      it "by default, should init dependencies config lazy - only after first model creation", ->
        mixin Model::
        expect(Model::).not.has.ownProperty propName
        model = new Model
        expect(Model::).has.ownProperty propName
        expect(model).not.has.ownProperty propName

      it "should initialize dependencies config only once", ->
        mixin Model::, yes
        config1 = Model::[propName]
        model = new Model
        config2 = model[propName]
        expect(config1).is.an "object"
        expect(config1).is.equal config2, "Dependencies config was rewritten after first initialization"

    describe "when initializing with empty computed config", ->

      beforeEach -> Model = clazz()

      it "should NOT create dependencies config in prototype", ->
        mixin Model::, yes
        expect(Model::).not.has.ownProperty propName

      it "should NOT create dependencies config nowhere", ->
        model = new Model
        mixin model, yes
        expect(model).not.has.ownProperty propName
        expect(Model::).not.has.ownProperty propName

      it "should NOT lazy create dependencies config nowhere", ->
        mixin Model::
        model = new Model
        expect(Model::).not.has.ownProperty propName
        expect(model).not.has.ownProperty propName
