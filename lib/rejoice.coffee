#
# Rejoice loader -- development use only
#

# like File.join, but in JavaScript and for URLs
joinURLs = (a, b) ->
  return a if !b
  return b if !a
  return b if b.match(/^\//) || b.match(/^https?:/)
  return b if a == '.'
  a = "#{a}/" unless a.match(/\/$/)
  return "#{a}#{b}"

# see https://github.com/isaacs/slide-flow-control/blob/master/lib/async-map.js
asyncMap = (list, fn, callback) ->
  return callback(null, []) if list.length == 0

  results     = []
  outstanding = list.length
  anyError    = null

  itemCallback = (err, data) ->
    return if anyError
    return callback(anyError = err) if err

    results.push data
    return callback(null, results) if (--outstanding) == 0

  list.forEach (item) -> fn(item, itemCallback)
  undefined

# insert a <SCRIPT> tag and wait till it gets executed
executeScriptUsingDOM = (url, callback) ->
  console.log "Rejoice: executing #{url}" if Rejoice.verbose

  script = document.createElement("script");
  script.src = url

  done = no
  script.onload = script.onreadystatechange = ->
    return if done
    if !this.readyState || this.readyState == "loaded" || this.readyState == "complete"
      done = yes
      callback(null)

  head = document.getElementsByTagName("head")[0] || document.documentElement;
  head.insertBefore script, head.firstChild

# AJAX load -- TODO rewrite this to avoid jQuery
loadURL = (url, callback) ->
  jQuery.ajax
    url: url
    dataType: 'text'
    success: (data, textStatus) ->
      callback(null, data)
    error: (xhr, textStatus, errorThrown) ->
      callback(textStatus || errorThrown || 'loadScript error')

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
resolveFQN = (name, baseFQN) ->
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
    return name

# to provide a global 'exports' object and to track 'require' calls, we need to execute scripts one by one
newExecutionQueue = ->
  _queue = []
  _busy  = no

  next = ->
    return unless (_busy = _queue.length > 0)

    { url, before, after } = _queue.shift()

    before()
    executeScriptUsingDOM url, (err) ->
      after(err)
      next()

  enqueue = (options) ->
    _queue.push options
    next() unless _busy

  { enqueue }

Rejoice =
  path:    ''
  queue:   newExecutionQueue()
  module:  null
  modules: {}
  verbose: window.location.href.match(/rejoice-verbose=1/)

# set up window.exports
publishGlobals = (module) ->
  if Rejoice.module
    throw "Rejoice assertion error: Rejoice.module != null when loading '#{module.fqn}'"
  Rejoice.module = module
  window.exports = module.exports

# tear down window.exports
unpublishGlobals = (module) ->
  if Rejoice.module isnt module
    throw "Rejoice assertion error: Rejoice.module is '#{Rejoice.module?.fqn}' when finished loading '#{module.fqn}'"
  Rejoice.module = null

  module.exports = window.exports
  delete window.exports

class Module
  constructor: (@fqn) ->
    @exports = {}     # overwritten with window.exports after loading
    @requires = []    # statically parsed list of requires, to compare against require() calls
    @callbacks = []   # multiple modules might be waiting for this module to load

  require: (name) ->
    unless name in @requires
      throw "Rejoice API error: require('#{name}') called from '#{@fqn}', but the call hasn't been found by a regexp"

    fqn = resolveFQN(name, @fqn)
    unless module = Rejoice.modules[fqn]
      throw "Rejoice internal error: module '#{fqn}' require by '#{@fqn}' hasn't been loaded yet"

    return module.exports

  callback: (err) ->
    for cb in @callbacks
      cb(err)
    undefined

# the core of the loader
requireModule = (fqn, callback) ->
  # might be called with or without extension; try to tolerate that
  path = fqn
  path = "#{path}.js" unless path.match(/\.js($|\?)/i)
  fqn  = fqn.replace(/\.js(\?.*)?$/i, '')

  if module = Rejoice.modules[fqn]
    module.callbacks.push callback
    return

  module = Rejoice.modules[fqn] = new Module(fqn)
  module.callbacks.push callback

  url = joinURLs(Rejoice.path, path)  # currently all URLs are relative to a single root

  # first, load the source via AJAX and parse it with a regexp
  loadURL url, (err, data) ->
    if err
      console.log "Rejoice: error loading URL #{url} -- #{err}" if Rejoice.verbose
      return callback(err)

    console.log "Rejoice: loaded URL #{url}" if Rejoice.verbose

    requires = module.requires = findRequireCalls(data)

    # second, load the required modules
    resolveAndRequireModules requires, fqn, (err) ->
      return module.callback(err) if err

      # third, add a <SCRIPT> tag for this module (have to queue it up to avoid clashes)
      Rejoice.queue.enqueue
        url: url
        before: ->
          publishGlobals(module)
        after: (err) ->
          unpublishGlobals(module)
          module.callback(err)

# just a little helper
resolveAndRequireModules = (names, baseFQN, callback) ->
  names = [names] if names.constructor is String
  names = (resolveFQN(name, baseFQN) for name in names)
  asyncMap names, requireModule, callback

# public API -- does not really load anything, all dependencies should have already been
# loaded by the time a module gets executed
require = (name) ->
  unless Rejoice.module
    throw "Rejoice: cannot use 'require' outside of top-level module code"
  Rejoice.module.require(name)

init = ->
  # parse the extra data given in a <script src="rejoice.js">
  initialModules = []
  for script in document.getElementsByTagName("SCRIPT")
    if script.src? and script.src.match(/rejoice\.js/)
      if path = script.getAttribute('data-path')
        Rejoice.path = path
      if initial = script.getAttribute('data-main')
        initial = initial.split(",")
        initialModules = initialModules.concat initial

  console.log "Rejoice: loading main modules #{initialModules.join(', ')} with path '#{Rejoice.path}'" if Rejoice.verbose
  resolveAndRequireModules initialModules, '', (err) ->
    if err
      console.log "Rejoice: error loading some modules -- #{err}" if Rejoice.verbose
    else
      console.log "Rejoice: done." if Rejoice.verbose

window.Rejoice = Rejoice
window.require = require

init()
