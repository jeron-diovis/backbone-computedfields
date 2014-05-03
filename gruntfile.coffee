module.exports = (grunt) ->
  require("matchdep").filterDev("grunt-*").forEach grunt.loadNpmTasks

  cfg = grunt.config

  grunt.initConfig {

    pkg:
      name: "backbone-computedfields"

    rig:
      browser:
        src: 'src/wrappers/browser.js'
        dest: 'dist/<%= pkg.name %>.js'
      amd:
        src: 'src/wrappers/amd.js'
        dest: 'dist/<%= pkg.name %>-amd.js'
      amd_export:
        src: 'src/wrappers/amd_export.js'
        dest: 'dist/<%= pkg.name %>-amd-export.js'

  }

  # end of initConfig