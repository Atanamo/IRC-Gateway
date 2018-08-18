{exec} = require 'child_process'

task 'build', 'Build project from /src/*/*.coffee to /dist/*.js', ->
    invoke 'build-server'
    invoke 'build-webclient'

task 'build-server', 'Compile server from /src/server/*.coffee to /dist/server/*.js', ->
    child = exec 'coffee --output "./dist/server" --compile "./src/server"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

task 'build-webclient', 'Compile and join webclient from /src/webclient/*.coffee to /dist/webclient.js', ->
    child = exec 'coffee --join "./dist/webclient.js" --compile "./src/webclient"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout


task 'watch', 'Build project and watch sources for changes', ->
    invoke 'watch-server'
    invoke 'watch-webclient'

task 'watch-server', 'Build server and watch its sources for changes', ->
    child = exec 'coffee -o "./dist/server" -wc "./src/server"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

    child.stdout.on 'data', (args...) ->
        console.log args...

task 'watch-webclient', 'Build webclient and watch its sources for changes', ->
    child = exec 'coffee --join "./dist/webclient.js" -wc "./src/webclient"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

    child.stdout.on 'data', (args...) ->
        console.log args...


