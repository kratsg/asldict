require 'json'
require 'pg'
require 'upsert'
require 'date'
require 'time'

Dir.chdir 'SpreadTheSign'
@conn ||= PG.connect(dbname: "kratsg")
Upsert.batch(@conn, :signs) do |upsert|
  IO.foreach("all_words.txt") do |line|
    l = JSON.parse(line)
    next unless (l['languages'] & %w(English American English)).present?
    selector = {
      gloss: l['gloss'],
      description: l['description'],
      source: "spreadthesign"
    }
    setter = {
      url: "http://www.spreadthesign.com%s" % l['href'],
    }
    upsert.row(selector, setter)
  end
end
