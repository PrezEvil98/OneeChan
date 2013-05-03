module.exports = (grunt) ->

  pkg = grunt.file.readJSON 'package.json'
  concatOptions =
    process:
      data: pkg

  shellOptions =
    stdout:      true
    stderr:      true
    failOnError: true

  # Project configuration.
  grunt.initConfig
    pkg: pkg
    concat:
      coffee:
        options: concatOptions
        src: [
          'src/Default.coffee'
          'src/Globals.coffee'
          'src/$.coffee'
          'src/Main.coffee'
          'src/Config.coffee'
        ]
        dest: 'tmp-<%= pkg.type %>/script.coffee'

      meta:
        options: concatOptions
        files:
          'LICENSE': 'src/meta/metadata.js',

      crx:
        options: concatOptions
        files:
          'builds/crx/manifest.json': 'src/meta/manifest.json'
          'builds/crx/script.js': [
            'src/meta/metadata.js'
            'tmp-<%= pkg.type %>/script.js'
          ]

      userjs:
        options: concatOptions
        src: [
          'src/General/meta/metadata.js'
          'tmp-<%= pkg.type %>/script.js'
        ]
        dest: 'builds/<%= pkg.name %>.js'

      userscript:
        options: concatOptions
        files:
          'builds/<%= pkg.name %>.meta.js': 'src/meta/metadata.js'
          'builds/<%= pkg.name %>.user.js': [
            'src/meta/metadata.js'
            'tmp-<%= pkg.type %>/script.js'
          ]

    copy:
      crx:
        src:    'src/img/*.png'
        dest:   'builds/crx/'
        expand:  true
        flatten: true

    coffee:
      script:
        src:  'tmp-<%= pkg.type %>/script.coffee'
        dest: 'tmp-<%= pkg.type %>/script.js'

    concurrent:
      build: [
        'build-crx'
        'build-userjs'
        'build-userscript'
      ]

    shell:
      commit:
        options: shellOptions
        command: [
          'git checkout <%= pkg.meta.mainBranch %>',
          'git commit -am "Release <%= pkg.meta.name %> v<%= pkg.version %>."',
          'git tag -a <%= pkg.version %> -m "<%= pkg.meta.name %> v<%= pkg.version %>."',
          'git tag -af stable -m "<%= pkg.meta.name %> v<%= pkg.version %>."'
        ].join(' && ')
        stdout: true

      push:
        options: shellOptions
        command: 'git push origin --tags -f && git push origin --all' 

    watch:
      all:
        options:
          interrupt: true
        files: [
          'Gruntfile.coffee'
          'package.json'
          'src/**/*'
        ]
        tasks: 'build'

    compress:
      crx:
        options:
          archive: 'builds/4chan-X.zip'
          level: 9
          pretty: true
        expand: true
        cwd: 'builds/crx/'
        src: '**'

    clean:
      builds:        'builds'
      tmpcrx:        'tmp-crx'
      tmpuserjs:     'tmp-userjs'
      tmpuserscript: 'tmp-userscript'

  grunt.loadNpmTasks 'grunt-bump'
  grunt.loadNpmTasks 'grunt-concurrent'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-compress'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-shell'

  grunt.registerTask 'default', [
    'build'
  ]

  grunt.registerTask 'set-build', 'Set the build type variable', (type) ->
    pkg.type = type;
    grunt.log.ok 'pkg.type = %s', type

  grunt.registerTask 'build', [
    'concurrent:build'
  ]

  grunt.registerTask 'build-crx', [
    'set-build:crx'
    'concat:coffee'
    'coffee:script'
    'concat:crx'
    'copy:crx'
    'clean:tmpcrx'
  ]

  grunt.registerTask 'build-userjs', [
    'set-build:userjs'
    'concat:coffee'
    'coffee:script'
    'concat:userjs'
    'clean:tmpuserjs'
  ]

  grunt.registerTask 'build-userscript', [
    'set-build:userscript'
    'concat:coffee'
    'coffee:script'
    'concat:userscript'
    'clean:tmpuserscript'
  ]

  grunt.registerTask 'release', [
    'default'
    'compress:crx'
    'shell:commit'
    'shell:push'
  ]

  grunt.registerTask 'patch',   [
    'bump'
    'reloadPkg'
    'updcl:3'
  ]

  grunt.registerTask 'minor',   [
    'bump:minor'
    'reloadPkg'
    'updcl:2'
  ]

  grunt.registerTask 'major',   [
    'bump:major'
    'reloadPkg'
    'updcl:1'
  ]

  grunt.registerTask 'reloadPkg', 'Reload the package', ->
    # Update the `pkg` object with the new version.
    pkg = grunt.file.readJSON('package.json')
    grunt.config.data.pkg = concatOptions.process.data = pkg
    grunt.log.ok('pkg reloaded.')

  grunt.registerTask 'updcl',   'Update the changelog', (i) ->
    # i is the number of #s for markdown.
    version = []
    version.length = +i + 1
    version = version.join('#') + ' ' + pkg.version + ' - ' + grunt.template.today('yyyy-mm-dd')
    grunt.file.write 'CHANGELOG.md', version + '\n' + grunt.file.read('CHANGELOG.md')
    grunt.log.ok     'Changelog updated for v' + pkg.version + '.'