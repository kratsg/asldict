require 'net/http'
require 'nokogiri'

base_url = 'http://aslstem.cs.washington.edu/topics/signs/%d'

words = []
$i = 1
$skipPage = []
while true do
  uri = URI(base_url % $i)
  $i+=1
  http = Net::HTTP.new(uri.host, uri.port)
  response = http.request(Net::HTTP::Get.new(uri.request_uri))

  break if $skipPage.length > 100
  unless response.code == "200" then
    $skipPage.push({url: uri.to_s, code: response.code})
    next
  end

  response_doc = Nokogiri::HTML(response.body)
  sign = response_doc.css('#topic').text[/\w+$/]
  words.push({href: uri.to_s, text: sign})
  p "%d: %s" % [$i, sign]
end
