require 'simplecov'
require 'coveralls'
Coveralls.wear!

SimpleCov.command_name 'Unit Tests'
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start

require 'rubygems'
require 'pry'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'geomodel'
require 'rspec'
require 'rspec/autorun'

RSpec.configure do |config|

end