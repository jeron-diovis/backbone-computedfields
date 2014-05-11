// TODO: configurable serializeability for computed
// TODO: built-in computed? (like full name)
// TODO: allow to manually refresh depsMap, for cases when config was updatedin runtime


var ComputedFields = {};

ComputedFields.config = {
    configPropName: 'computed',
    funcDepsPrefix: '=',
    shortDepsNameSeparator: /\s+<\s+/,
    shortDepsSplitter: /\s+/,
    stringDepsSplitter: /\s+/,
    proxyFieldPattern: /^&$/ // not sure that regexp is really needed for this...)
};

// ---------------------------------------------------

// shortcut
var cfg = function(opt) { return ComputedFields.config[opt]; };

var sandboxContext = { isSandboxContext: true };
var depsMapPropName = '_computedFieldsDependenciesMap';
var endlessLoopMaxIterations = 50;

// ---------------------------------------------------

ComputedFields.mixin = function(model, isInstance) {
    for (var name in wrappers) {
        var backup = model[name];
        model[name] = _.wrap(model[name], wrappers[name]);
        if (name === 'get') {
            model[name].origin = backup;
        }
    }

    if (isInstance && utils.hasComputed(model)) {
        methods.initialize.call(model);
    }

    return model;
};

// ---------------------------------------------------

// wrappers for model's methods with same names. Will replace model's methods
var wrappers = {

    "get": function(origin, attr) {
        if (utils.isComputed(this, attr)) {
            return methods.get.call(this, attr);
        } else {
            return origin.call(this, attr);
        }
    },

    "set": function(origin, key, val, options) {
        // standard backbone 'set' header
        if (key == null) { return this; }

        var attrs;
        if (typeof key === 'object') {
            attrs = key;
            options = val;
        } else {
            (attrs = {})[key] = val;
        }
        options || (options = {});
        //

        // unsetting is not our job
        if (options.unset) { return origin.call(this, attrs, options); }

        if (!utils.hasComputed(this)) {
            return origin.call(this, key, val, options);
        }

        // check for initialization here to handle very first 'set' call from model's constructor
        if (!utils.isDepsMapInitialized(this)) {
            methods.initialize.call(this);
        }

        attrs = methods.set.call(this, attrs, options);

        // actually set attributes:
        var result = origin.call(this, attrs.direct, options);

        // now need to remove virtuals from 'attributes' hash:

        // little trick to prevent '_previousAttributes' from being updated
        var changing = this._changing;
        this._changing = true;

        for (var i = 0; i < attrs.virtual.length; i++) {
            this.unset(attrs.virtual[i], { silent: true, validate: false });
        }
        // restore prev 'changing' state
        this._changing = changing;

        return result;
    }

    // TODO: implement
    /*toJSON: function(origin, options) {
        return origin.call(this, options);
    }*/
};

// ---------------------------------------------------

