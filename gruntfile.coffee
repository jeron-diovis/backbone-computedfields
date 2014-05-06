module.exports = (grunt) ->
  require("matchdep").filterDev("grunt-*").forEach grunt.loadNpmTasks

  cfg = grunt.config

  grunt.initConfig {

    pkg:
      name: "backbone.computedfields"
      dist: "dist"
      src: "src/<%=pkg.name %>.js"
      main: "<%=pkg.dist %>/<%=pkg.name %>.js"
      tests: ["test/spec/**/*.{js,coffee}", "test/test-config.coffee"]


    bower:
      install:
        options:
          verbose: yes
          cleanup: yes
          layout: -> "" # skip by-package grouping


    rig:
      browser:
        src: "src/wrappers/browser.js"
        dest: "<%=pkg.main %>"
      amd:
        src: "src/wrappers/amd.js"
        dest: "<%=pkg.dist %>/<%= pkg.name %>-amd.js"
      amd_export:
        src: "src/wrappers/amd_export.js"
        dest: "<%=pkg.dist %>/<%= pkg.name %>-amd-export.js"


    uglify:
      all:
        expand: yes
        cwd: "<%=pkg.dist %>"
        src: "*.js"
        dest: "<%=pkg.dist %>/min"
        rename: (dest, src) -> ext = ".js"; "#{dest}/#{src.slice(0, -ext.length)}.min#{ext}"


    karma:
      options:
        configFile: "karma.conf.coffee"
        basePath: "."
        files: [
          # do not use {brackets,expansion} as it does not guarantees order
          "lib/underscore.js"
          "lib/backbone.js"
          "<%=pkg.main %>"
          "<%=pkg.tests %>"
        ]

      watch:
        options:
          background: yes

      CI:
        options:
          singleRun: yes


    watch:
      gruntfile: files: "gruntfile.coffee"

      rig:
        files: "<%=pkg.src %>"
        tasks: ["rig"]

      karma:
        files: [
          "<%=pkg.main %>"
          "<%=pkg.tests %>"
        ]
        tasks: ["karma:watch:run"]
  }

  # end of initConfig

  grunt.registerTask "start", ["karma:watch:start", "watch"]
  grunt.registerTask "test", "karma:CI"
  grunt.registerTask "build", ["rig", "uglify"]
  grunt.registerTask "default", ["build"]