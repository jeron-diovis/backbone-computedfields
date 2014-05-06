{mixin} = Backbone.ComputedFields

# shortcut for most of tests, where we want to test classes with mixins
clazz = (proto = {}) ->
  NewClass = Backbone.Model.extend proto
  mixin NewClass::
  NewClass