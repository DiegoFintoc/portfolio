require 'rspec/sorbet'
require 'rubocop'
require 'rubocop/rspec/support'
require 'sorbet-runtime'
require 'zeitwerk'

loader = Zeitwerk::Loader.new
%w[values].each do |dir|
  loader.push_dir(File.expand_path("../app/#{dir}", __dir__), namespace: Object)
end
loader.setup
