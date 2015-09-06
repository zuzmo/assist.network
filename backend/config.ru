#\ -E deployment -o 0.0.0.0 -P /tmp/elog.pid
require 'rubygems'
require 'bundler/setup'
require 'logger'
require_relative 'api/api.rb'
logger = Logger.new('log/api_http.log')
logger.level = Logger::DEBUG
use Rack::CommonLogger, logger
run Elog::API

