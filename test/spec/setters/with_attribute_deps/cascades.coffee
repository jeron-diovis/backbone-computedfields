Model = null

describe "setters", -> \
describe "when field has attribute dependencies", -> \
describe "when setter is a function", -> \

describe "cascaded update of all fields with attribute dependencies in dependencies tree", ->

  defSetters = (setters = {}) ->
    Model = clazzMix
      defaults: ->
        question: "The meaning of life?"
      computed: ->
        config =
          answer:
            get: -> 42
          report:
            depends: ["question", "answer"]
            get: (question, answer) -> "For question '#{question}' answer is '#{answer}'"
          formatted:
            depends: "report"
            get: (report) -> "Formatted: #{report}"
          independent:
            get: -> "independent field"

        for name, field of config when setters[name]?
          field.set = setters[name]

        config

  beforeEach -> Model = null

  describe "from root to top", ->
    it "should trigger 'change' for each field in chain, even without setters", ->
      defSetters()

      model = new Model
      callback = sinon.spy()

      model.on "all", callback

      model.set "question", "Is it works?"

      expect(callback.firstCall.calledWith("change:question", model, "Is it works?")).is.equal true, "question is not changed properly"
      expect(callback.secondCall.calledWith("change:report", model, "For question 'Is it works?' answer is '42'")).is.equal true, "report is not changed properly"
      expect(callback.thirdCall.calledWith("change:formatted", model, "Formatted: For question 'Is it works?' answer is '42'")).is.equal true, "formatted is not changed properly"

      expect(model.attributes).not.has.property "report"
      expect(model.attributes).not.has.property "formatted"

  describe "from top to root", ->
    it "should only trigger 'change' for topmost field when there are no setters", ->
      defSetters()

      model = new Model
      callback = sinon.spy()

      model.on "all", callback

      model.set "formatted", "New formatted value"

      expect(callback.calledTwice).is.equal true, "change was triggered for several attributes"
      expect(callback.firstCall.calledWith("change:formatted", model, "New formatted value")).is.true
      expect(callback.secondCall.calledWith("change")).is.true

      expect(model.attributes).not.has.property "formatted"

    it "should update all attributes, listed in dependencies of fields with functional setters, with single 'model::set' call", ->
      setters =
        formatted: sinon.spy (str) -> str.match(/Formatted: (.*)/)[1]
        report: sinon.spy (str) ->
          [question, answer] = str.match(/question '([\w\s]+\?)'.*answer is '([\w\s]+)'/).slice 1
          {question, answer}
        answer: true

      defSetters setters

      model = new Model
      callback = sinon.spy()
      sinon.spy model, "set"

      model.on "all", callback

      model.set "formatted", "Formatted: For question 'Is it works?' answer is 'yes'"

      expect(model.set.calledOnce).is.equal true, "model::set was called several times"

      expectedChanges =
        "formatted": "Formatted: For question 'Is it works?' answer is 'yes'"
        "report"   : "For question 'Is it works?' answer is 'yes'"
        "question" : "Is it works?"
        "answer"   : "yes"

      expect(callback.callCount).is.equal 5, "Callback was called wrong number of times" # +1 for common 'change' event
      expect(callback.calledWith "change:independent").is.equal false, "Independent field was updated"

      i = -1
      for name, value of expectedChanges
        call = callback.getCall ++i
        expect(call.args[0]).is.equal "change:#{name}", "'#{name}' was not changed in proper order"
        expect(call.args[2]).is.equal value, "'#{name}' has wrong value"

      expect(model.attributes).is.deep.equal { "question": "Is it works?", "answer": "yes" }, "Attributes was not stored properly"

      for name in ["formatted", "report"]
        expect(setters[name].calledOnce).is.equal true, "'#{name}' setter was called several times"
        expect(setters[name].calledWith expectedChanges[name]).is.equal true, "'#{name}' setter was called with wrong value"

    it """should update entire dependencies tree, propagating new values in all directions
            and updating next node only when all possible of it's dependencies are resolved with new values""", ->
      Model = clazzMix
        defaults: ->
          node00: 0
        computed: ->
          node10:
            depends: "node00"
            get: (node00) -> "10: (00: #{node00})"
          node11:
            depends: "node00"
            get: (node00) -> "11: (00: #{node00})"
          node20:
            depends: "node10"
            get: (node10) -> "20: (10: #{node10})"
          node21:
            depends: "node00 node11"
            set: (str) -> str.split " "
          node30:
            depends: "node11 node20"
            get: (node11, node20) -> "30: (11: #{node11}, 20: #{node20})"

      model = new Model
      callback = sinon.spy()

      model.on "all", callback

      model.set "node21", "00 11"

      # note, that 'change' events are not guaranteed to be triggered in order, specified here
      expectedChanges =
        node21: "00 11"
        node00: "00"
        node11: "11"
        node10: "10: (00: 00)"
        node20: "20: (10: 10: (00: 00))"
        node30: "30: (11: 11, 20: 20: (10: 10: (00: 00)))"

      for name, value of expectedChanges
        attrCallback = callback.withArgs("change:#{name}")
        expect(attrCallback.calledOnce).is.equal true, "Field '#{name}' was not updated"
        expect(attrCallback.firstCall.args[2]).is.equal value, "Field '#{name}' has wrong value"


  describe "validating consistency of values to be set", ->
    it "should raise error when several setters returns different values for same attribute", ->
      defSetters
        report: (str) -> str.split "-"
        formatted: _.identity

      model = new Model

      setter = ->
        model.set
          report: "question-answer"
          question: "inconsistent question value"
          answer: "inconsistent answer value"

      expect(setter).to.throw /can't set attribute 'question'/, "One-level inconsistency was not detected"

      setter = ->
        model.set
          formatted: "question-answer"
          question: "inconsistent question value"
          answer: "inconsistent answer value"

      expect(setter).to.throw /can't set attribute 'question'/, "Multi-level inconsistency was not detected"