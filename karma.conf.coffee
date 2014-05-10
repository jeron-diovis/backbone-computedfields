# Karma configuration
# Generated on Sun May 04 2014 15:00:27 GMT+0300 (EEST)

# .coffee config requires coffee-script dependency
module.exports = (config) ->
  config.set {

    # base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: "test"

    # frameworks to use
    # available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ["mocha", "chai", "sinon"]

    # list of files / patterns to load in the browser
    # File paths are duplicated in Gruntfile. Here they are to allow to run tests configuration with external tools
    files: [
      "../lib/underscore.js"
      "../lib/backbone.js"
      "../dist/backbone.computedfields.js"
      "test-config.coffee"
      "spec/**/*.{js,coffee}"
    ]

    # list of files to exclude
    exclude: []

    # preprocess matching files before serving them to the browser
    # available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors:
      "**/*.coffee": "coffee"


    # test results reporter to use
    # possible values: 'dots', 'progress'
    # available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ["progress"]

    # web server port
    port: 9876

    # enable / disable colors in the output (reporters and logs)
    colors: true

    # level of logging
    # possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO

    # enable / disable watching file and executing tests whenever any file changes
    autoWatch: true

    # start these browsers
    # available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: ["Chrome"]

    # Continuous Integration mode
    # if true, Karma captures browsers, runs the tests and exits
    singleRun: false
  }