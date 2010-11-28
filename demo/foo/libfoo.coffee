
console.log "Hello from libfoo!"

bar = require './bar/libbar'
bar2 = require 'foo/bar/libbar'

window.exports = "#{bar} || #{bar2}"