// what should be wrapped by corresponding wrappers
// always called in model's context
var methods = {

    initialize: function () {
        var model = this,
            config = utils.getComputedConfig(model),
            storage = utils.getDepsMapStorage(model);

        var dependenciesMap = {};

        for (var attr in config) {
            var field = config[attr];

            if (!(_.has(field, 'get') || _.has(field, 'set'))) {
                throw new Error('Computed fields: field "' + attr + '" is useless - no getter and no setter defined');
            }

            // TODO: short syntax for dependencies ("attr < dep1 dep2")
            // TODO: short syntax for getter (when getter only)

            field.name = attr;
            field.depends = methods.parseDeps.call(model, field);

            var deps = field.depends.attrs;
            for (var i = 0; i < deps.length; i++) {
                var dependent = deps[i];
                (dependenciesMap[dependent] || (dependenciesMap[dependent] = [])).push(attr);
            }
        }

        utils.ensureValidDependencies(config);

        storage[cfg('configPropName')] = config;
        storage[depsMapPropName] = dependenciesMap;

        return this;
    },

    "get": function (attr) {
        var model = this,
            config = utils.getComputedConfig(model),
            field = config[attr];

        if (!field.get) {
            return model.get.origin.call(model, attr);
        }

        var isProxy = utils.isProxyField(field),
            deps;

        if (isProxy || utils.hasDeps(field)) {
            deps = utils.resolveGetterDeps(model, field);
            return field.get.apply(sandboxContext, deps);
        } else {
            return field.get.call(sandboxContext);
        }
    },

    // Only prepares attributes to be set. Does not actually perform setting.
    "set": function (attrs, options) {
        var model = this,
            config = utils.getComputedConfig(model),
            depsMap = model[depsMapPropName],

            virtualAttrs = [],
            preparedAttrs = {},
            validationMap = {},
            cascadeAttrs, preparedInIteration,
            attr, value, attrResult,
            setter, setterResult,
            field, deps,
            isProxy,

            iteration = 0;

        while (true) {
            if (++iteration > endlessLoopMaxIterations) throw new Error("INFINITY");

            cascadeAttrs = {};
            preparedInIteration = {};
            for (attr in attrs) {
                value = attrs[attr];

                attrResult = {};

                // simple attrs are processed as usual
                if (!utils.isComputed(model, attr, config)) {
                    attrResult[attr] = value;
                } else {
                    // let's deal with computed attrs:
                    field = config[attr];
                    setter = field.set;
                    isProxy = utils.isProxyField(field);

                    // if setter is explicitly disabled, this attribute cannot be set at all
                    if (setter === false || (setter == null && !isProxy)) {
                        continue;
                    } else {
                        setterResult = (setter == null || setter === true) ? value : setter.call(sandboxContext, value, options);

                        // 'proxy' field means that is is modified on setting - so save setterResult in this case, and it's value will appear in 'change' event
                        // in any other case new attribute value will be same as passed to 'set'
                        attrResult[attr] = isProxy ? setterResult : value;

                        // unless field is proxy, it is 'virtual' - it can't be saved in 'attributes' hash (unless setter explicitly allows it)
                        // it still will be passed to origin 'set' - to be validated and to trigger 'change' event - but after that it will be removed from 'attributes'
                        if (!(isProxy || setter === true)) {
                            virtualAttrs.push(attr);
                        }

                        // virtual attributes can only update it's dependencies:
                        if (!isProxy && typeof setter === 'function' && utils.hasAttrDeps(field)) {

                            // note, that values for dependencies will NOT yet be added to 'prepared' list - as they now must also me checked recursively:

                            deps = utils.getAttrDeps(field);
                            // for fields with single dependency any returned value is considered that dependency value
                            if (deps.length === 1) {
                                cascadeAttrs[deps[0]] = setterResult;
                            } else {
                                // otherwise value must be array or an object, which will be mapped to dependencies list
                                if (_.isArray(setterResult)) {
                                    setterResult = _.object(deps, setterResult);
                                } else if (_.isObject(setterResult)) {
                                    setterResult = _.pick(setterResult, deps);
                                } else {
                                    throw new Error('Computed fields: field "' + attr + "' depends from following attrs: " + deps.join(",") + ", so it's setter must return array, or object with corresponding keys.");
                                }
                                _.extend(cascadeAttrs, setterResult);
                            }
                        }
                    }
                }

                // save processed attr to be passed to origin 'set'
                _.extend(preparedInIteration, attrResult);
                _.extend(preparedAttrs, preparedInIteration);

                // and save additional validation info
                utils.extendValidationMap(validationMap, attr, attrResult);
                utils.extendValidationMap(validationMap, attr, cascadeAttrs);
            }

            utils.ensureSetterConsistency(validationMap);

            // if some attributes should be directly updated by another setters, process them first:
            if (!_.isEmpty(cascadeAttrs)) {
                attrs = cascadeAttrs;
            } else {
                // when all directly set attributes resolved, check whether there are some cascadely dependent attributes
                // resolve them recursively until cascade is exhausted
                var cascade = utils.buildDepsCascade(_.keys(preparedInIteration), config, depsMap);
                if (cascade.length > 0) {
                    cascadeAttrs = utils.resolveDepsCascade(cascade, preparedAttrs, model, config);
                    attrs = cascadeAttrs;
                } else {
                    break;
                }
            }
        }

        return {
            direct: preparedAttrs,
            virtual: virtualAttrs.length === 1 ? virtualAttrs : _.uniq(virtualAttrs)
        };
    },

    toJSON: function (options) {
        // TODO: implement
    },

    parseDeps: function (field) {
        var model = this;

        var parsed = {
            attrs: [],
            common: []
        };

        if (!field.depends) {
            return parsed;
        }

        var i, deps, dependency,
            funcPrefix = cfg('funcDepsPrefix'),
            proxyFieldPattern = cfg('proxyFieldPattern'),
            stringDepsSplitter = cfg('stringDepsSplitter');

        deps = field.depends;
        if (typeof deps === 'string') {
            deps = deps.split(stringDepsSplitter);
        } else if (typeof deps === 'function') {
            deps = [deps];
        }

        for (i = 0; i < deps.length; i++) {
            dependency = deps[i];
            if (typeof dependency === 'string') {
                if (dependency.indexOf(funcPrefix) === 0) {
                    dependency = model[dependency.slice(funcPrefix.length)];
                    parsed.common.push(dependency);
                } else {
                    // allow self-ref both by shortcut and by name (to prevent circular dependencies)
                    if (proxyFieldPattern.test(dependency) || dependency === field.name) {
                        parsed.proxyIndex = i;
                    } else {
                        parsed.attrs.push(dependency);
                        parsed.common.push(dependency);
                    }
                }
            } else if (typeof dependency === 'function') {
                parsed.common.push(dependency);
            } else {
                throw new Error('Field dependency must be either function or string');
            }
        }

        return parsed;
    }
};

