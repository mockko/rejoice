Rejoice: (WORK IN PROGRESS) CommonJS module (re-)loader for the browser
=======================================================================

Rejoice is a no-fuss CommonJS loader for the browser, built around two core assumptions:

1. CommonJS modules are for development only — combine all scripts into a single file for production use.

2. Full page reloads suck, JavaScript should be reloaded live.

Rejoice thus provides two separate components:

* Rejoice Loader is used for development and loads the modules using debugger-friendly separate SCRIPT tags.

* Rejoice Bundler combines all modules into a single file for further minification.


Work in progress
----------------

Right now, Rejoice can only load modules, only in WebKit browsers, and requires jQuery to be available.


Loader
------

Rejoice loads unwrapped CommonJS modules (the same modules that node.js uses), like this one:

    var foo = require('./foo');
    var bar = require('./bar');

    exports.usefulFunc = function(a, b) {
      foo.doSometing(a);
      return bar.doSomethingElse(b);
    };

A set of top-level scripts to load and the root directory for all JavaScripts is specified inside the SCRIPT tag that loads Rejoice:

    <script data-path="." data-main="demo.js,another.js" src="../lib/rejoice.js"></script>


Reloader
--------

When used with LiveReload, Rejoice will soon automatically reload JavaScript modules and other modules that depend on them. Sensible reloading will require some help from the module author.


Bundler
-------

Bundler is not implemented yet.


License & Copyright
-------------------

This software is distributed under the MIT license.

© 2010, Andrey Tarantsov <andreyvit@gmail.com>
