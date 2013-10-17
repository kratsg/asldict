require 'httparty'
require 'nokogiri'

@base_url = 'http://www.spreadthesign.com/includes/search.inc.php'
@classFilter = %w(all adverb adjective interjection conjunction preposition pronoun numeral noun verb sentences)

def grab_page(letter, partOfSpeech, page=1)
  HTTParty.post(@base_url, body: ("lang=13&group=0&search=%s&class=%d&page=%d" % [letter, @classFilter.index(partOfSpeech), page]))
end

Dir.chdir 'SpreadTheSign'
('a'..'z').each do |letter|
  puts "Opened up letter: %s" % letter
  @classFilter.each do |partOfSpeech|
    puts "\tOpened up POS: %s" % partOfSpeech 
 
    #first step, make a request for page 1
    response = grab_page(letter, partOfSpeech)
    puts "\t\t - Grabbed Page 1"
    doc = Nokogiri::HTML(response.body)
    numPages = doc.css("#searchpages button[onclick]").map(&:text).delete_if{|x| x.to_i == 0}.max.to_i
    puts "\t\tNum Pages: %d" % numPages
    # we need to grab all pages, if there's 0 or 1 page - do nothing
    if numPages > 1 then
      2.upto(numPages) do |page|
        puts "\t\t - Grabbed Page %d" % page
        response += grab_page(letter, partOfSpeech, page)
      end
    end
    if numPages >= 1 then
      File.open(('%s_%s_response.out' % [letter, partOfSpeech]),'w+'){|f| f.write(response)}
    end
    puts "\t\tDone!"
  end
end
Dir.chdir '..'
