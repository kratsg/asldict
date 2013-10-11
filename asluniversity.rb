require 'net/http'
require 'nokogiri'
uris = ('a'..'z').map{|l| URI 'http://www.lifeprint.com/asl101/index/%s.htm' % l}
uris.map! do |page|
  begin
    response = Net::HTTP.get(page).gsub!(/(\n|\t)/,"").encode!('UTF-8', 'ASCII', :invalid => :replace)
    response_doc = Nokogiri::HTML(response)
    response_doc.css('a[href]').map do |link|
      begin
        {href: URI.join(page.to_s, link['href']).to_s, text: link.text.downcase}
      rescue => e
        p link['href'].to_s, link.text.downcase
        raise e
      end
    end
  rescue => e
    p page
    raise e
  end
end
uris.flatten!(1)
