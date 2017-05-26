require 'rack'
require_relative 'vts'

cfgfile = File.expand_path('./config.yaml', File.dirname(__FILE__))
Vts.configure YAML.load_file cfgfile

map('/jwt/') do
    run Vts
end
