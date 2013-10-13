require 'net/http'
require 'nokogiri'

base_url = 'http://aslstem.cs.washington.edu/signs/view/%d'

$skipPage = []
$i = 1
open('wordsOutput.out', 'a') do |f|
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

    output = File.open("ASLStemForumData/%d.out" % ($1-1))
    output << response.body
    output.close

    response_doc = Nokogiri::HTML(response.body)
    sign = response_doc.css('#topic').text.gsub!(/Viewing sign ##{$i-1} for /,"")
    youtubeURL = response_doc.css('object.view_sign embed').attribute('src').value
    f.puts('%d,%s,%s}' % [$i, sign, youtubeURL])
  end
end
