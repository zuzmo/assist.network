require 'minitest/autorun'
require 'faraday'
require 'faraday/detailed_logger'
require 'logger'
require 'json'
require 'xmlsimple'
require 'digest'

URL = 'https://import-test-b.ekaer.nav.gov.hu'
MANAGE_SERVICE = '/TradeCardManagementService/customer/manageTradeCards'
QUERY_SERVICE = '/TradeCardManagementService/customer/queryTradeCards'
SECRET = 'u2hyfZ8hVB'
LOGFILE = '../../log/nav_test_http.log'

CREATE_TEMPLATE = 'template/create.json'
MODIFY_TEMPLATE = 'template/modify.json'
DELETE_TEMPLATE = 'template/delete.json'
LIST_TEMPLATE = 'template/list.json'

class NavTest < MiniTest::Test

  def self.test_order
    :alpha
  end

  def setup
    @time = Time.now
    @reqest_id = 'PPT' + (@time.to_f * 1000).to_i.to_s
    logger = Logger.new(LOGFILE)
    logger.level = Logger::DEBUG
    @conn = Faraday.new(:url => URL, :ssl => { :verify => false }) do |faraday|
      faraday.request  :url_encoded
      faraday.response :detailed_logger, logger
      faraday.adapter  Faraday.default_adapter
    end
  end

  def generate_xml(template_json)
    root = 'tns:manageTradeCardsRequest'
    template_hash = JSON.parse(File.read(template_json))
    template_hash['tns:header'][0]['tns:requestId'][0] = @reqest_id
    template_hash['tns:header'][0]['tns:timestamp'][0] = @@time.strftime('%Y-%m-%dT%H:%M:%S%:z')
    template_hash['tns:user'][0]['tns:requestSignature'][0] = Digest::SHA512.hexdigest(@reqest_id + @time.getutc.strftime('%Y%m%d%H%M%S') + SECRET).upcase
    case @action
      when :create
        template_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tradeCard'][0]['loadDate'][0] = @@time.strftime('%Y-%m-%dT%H:%M:%S%:z')
        template_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tradeCard'][0]['arrivalDate'][0] = (@@time + (60*60*24)).strftime('%Y-%m-%dT%H:%M:%S%:z')
      when :modify
        template_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tradeCard'][0]['tcn'][0] = @@card
        template_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tradeCard'][0]['items'][0]['tradeCardItem'][0]['id'] = @@item
        template_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tradeCard'][0]['loadDate'][0] = @@time.strftime('%Y-%m-%dT%H:%M:%S%:z')
        template_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tradeCard'][0]['arrivalDate'][0] = (@@time + (60*60*24)).strftime('%Y-%m-%dT%H:%M:%S%:z')
      when :delete
        template_hash['tradeCardOperations'][0]['tradeCardOperation'][0]['tcn'][0] = @@card
      when :list
        root = 'tns:queryTradeCardsRequest'
      else
    end
    XmlSimple.xml_out(template_hash, :rootname => root, :xmldeclaration => '<?xml version="1.0" encoding="UTF-8"?>')
  end

  def post(template_json)
    service = MANAGE_SERVICE
    if :list == @action
      service = QUERY_SERVICE
    end
    @conn.post do |req|
      req.url service
      req.headers['Content-Type'] = 'text/xml'
      req.headers['Accept'] = 'text/xml'
      req.body = generate_xml(template_json)
    end
  end

  def test_1_create
    @action = :create
    @@time = @time
    # Server connection
    assert_silent {
      @response = post(CREATE_TEMPLATE)
    }
    # HTTP code check
    assert_equal(200, @response.status, 'HTTP status: ' + @response.status.to_s)
    # Parse XML
    assert_silent {
      @response_xml = XmlSimple.xml_in(@response.body)
    }
    # ID check
    assert_equal(@reqest_id, @response_xml['header'][0]['requestId'][0], 'Request id mismatch')
    # Result ERROR code check
    result = @response_xml['result'][0]
    assert_equal('OK', result['funcCode'][0], result['funcCode'][0] + ' result: ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : ''))
    # Operation ERROR code check
    result = @response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['result'][0]
    assert_equal('OK', result['funcCode'][0], result['funcCode'][0] + ' operationResult: ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : ''))
    # Save IDs
    if @response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['tradeCardInfo'].respond_to?('each')
      @@card = @response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['tradeCardInfo'][0]['tcn'][0]
      @@item = @response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['tradeCardInfo'][0]['items'][0]['tradeCardItem'][0]['id']
    end
  end

  def test_2_modify
    @action = :modify
    # Server connection
    assert_silent {
      @response = post(MODIFY_TEMPLATE)
    }
    # HTTP code check
    assert_equal(200, @response.status, 'HTTP status: ' + @response.status.to_s)
    # Parse XML
    assert_silent {
      @response_xml = XmlSimple.xml_in(@response.body)
    }
    # ID check
    assert_equal(@reqest_id, @response_xml['header'][0]['requestId'][0], 'Request id mismatch')
    # Result ERROR code check
    result = @response_xml['result'][0]
    assert_equal('OK', result['funcCode'][0], result['funcCode'][0] + ' result: ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : ''))
    # Operation ERROR code check
    result = @response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['result'][0]
    assert_equal('OK', result['funcCode'][0], result['funcCode'][0] + ' operationResult: ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : ''))
    # Card id check
    assert_equal(@@card, @response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['tradeCardInfo'][0]['tcn'][0], 'Card id mismatch')
  end

  def test_3_list
    @action = :list
    # Server connection
    assert_silent {
      @response = post(LIST_TEMPLATE)
    }
    # HTTP code check
    assert_equal(200, @response.status, 'HTTP status: ' + @response.status.to_s)
    # Parse XML
    assert_silent {
      @response_xml = XmlSimple.xml_in(@response.body)
    }
    # ID check
    assert_equal(@reqest_id, @response_xml['header'][0]['requestId'][0], 'Request id mismatch')
    # Result ERROR code check
    result = @response_xml['result'][0]
    assert_equal('OK', result['funcCode'][0], result['funcCode'][0] + ' result: ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : ''))
    # Number of results check
    tradecards = @response_xml['tradeCards'][0]['tradeCardInfo']
    assert_respond_to(tradecards, 'each', 'No tradecards in list')
  end

  def test_4_delete
    @action = :delete
    # Server connection
    assert_silent {
      @response = post(DELETE_TEMPLATE)
    }
    # HTTP code check
    assert_equal(200, @response.status, 'HTTP status: ' + @response.status.to_s)
    # Parse XML
    assert_silent {
      @response_xml = XmlSimple.xml_in(@response.body)
    }
    # ID check
    assert_equal(@reqest_id, @response_xml['header'][0]['requestId'][0], 'Request id mismatch')
    # Result ERROR code check
    result = @response_xml['result'][0]
    assert_equal('OK', result['funcCode'][0], result['funcCode'][0] + ' result: ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : ''))
    # Operation ERROR code check
    result = @response_xml['tradeCardOperationsResults'][0]['operationResult'][0]['result'][0]
    assert_equal('OK', result['funcCode'][0], result['funcCode'][0] + ' operationResult: ' + result['reasonCode'][0] + ': ' + (result['msg'].respond_to?('each') ? result['msg'][0] : ''))
  end
end
