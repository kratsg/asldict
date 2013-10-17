require 'json'
require 'pg'

@conn ||= PG.connect(dbname: "kratsg")
@insert_statement ||= @conn.prepare("insert_statement","INSERT INTO signs (gloss, source, description, url) VALUES ($1, $2, $3, $4)")
Dir.chdir 'SpreadTheSign'
response = IO.foreach("all_words.txt") do |line|
  l = JSON.parse(line)
  l['flags'].each do |flag|
    l['href'] = flag['href'] if ["American English","English"].include?(flag['title'])
    l['has_english'] = true if ["American English","English"].include?(flag['title'])
  end
  next unless l['has_english']
  @conn.exec_prepared("insert_statement", [l['gloss'], 'spreadthesign', l['pos'], l['href']] )
end
