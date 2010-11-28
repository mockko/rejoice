fs  = require 'fs'
sys = require 'sys'


# like File.join, but in JavaScript and for URLs
joinURLs = (a, b) ->
  return a if !b
  return b if !a
  return b if b.match(/^\//) || b.match(/^https?:/)
  return b if a == '.'
  a = "#{a}/" unless a.match(/\/$/)
  return "#{a}#{b}"


# detect require('xxx') calls using regular expressions
findRequireCalls = (source) ->
  requires = []
  for callSite in source.match(/require\s*\(\s*['"]([^'")]*?)['"]\s*\)/g) || []
    if m   =    callSite.match(/require\s*\(\s*['"]([^'")]*?)['"]\s*\)/)
      requires.push m[1]
  requires

# given 'abc/def/ghi', returns 'abc/def'; given 'xyz', returns ''
packageNameOf = (fqn) ->
  if (result = fqn.replace(/\/[^\/]*$/, '')) != fqn
    return result
  else
    return ''

# resolves the given module name relative to another fully-qualified module name
resolveFQN = (name, baseFQN, libPath) ->
  if name.match(/^\./)
    prev   = ''
    result = joinURLs(packageNameOf(baseFQN), name)

    while prev != result
      prev = result
      result = result.replace(/(^|\/)\.(\/|$)/g, '$1')
      result = result.replace(/(^|\/)[^\/]+\/\.\.(\/|$)/g, '$1')
    if result.match(/(^|\/)\.\.(\/|$)/)
      throw "invalid path '#{name}' relative to FQN '#{baseFQN}': not enough subpackages to resolve '..'"
    return result
  else
    return joinURLs(libPath, name)

resolveExtension = (path) ->
  unless path.match(/\.js$/i)
    path = "#{path}.js"
  path

resolveModule = (name, basePath, libPath) ->
  fqn = resolveFQN(name, basePath, libPath)
  sys.puts "resolveFQN(#{name}, #{basePath}) == #{fqn}"
  resolveExtension(fqn)

class Module
  constructor: (@path) ->
    @id = "__" + @path.replace(/[@.\/]/g, '_')

class Bundler
  constructor: (@libPath) ->
    @modules = {}
    @output = []

  lookup: (path) ->

  bundle: (path) ->
    return if @modules[path]
    module = @modules[path] = new Module(path)

    sys.puts "Reading #{path}"
    data = fs.readFileSync(path, 'utf8')

    requires = findRequireCalls(data)
    this.bundle(resolveModule(rq, path, @libPath)) for rq in requires

    for callSite in data.match(/require\s*\(\s*['"]([^'")]*?)['"]\s*\)/g) || []
      if m  =   callSite.match(/require\s*\(\s*['"]([^'")]*?)['"]\s*\)/)
        rq = m[1]
        rqPath = resolveModule(rq, path, @libPath)
        if m = @modules[rqPath]
          data = data.replace(callSite, m.id)

    @output.push data.replace(/\b(window\.)?exports\b/g, module.id)

    undefined
    
  result: ->
    @output.unshift "var " + ("#{module.id} = {}" for k, module of @modules).join(", ") + ";"
    @output.unshift "(function() {"
    @output.push "})();"
    return @output.join("\n")

exports.bundle = (inputs, libPath) ->
  bundler = new Bundler(libPath)
  bundler.bundle(resolveExtension(input)) for input in inputs
  return bundler.result()
