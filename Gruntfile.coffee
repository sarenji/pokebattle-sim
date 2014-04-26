{exec} = require('child_process')
crypto = require('crypto')
fs = require('fs')
path = require('path')

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
            "client/app/js/init.coffee"
            "shared/**/*.coffee"
            "client/app/js/models/**/*.coffee"
            "client/app/js/collections/**/*.coffee"
            "client/app/js/views/**/*.coffee"
            "client/app/js/client.coffee"
            "client/app/js/concerns/**/*.coffee"
            "client/app/js/**/*.coffee"
          ]
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
        files: ['**/*.json','!**/node_modules/**']
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
    aws: grunt.file.readJSON("aws_config.json")
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
        dest: 'sim/'
        rename: (dest, src) ->
          contents = fs.readFileSync("public/#{src}")
          hash = crypto.createHash('md5').update(contents).digest('hex')
          extName = path.extname(src)
          "#{dest}#{src[0...-extName.length]}-#{hash}#{extName}"

  grunt.loadNpmTasks('grunt-contrib-jade')
  grunt.loadNpmTasks('grunt-contrib-stylus')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-contrib-cssmin')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-nodemon')
  grunt.loadNpmTasks('grunt-concurrent')
  grunt.loadNpmTasks('grunt-external-daemon')
  grunt.loadNpmTasks('grunt-aws')
  grunt.registerTask('heroku:production', 'concurrent:compile')
  grunt.registerTask('heroku:development', 'concurrent:compile')
  grunt.registerTask('default', ['concurrent:compile', 'concurrent:server'])

  grunt.registerTask 'scrape:pokemon', 'Scrape pokemon data from Veekun', ->
    cmd = ". ./venv/bin/activate && cd ./scrapers/bw && python pokemon.py"
    exec(cmd, this.async())

  grunt.registerTask 'compile:json', 'Compile all data JSON into one file', ->
    fs = require('fs')
    {GenerationJSON} = require './server/generations'
    EventPokemon = require './shared/event_pokemon.json'
    contents = """var Generations = #{JSON.stringify(GenerationJSON)};
    var EventPokemon = #{JSON.stringify(EventPokemon)}"""
    grunt.file.write('./public/js/data.js', contents)

  grunt.registerTask 'assets:deploy', 'Compiles and uploads all assets', ->
    grunt.task.run(['concurrent:compile', 's3:build'])
