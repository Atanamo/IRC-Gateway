{exec} = require 'child_process'

task 'build', 'Build project from coffee_src/*/*.coffee to src_js/*.js', ->
    child = exec 'coffee --output "./src_js" --compile "./src_coffee"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

task 'watch', 'Build project and watch sources for changes', ->
    child = exec 'coffee -o "./src_js" -wc "./src_coffee"', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr

    child.stdout.on 'data', (args...) -> 
        console.log args...