// ---------------------------------------------------

// Utilities.
// Actually, all these functions could be methods of 'ComputedFields' class.
// Should not be used with changing context
var utils = {

    getComputedConfig: function (model) {
        return _.result(model, cfg('configPropName')) || {};
    },


    hasComputed: function (model, config) {
        return !_.isEmpty(config || utils.getComputedConfig(model));
    },

    isComputed: function (model, attr, config) {
        return attr in (config || utils.getComputedConfig(model));
    },


    hasDeps: function (field) {
        return field.depends.common.length > 0;
    },

    getDeps: function (field) {
        return field.depends.common;
    },


    hasAttrDeps: function (field) {
        return field.depends.attrs.length > 0;
    },

    getAttrDeps: function (field) {
      return field.depends.attrs;
    },


    getDepsMapStorage: function (model) {
        return _.has(model, cfg('configPropName')) ? model : model.constructor.prototype;
    },

    isDepsMapInitialized: function (model) {
        return _.has(utils.getDepsMapStorage(model), depsMapPropName);
    },


    isProxyField: function (field) {
        return field.depends.proxyIndex != null || field.get == null;
    },

    buildDepsCascade: function (attrs, config, depsMap) {
        var i, j, len,
            attr,
            resolvedAttrs = attrs.slice(),
            deps,
            push = [].push,
            list, result = [],
            depsCache = {},

            iteration = 0;

        while (true) {
            if (++iteration > endlessLoopMaxIterations) throw new Error('INFINITY');
            list = [];
            for (i = 0; i < attrs.length; i++) {
                attr = attrs[i];
                if (attr in depsMap) {
                    deps = _.difference(depsMap[attr], resolvedAttrs);
                    // 'flatten'. Inline, and use 'if' for little speed up (http://jsperf.com/apply-vs-call-if)
                    if (deps.length === 1) { push.call(list, deps[0]); } else { push.apply(list, deps); }
                }
            }

            if (list.length === 0) {
                break;
            } else {
                result.push(list);
                attrs = list;
            }
        }

        // uniq each list, and bubble attrs with most of deps to the end
        for (i = 0; i < result.length; i++) {
            list = result[i];
            switch (list.length) {
                case 2: if (list[0] === list[1]) { list.pop(); /* no break! */ } else { break; }
                case 1: continue;
                default: result[i] = list = _.uniq(list);
            }
            for (j = list.length - 1; j >= 0; j--) {
                attr = list[j];
                deps = depsCache[attr] || (depsCache[attr] = utils.getAttrDeps(config[attr]));
                if (deps.length === 0) {
                    continue;
                }
                len = list.length;
                if (len === 2 ? _.indexOf(deps, list[1 - j]) >= 0 : _.intersection(deps, list).length > 0) {
                    if (i === result.length - 1) {
                        result.push([]);
                    }
                    result[i + 1].push(j === len - 1 ? list.pop() : list.splice(j, 1)[0]);
                }
            }
        }

        return result;
    },

    resolveDepsCascade: function (cascade, resolved, model, config) {
        var i, j, attr, list, field,
            getterArgs, getterResult,
            result = {};

        resolved = _.clone(resolved);

        config || (config = utils.getComputedConfig(model));

        for (i = 0; i < cascade.length; i++) {
            list = cascade[i];
            for (j = 0; j < list.length; j++) {
                attr = list[j];
                field = config[attr];
                if (field.get) {
                    getterArgs = utils.resolveGetterDeps(model, field, resolved);
                    getterResult = field.get.apply(sandboxContext, getterArgs);
                } else {
                    getterResult = (attr in resolved) ? resolved[attr] : model.get(attr);
                }
                result[attr] = resolved[attr] = getterResult;
            }
        }

        return result;
    },

    resolveGetterDeps: function (model, field, subst) {
        var i, deps, dependency,
            isProxy = utils.isProxyField(field),
            resolvedDeps = [];

        subst || (subst = {});

        deps = utils.getDeps(field);
        for (i = 0; i < deps.length; i++) {
            dependency = deps[i];
            if (typeof dependency === 'string') {
                if (dependency in subst) {
                    dependency = subst[dependency];
                } else {
                    dependency = model.get(dependency);
                }
            } else {
                dependency = dependency.call(model, field.name);
            }
            resolvedDeps.push(dependency);
        }
        if (isProxy) {
            resolvedDeps.splice(field.depends.proxyIndex, 0, model.get.origin.call(model, field.name));
        }
        return resolvedDeps;
    },

    extendValidationMap: function (map, srcAttr, attrs) {
        var attr, value;
        for (attr in attrs) {
            value = attrs[attr];
            map[attr] || (map[attr] = {});
            map[attr][srcAttr] = attrs[attr];
        }
        return map;
    },

    ensureValidDependencies: function (config) {
        var attr, field, deps, newDeps,
            iteration = 0;
        for (attr in config) {
            field = config[attr];
            if (!utils.hasAttrDeps(field)) {
                continue;
            }
            deps = field.depends.attrs;
            do {
                if (++iteration > endlessLoopMaxIterations) throw new Error("INFINITY");

                newDeps = _.chain(deps).map(function(attr) {
                    var field = config[attr];
                    return field ? field.depends.attrs : [];
                }).flatten(true).uniq().value();

                if (_.indexOf(newDeps, attr) >=0) {
                    throw new Error("Computed fields: circular dependency detected between '" + attr + "' and one of these attributes: " + deps.join(","));
                }

                deps = newDeps;
            } while (newDeps.length > 0);
        }
        return true;
    },

    ensureSetterConsistency: function (preparedAttrs) {
        var attr, sources, msg, isShouldBeChecked, isValid;
        for (attr in preparedAttrs) {
            sources = preparedAttrs[attr];
            isShouldBeChecked = _.size(sources) > 1;
            if (isShouldBeChecked) {
                isValid = _.chain(sources).values().flatten(true).map(utils.serialize).uniq().value().length === 1;
                if (!isValid) {
                    msg = "Computed fields: can't set attribute '" + attr + "' as it is inconsistent - several setters returns different values: \n" +
                        _.map(sources, function (value, srcAttr) {
                            return srcAttr + ": " + value;
                        }).join("\n");

                    throw new Error(msg);
                }
            }
        }
        return true;
    },

    serialize: function (obj) {
        if (!_.isObject(obj)) {
            return obj;
        } else if (typeof obj.serialize === 'function') {
            return obj.serialize();
        } else if (typeof obj.toJSON === 'function') {
            return obj.toJSON();
        } else {
            return JSON.stringify(obj);
        }
    }
};

// -------------------------------

if (Object.freeze) {
    Object.freeze(sandboxContext);
}
if (Object.seal) {
    Object.seal(ComputedFields);
}

