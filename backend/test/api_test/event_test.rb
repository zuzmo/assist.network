require 'net/http'

http = Net::HTTP.new('localhost', 9292)
path = '/event'
#data = File.read('test/api_test/event_csv.json')
data = File.read('event_csv.json')
#data = '{"event":"deposit_calculated","cartID":1}'
headers = {
    'Auth' => 'MTMxYjdkNmRkZjEzMWQxYzJlNmY2N2Vh',
    'Content-Type' => 'application/json'
}

resp = http.post(path, data, headers)
print resp.body