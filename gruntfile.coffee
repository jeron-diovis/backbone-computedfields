module.exports = (grunt) ->
  require("matchdep").filterDev("grunt-*").forEach grunt.loadNpmTasks

  cfg = grunt.config

  grunt.initConfig {

    pkg:
      name: "backbone-computedfields"
      dist: "dist"

    rig:
      browser:
        src: "src/wrappers/browser.js"
        dest: "<%=pkg.dist %>/<%= pkg.name %>.js"
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

  }

  # end of initConfig

  grunt.registerTask "build", ["rig", "uglify"]
  grunt.registerTask "default", ["build"]