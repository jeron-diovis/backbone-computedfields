Plugin = Backbone.ComputedFields

{mixin} = Plugin

{clazz, clazzMix, clazzMixInit} = do ->
  clazz = -> Backbone.Model.extend arguments...

  factory = (proto = {}, init = no) ->
    NewClass = clazz proto
    mixin NewClass::, init
    NewClass

  clazz: clazz
  clazzMix: (proto) -> factory proto, no
  clazzMixInit: (proto) -> factory proto, yes

# global vars to be used from inside tests and hooks
config = null
Model = null

# wrapper for function passed to "describe",
# to avoid same and same setup/teardown boilerplate code when test should do changes in plugin config
configurable = (testSuite) -> ->
  prevConfig = null

  before -> prevConfig = _.clone Plugin.config
  beforeEach -> {config} = Plugin
  afterEach -> Plugin.config = _.clone prevConfig
  after -> config = null

  testSuite()

before -> Model = null
after  -> Model = null