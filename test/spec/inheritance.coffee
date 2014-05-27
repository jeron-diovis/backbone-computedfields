Model = null

describe "inheritance", ->

  it "should inherit config from parent", ->
    Parent = clazzMix
      computed:
        answer:
          get: -> 42

    class Child extends Parent
    model = new Child
    expect(model.get "answer").is.equal 42, "Computed field was not inherited"

  it "should store parent's config as own", ->
    Parent = clazzMix
      computed:
        answer:
          get: -> 42

    class Child extends Parent

    new Child

    internalProps = ["__computedFieldsDependenciesMap", "__computedFieldsParsedConfig"]
    expect(Child::).to.contain.keys internalProps
    expect(Parent::).to.not.contain.keys internalProps

  it "should have ability to override parent's config", ->
    Parent = clazzMix
      computed:
        answer:
          get: -> 42

    class Child extends Parent
      computed:
        question:
          get: -> "The meaning of life?"

    model = new Child

    expect(model.get "question").is.equal "The meaning of life?"
    expect(model.get "answer").is.undefined

  it "should have ability to extend parent's config", ->
    Parent = clazzMix
      computed: ->
        answer:
          get: -> 42

    class Child extends Parent
      computed: ->
        _.extend super,
          question:
            get: -> "The meaning of life?"

    model = new Child

    expect(model.get "question").is.equal "The meaning of life?"
    expect(model.get "answer").is.equal 42