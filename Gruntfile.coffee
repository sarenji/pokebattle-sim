{exec} = require('child_process')
path = require('path')

assets = require('./assets')

# asset paths (note: without public/ in front)
assetPaths = '''
js/data.js
js/vendor.js
js/templates.js
js/app.js
css/main.css
css/vendor.css
'''.trim().split(/\s+/)
# Transform them using proper slashes
assetPaths = assetPaths.map (assetPath) -> assetPath.split('/').join(path.sep)

module.exports = (grunt) ->
  awsConfigPath = 'aws_config.json'
  if !grunt.file.exists(awsConfigPath)
    grunt.file.copy("#{awsConfigPath}.example", awsConfigPath)

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    concurrent:
      compile: ["jade", "stylus", "coffee", "concat", "cssmin", "compile:json"]
      server:
        tasks: ["nodemon", "watch"]
        options:
          logConcurrentOutput: true
    jade:
      compile:
        options:
          client: true
          compileDebug: false
          processName: (fileName) ->
            templatePath = 'client/views/'
            index = fileName.lastIndexOf(templatePath) + templatePath.length
            fileName = fileName.substr(index)
            fileName.substr(0, fileName.indexOf('.'))
        files:
          "public/js/templates.js": "client/views/**/*.jade"
    stylus:
      compile:
        use: [ require('nib') ]
        files:
          "public/css/main.css": "client/app/css/main.styl"
    coffee:
      compile:
        files:
          'public/js/app.js': [
            "client/app/js/initializers/index.coffee"
            "client/app/js/initializers/**/*.coffee"
            "shared/**/*.coffee"
            "client/app/js/mixins/index.coffee"
            "client/app/js/mixins/**/*.coffee"
            "client/app/js/models/battles/pokemon.coffee"
            "client/app/js/models/battles/team.coffee"
            "client/app/js/models/battles/**/*.coffee"
            "client/app/js/models/chats/**/*.coffee"
            "client/app/js/collections/battles/**/*.coffee"
            "client/app/js/collections/chats/**/*.coffee"
            "client/app/js/views/battles/**/*.coffee"
            "client/app/js/views/teambuilder/**/*.coffee"
            "client/app/js/views/*.coffee"
            "client/app/js/client.coffee"
            "client/app/js/helpers/**/*.coffee"
            "client/app/js/concerns/**/*.coffee"
          ]
          # The replay scripts are typically scoped to a battles/ folder
          'public/js/replays.js': [
            "client/app/js/initializers/index.coffee"
            "client/app/js/initializers/**/*.coffee"
            "shared/**/*.coffee"
            "client/app/js/mixins/index.coffee"
            "client/app/js/mixins/battles/**/*.coffee"
            "client/app/js/models/battles/pokemon.coffee"
            "client/app/js/models/battles/team.coffee"
            "client/app/js/models/battles/**/*.coffee"
            "client/app/js/models/replays/**/*.coffee"
            "client/app/js/collections/replays/**/*.coffee"
            "client/app/js/views/battles/**/*.coffee"
            "client/app/js/views/replays/**/*.coffee"
            "client/app/js/helpers/**/*.coffee"
          ]
    uglify:
      options:
        compress: true
        warn: false
      vendor:
        files:
          'public/js/vendor.js': 'public/js/vendor.js'
      coffee:
        files:
          'public/js/app.js': 'public/js/app.js'
      jade:
        files:
          "public/js/templates.js": "public/js/templates.js"
      json:
        files:
          'public/js/data.js': 'public/js/data.js'
    cssmin:
      combine:
        files:
          'public/css/vendor.css' : [
            'client/vendor/css/**/*.css'
          ]
    concat:
      dist:
        dest: 'public/js/vendor.js'
        src: [
          "client/vendor/js/jquery.js"
          "client/vendor/js/underscore.js"
          "client/vendor/js/backbone.js"
          "client/vendor/js/*.js"
        ]
    external_daemon:
      cmd: "redis-server"
    exec:
      capistrano:
        cmd: 'bundle && bundle exec cap deploy'
      scrape:
        cmd: ". ./venv/bin/activate && cd ./scrapers/bw && python pokemon.py"
    watch:
      templates:
        files: ['client/views/**/*.jade']
        tasks: 'jade'
      css:
        files: ['client/**/*.styl']
        tasks: 'stylus'
      js:
        files: ['client/app/**/*.coffee', 'shared/**/*.coffee']
        tasks: 'coffee'
      vendor:
        files: ['client/vendor/js/**/*.js']
        tasks: 'concat'
      vendor_css:
        files: ['client/vendor/css/**/*.css']
        tasks: 'cssmin'
      json:
        files: [
          '**/*.json'
          '!**/node_modules/**'
          'server/generations'
          'server/commands'
        ]
        tasks: 'compile:json'
    nodemon:
      development:
        options:
          file: "start.js"
          ignoredFiles: [
            '.DS_Store'
            '.git/'
            'pokebattle-db'
            'test/'
            'scrapers/*'
            'client/*'
            'public/*'
            'Gruntfile*'
            'package.json'
            '*.md'
            '*.txt'
            'Capfile'
            'config/*'
            'Gemfile'
            'Gemfile.lock'
            'dump.rdb'
          ]
    aws: grunt.file.readJSON(awsConfigPath)
    s3:
      options:
        accessKeyId: "<%= aws.accessKeyId %>"
        secretAccessKey: "<%= aws.secretAccessKey %>"
        bucket: "s3.pokebattle.com"
        region: 'us-west-2'
      build:
        cwd: "public/"
        expand: true
        src: assetPaths
        dest: assets.S3_ASSET_PREFIX
        rename: (dest, src) ->
          assets.get(src)

  grunt.loadNpmTasks('grunt-contrib-jade')
  grunt.loadNpmTasks('grunt-contrib-stylus')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-contrib-cssmin')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-nodemon')
  grunt.loadNpmTasks('grunt-concurrent')
  grunt.loadNpmTasks('grunt-external-daemon')
  grunt.loadNpmTasks('grunt-aws')
  grunt.loadNpmTasks('grunt-exec')

  grunt.registerTask('compile', ['concurrent:compile', 'uglify'])

  grunt.registerTask('heroku:production', 'compile')
  grunt.registerTask('heroku:development', 'compile')
  grunt.registerTask('default', ['concurrent:compile', 'concurrent:server'])

  grunt.registerTask('scrape:pokemon', 'exec:scrape')

  grunt.registerTask 'compile:json', 'Compile all data JSON into one file', ->
    {GenerationJSON} = require './server/generations'
    EventPokemon = require './shared/event_pokemon.json'
    {HelpDescriptions} = require './server/commands'
    contents = """var Generations = #{JSON.stringify(GenerationJSON)},
    EventPokemon = #{JSON.stringify(EventPokemon)},
    HelpDescriptions = #{JSON.stringify(HelpDescriptions)};"""
    grunt.file.write('./public/js/data.js', contents)

  grunt.registerTask 'deploy:assets', 'Compiles and uploads all assets', ->
    grunt.task.run(['compile', 's3:build'])

  grunt.registerTask('deploy:server', 'exec:capistrano')

  grunt.registerTask('deploy', ['deploy:assets', 'deploy:server'])
