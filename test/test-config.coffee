{mixin} = Backbone.ComputedFields

{clazz, clazzMix, clazzMixInit} = do ->
  clazz = -> Backbone.Model.extend arguments...

  factory = (proto = {}, init = no) ->
    NewClass = clazz proto
    mixin NewClass::, init
    NewClass

  clazz: clazz
  clazzMix: (proto) -> factory proto, no
  clazzMixInit: (proto) -> factory proto, yes