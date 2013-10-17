require 'nokogiri'
require 'json'

@classFilter = %w(all adverb adjective interjection conjunction preposition pronoun numeral noun verb sentences)
@words = []

Dir.chdir 'SpreadTheSign'
('a'..'z').each do |letter|
  puts "Opened up letter: %s" % letter
  @classFilter.each do |partOfSpeech|
    puts "\tOpened up POS: %s" % partOfSpeech 
 
    #first step, make a request for page 1
    begin
      response = File.read("%s_%s_response.out" % [letter, partOfSpeech])
    rescue Errno::ENOENT
      next
    end
    puts "\t\t- Read File"
    doc = Nokogiri::HTML(response)
    puts "\t\t- Parsed File"
    @words += doc.css("div.list-row").map do |row|
      gloss = row.css(".caption").text
      flags = row.css(".flags a").map do |flag|
        {
          href: flag['href'],
          title: flag['title'],
          magnet: flag['data-magnet'],
          videa_language: flag['data-video-language'],
          video_id: flag['data-video-id']
        }
      end
      magnet = row.at_css(".videobox")['id'].gsub(/video/,"")
      {gloss: gloss, flags: flags, magnet: magnet, pos: partOfSpeech}
    end
    puts "\t\tDone!"
  end
  puts "\tDone!"
end
File.open('all_words.txt', 'w+') do |f|
  @words.each do |word|
    f.puts word.to_json
  end
end
Dir.chdir '..'
