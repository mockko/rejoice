
lib1 = require 'lib1'
lib2 = require 'lib2'
foo  = require 'foo/libfoo'
bar  = require './foo/bar/libbar'

console.log "Hello from demo.coffee: #{lib1.foo} / #{lib2.foo}!"
console.log "bar: #{bar}"
console.log "foo: #{foo}"
