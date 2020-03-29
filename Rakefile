require 'rake/testtask'
require 'yard'

Rake::TestTask.new :test do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = false
  t.warning = false
end

YARD::Rake::YardocTask.new :yard do |t|
  t.files   = ['lib/**/*.rb']
  t.options = ['--private', '--output-dir', 'docs']
  t.stats_options = ['--list-undoc']
 end

task :default => [:test]
