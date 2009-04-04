# -*- coding: utf-8 -*-

#log = File.new("hamlr.log", "a")
#STDOUT.reopen(log)
#STDERR.reopen(log)

ENV['RACK_ENV'] ||= 'production'

require 'app'
run Sinatra::Application

