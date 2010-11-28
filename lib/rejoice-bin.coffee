
fs       = require 'fs'
sys      = require 'sys'

{ OptionParser } = require 'optparse'

bundler = require '../lib/rejoice/bundler'

options =
  output:  null
  inputs:  []
  libPath: ''

parser = new OptionParser [
  ['-h', '--help', 'Shows help screen']
  ['-I', '--include PATH', 'Adds a directory to the CommonJS include path']
]

parser.on 'help', ->
  sys.puts 'Help'

parser.on 'include', (k, path) ->
  sys.puts "libPath = #{path}"
  options.libPath = path

args = parser.parse process.argv.slice(2)

options.output = args.shift()
options.inputs = args

if options.inputs.length == 0
  sys.puts "rejoice: no input files"
  process.exit 1

sys.puts "Output: #{options.output}"
sys.puts "Inputs: #{options.inputs.join(', ')}"

data = bundler.bundle(options.inputs, options.libPath)

fs.writeFileSync options.output, data, 'utf8'
