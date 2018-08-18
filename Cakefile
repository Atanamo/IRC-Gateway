browserify = require('browserify')
fs = require('fs')
{exec} = require 'child_process'


deleteFolder = (path) ->
    return unless fs.existsSync(path)
    fs.readdirSync(path).forEach (file, index) ->
        fs.unlinkSync("#{path}/#{file}")
    fs.rmdirSync(path)


SRC_DIR_SERVER = './src/server'
DIST_DIR_SERVER = './dist/server'

SRC_DIR_CLIENT = './src/webclient'
DIST_DIR_CLIENT = './dist/webclient.tmp/'

CLIENT_BUNDLE_MAIN = "#{DIST_DIR_CLIENT}/index.js"
DIST_CLIENT_BUNDLE = "#{__dirname}/dist/webclient.js"


task 'build', 'Build project from /src/*/*.coffee to /dist/*.js', ->
    invoke 'build-server'
    invoke 'build-webclient'

task 'build-server', 'Compile server from /src/server/*.coffee to /dist/server/*.js', ->
    child = exec "coffee --output #{DIST_DIR_SERVER} --compile #{SRC_DIR_SERVER}", (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

task 'build-webclient', 'Compile and join webclient from /src/webclient/*.coffee to /dist/webclient.js', ->
    child = exec "coffee --output #{DIST_DIR_CLIENT} --compile #{SRC_DIR_CLIENT}", (err, stdout, stderr) ->
        throw err if err
        console.log stdout
        invoke 'bundle-webclient'


task 'watch', 'Build project and watch sources for changes', ->
    invoke 'watch-server'
    invoke 'watch-webclient'

task 'watch-server', 'Build server and watch its sources for changes', ->
    child = exec "coffee -o #{DIST_DIR_SERVER} -wc #{SRC_DIR_SERVER}", (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

    child.stdout.on 'data', (args...) ->
        console.log args...

task 'watch-webclient', 'Build webclient and watch its sources for changes', ->
    child = exec "coffee -o #{DIST_DIR_CLIENT} -wc #{SRC_DIR_CLIENT}", (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

    child.stdout.on 'data', (args...) ->
        console.log args...
        invoke 'bundle-webclient'


task 'bundle-webclient', 'Bundle compiled sources of webclient', ->
    # Stream for output file
    outFileStream = fs.createWriteStream(DIST_CLIENT_BUNDLE)
    outFileStream.on 'finish', ->
        console.log('Finished webclient bundle:', DIST_CLIENT_BUNDLE)

    # Bundle via browserify
    bundler = browserify CLIENT_BUNDLE_MAIN,
        standalone: 'GatewayChat'  # Name of global main class in window object
    bundler = bundler.bundle (error, result) ->
        throw error if error?
    bundler.pipe(outFileStream)


task 'del-temp-files', 'Delete temporary files', ->
    deleteFolder(DIST_DIR_CLIENT)
    console.log('Removed temporary files:', DIST_DIR_CLIENT)

