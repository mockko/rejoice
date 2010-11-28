require 'rake/clean'
require 'fileutils'

RAKEFILE = 'Rakefile'


###############################################################################
#  CoffeeScript

COFFEE = FileList['**/*.coffee']

JS  = COFFEE.ext('js')

CLOBBER.include(JS)

rule '.js' => '.coffee' do |t|
   puts "COFFEE #{t.source}"
   sh 'coffee', '-c', t.source
end


###############################################################################
#  watch

desc "Continuously watch for changes and rebuild files"
task :watch => [:default] do
    require 'rubygems'
    require 'fssm'

    def rebuild
        sh 'rake'
        puts "    OK"
    rescue
        nil
    end

    begin
        FSSM.monitor(nil, [RAKEFILE, '**/*.coffee', '**/*.haml', '**/*.less']) do
            update { rebuild }
            delete { rebuild }
            create { rebuild }
        end
    rescue FSSM::CallbackError => e
        Process.exit
    end
end

task :default => (JS)
