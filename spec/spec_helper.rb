require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require 'rubygems'
require 'pry'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'geomodel'
require 'rspec'
require 'rspec/autorun'

RSpec.configure do |config|

end