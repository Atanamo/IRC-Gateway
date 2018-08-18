{exec} = require 'child_process'

task 'build', 'Build project from /coffee_src/*/*.coffee to /dist/*.js', ->
    child = exec 'coffee --output "./dist" --compile "./src"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

task 'watch', 'Build project and watch sources for changes', ->
    child = exec 'coffee -o "./dist" -wc "./src"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

    child.stdout.on 'data', (args...) ->
        console.log args...

        # Re-bundle the webclient if it changed
        if String(args[0]).replace(/\\/g, '/').indexOf('src/webclient/') > 0
            invoke 'bundle-client'
            console.log 'Rebuilt webclient'

task 'bundle-client', 'Join and compile webclient sources to /dist/webclient.js', ->
    child = exec 'coffee --join "./dist/webclient.js" --compile "./src/webclient"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout

