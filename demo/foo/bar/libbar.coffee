
console.log "Hello from libbar!"

lib2 = require('../../lib2')
lib1 = require('lib1')
boz = require('./libboz')

window.exports = "lib1=#{lib1.foo}, lib2=#{lib2.foo}, boz=#{boz}"
