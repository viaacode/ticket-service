require 'rack'
require_relative 'mts'

cfgfile = File.expand_path('./config.yaml', File.dirname(__FILE__))
Mts.configure YAML.load_file cfgfile

map('/ticket/') do
    run Mts
end
