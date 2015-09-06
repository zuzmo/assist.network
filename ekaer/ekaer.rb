require 'yaml'
require 'faraday'
require 'faraday/detailed_logger'
require 'faraday/request/retry'
require 'logger'
require 'json'
require 'xmlsimple'

CONFIG = YAML.load_file 'config.yaml'

class Ekaer

  def initialize
    logger = Logger.new(CONFIG['logfile'])
    logger.level = Logger::DEBUG
    @conn = Faraday.new(:url => CONFIG['url'], :ssl => { :verify => false }) do |faraday|
      faraday.request  :url_encoded
      faraday.request  :retry, max: 2, interval: 0.05, interval_randomness: 0.5, backoff_factor: 2, exceptions: [StandardError, 'Server timeout']
      faraday.response :detailed_logger, logger
      faraday.adapter  Faraday.default_adapter
    end
  end

  def create(cart)
    xml = generate_xml(:create, cart)
    response = post(CONFIG['manage_service'], xml)
    handle_response(response)
  end

  def modify(cart)
    xml = generate_xml(:modify, cart)
    response = post(CONFIG['manage_service'], xml)
    handle_response(response)
  end

  def close(cart)
    xml = generate_xml(:finalize, cart)
    response = post(CONFIG['manage_service'], xml)
    handle_response(response)
  end

  def delete(cart)
    xml = generate_xml(:delete, cart)
    response = post(CONFIG['manage_service'], xml)
    handle_response(response)
  end

  def list(from, to)
    xml = generate_xml(:list, nil, from, to)
    response = post(CONFIG['query_service'], xml)
    handle_response(response)
  end

  private

  def generate_xml(type, cart, from = 0, to = 0)
    time = Time.now
    request_id = 'PPT' + (time.to_f * 1000).to_i.to_s
    template_hash = JSON.parse(File.read('ekaer/header.json'))
    template_hash['tns:header'][0]['tns:requestId'][0] = request_id
    template_hash['tns:header'][0]['tns:timestamp'][0] = time.strftime('%Y-%m-%dT%H:%M:%S%:z')
    template_hash['tns:user'][0]['tns:requestSignature'][0] = Digest::SHA512.hexdigest(request_id + time.getutc.strftime('%Y%m%d%H%M%S') + CONFIG['secret']).upcase
    if type == :finalize or type == :delete
      action_hash = JSON.parse(File.read('ekaer/action.json'))
      action_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['operation'][0] = type
      unless cart[:tradeCardOperations][0][:tradeCardOperation][0][:tradeCard][0][:tcn].respond_to?('each')
        raise 'Cart does not have EKAER number'
      end
      action_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tcn'][0] = cart[:tradeCardOperations][0][:tradeCardOperation][0][:tradeCard][0][:tcn][0]
      template_hash.merge!(action_hash)
    elsif type == :list
      list_hash = JSON.parse(File.read('ekaer/list.json'))
      list_hash['queryParams'][0]['insertFromDate'][0] = Time.at(from).strftime('%Y-%m-%dT%H:%M:%S%:z')
      list_hash['queryParams'][0]['insertToDate'][0] = Time.at(to).strftime('%Y-%m-%dT%H:%M:%S%:z')
      template_hash.merge!(list_hash)
    else
      template_hash.merge!(cart)
    end
    XmlSimple.xml_out(template_hash, :rootname => 'tns:manageTradeCardsRequest', :xmldeclaration => '<?xml version="1.0" encoding="UTF-8"?>')
  end

  def post(service, xml)
    Logger.new(STDERR).debug(xml)
    @conn.post do |req|
      req.url service
      req.headers['Content-Type'] = 'text/xml'
      req.headers['Accept'] = 'text/xml'
      req.body = xml
    end
  end

  def handle_response(response)
    if response.status == 200
      # HTTP OK
      response_xml = XmlSimple.xml_in(response.body)
      Logger.new(STDERR).debug(response.body)
      # Check for errors in result
      results = {'Result: ' => response_xml['result'][0]}
      if response_xml['tradeCardOperationsResults'][0]['operationResult'].respond_to?('each')
        results.merge!({'Operation result: ' => response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['result'][0]})
      end
      results.each do |message, result|
        unless 'OK' == result['funcCode'][0]
          raise message + result['funcCode'][0] + ' ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : '')
        end
      end
      response_xml
    else
      # HTTP errors
      raise 'HTTP: ' + response.status.to_s + ' ' + response.body
    end
  end
end