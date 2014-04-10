require 'net/http'
require 'nokogiri'

open('aslbrowser.commtechlab.msu.out', 'a') do |f|
  uris = ('A'..'Z').map{|l| URI 'http://aslbrowser.commtechlab.msu.edu/%s/index.htm' % l}
  uris.map! do |uri|
    http = Net::HTTP.new(uri.host, uri.port)
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    response_doc = Nokogiri::HTML(response.body)
    response_doc.css('a[href]').each do |link|
      f.puts('%s,%s' % [link.text.downcase, uri.to_s.gsub(/\w+\.\w+$/, link['href']) ])
    end
  end
end
