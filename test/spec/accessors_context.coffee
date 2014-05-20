describe "accessors context", ->

  it "should call accessors in sandbox context", ->
    accessor = sinon.spy()

    Model = clazzMix
      computed:
        field:
          set: accessor
          get: accessor

    model = new Model
    model.get "field"
    model.set "field", 0

    expect(accessor.calledTwice).is.true
    expect(accessor.calledOn model).is.false
    for context in accessor.thisValues
      expect(context).has.property "isSandboxContext", true

  if Object.freeze?
    it "should deny to modify accessors context", ->
      accessor = sinon.spy ->
        @newProperty = "modified!"
        @isSandboxContext = false

      Model = clazzMix
        computed:
          field:
            set: accessor
            get: accessor

      model = new Model
      model.get "field"
      model.set "field", 0

      for context in accessor.thisValues
        expect(context).not.has.property "newProperty"
        expect(context).has.property "isSandboxContext", true