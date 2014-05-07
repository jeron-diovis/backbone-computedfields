Model = null

describe "getters", ->

    it "should get simplest virtual attribute", ->
      Model = clazzMix
        computed:
          answer:
            get: -> 42

      model = new Model
      expect(model.get "answer").is.equal 42
      expect(model.attributes).to.not.have.property "answer"