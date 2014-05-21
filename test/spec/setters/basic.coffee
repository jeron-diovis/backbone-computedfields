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

  describe "should cascaded update all fields with attribute dependencies in dependencies chain", ->

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

      it "should update all attributes, listed in dependencies of fields with setters, with single 'model::set' call", ->
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

      it "should check consistency of values to be set", ->
        defSetters report: (str) -> str.split "-"

        model = new Model

        setter = ->
          model.set
            report: "question-answer"
            question: "inconsistent question value"
            answer: "inconsistent answer value"

        expect(setter).to.throw /can't set attribute 'question'/