require 'cinch'
require 'httparty'
require 'uri'
require 'pg'

bot = Cinch::Bot.new do
  configure do |c|
    c.nick            = 'ASLbotOO7'
    #  c.password        = 'password'
    c.server          = 'irc.oftc.net'
    #  c.port            = 7000
    #  c.ssl             = true
    c.verbose         = true,
    c.channels        = ["#asl"]
  end

  helpers do
    def asl_lookup(word)
      return [false,"I don't know what sign you want"] if word.nil?
      word.strip.downcase!
      conn = PG.connect(dbname: "kratsg")
      conn.prepare("statement","SELECT gloss, source, description, url FROM signs WHERE gloss=$1")
      res = conn.exec_prepared("statement", [word])

      return [false,"I'm a work in progress. I do not know '%s' yet." % word] if res.count == 0
      # use this to sort sources (best -> worst)
      $sources = %w(aslu handspeak signingsavvy aslstemforum ritsciencesigns aslpro)
      res = res.sort_by{|item| $sources.index(item["source"])}
      message = res.map do |row|
         "%s <%s>" % [row["source"], shorten(row["url"])]
      end
      [true, message*" | "]

    rescue PG::ConnectionBad
      [false,"My brain is disconnected."]
    rescue PG::SyntaxError
      [false,"I have a headache. Not now honey."]
    end

    def shorten(url)
      response = HTTParty.get("http://tinyurl.com/api-create.php?url=#{URI.escape(url)}")
      (response.code == 200 ? response.body : url)
    end
  end

  on :message, /!shorten url (.*)/ do |m,url|
    m.reply("%s: %s" % [m.user.nick, shorten(url)] )
  end

  on :message, /!tell ([a-zA-Z0-9]+)(?: about)? the signs? for (.*)/ do |m,u,word|
    lookup_success, signs = asl_lookup word
    user = User(u)
    m.reply("Hey %s. The sign for '%s'. %s" % [User(user).nick, word, signs] ) if user.online? and lookup_success
    m.reply("Hey %s. %s" % [m.user.nick, signs]) if user.online? and not lookup_success
    m.reply("That user is not online.") unless user.online?
  end

  on :message, /!(?:(?!tell).*?)(?:signs? for )([^?!.,"'\s]+)(?: and )?([^?!.,"'\s]+)?/ do |m,word1, word2|
    lookup_success1, signs1 = asl_lookup word1
    lookup_success2, signs2 = asl_lookup word2
    if lookup_success2 and not lookup_success1 then
      lookup_success1, lookup_success2 = lookup_success2, lookup_success1
      signs1, signs2 = signs2, signs1
      word1,  word2  = word2,  word1
    end

    nice_response = ["you asked for","you asked about","here's what I found for","some signs for","I think I found something for","you wanted to know about","here's some info about"].sample
    m.reply("%s, %s '%s'. %s" % [m.user.nick, nice_response, word1, signs1] ) if lookup_success1
    m.reply("%s, also %s '%s'. %s" % [m.user.nick, nice_response, word2, signs2] ) if lookup_success2
    m.reply("%s, %s" % [m.user.nick, signs1]) unless lookup_success1
    m.reply("%s, %s" % [m.user.nick, signs2]) unless lookup_success2 or word2.nil?
  end

  on :message, /^!\?$/ do |m|
    m.reply("You can ask me about the sign for baz. You can also ask me about the sign for foo and bar!")
  end

  on :message, /^ASLbotOO7/ do |m|
    m.reply("I'm sorry. If you want to use me, use the format !message.")
  end

end

bot.start
