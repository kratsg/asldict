require 'cinch'
require 'cinch/plugins/identify'
require 'httparty'
require 'uri'
require 'pg'

bot = Cinch::Bot.new do
  configure do |c|
    c.nick            = 'handsy'
    c.password        = 'zane1n'
    c.server          = 'irc.oftc.net'
    #  c.port            = 7000
    #  c.ssl             = true
    c.verbose         = true
    c.channels        = ["#asl"]
    c.plugins.plugins = [Cinch::Plugins::Identify] # optioinally add more plugins
    c.plugins.options[Cinch::Plugins::Identify] = {
      :username => c.password,# oftc.net is backwards
      :password => c.nick,
      :type     => :nickserv,
    }
  end

  helpers do
    def asl_lookup(word)
      return [false,"I don't know what sign you want"] if word.nil?
      word.strip.downcase!
      conn = PG.connect(dbname: "kratsg")
      conn.prepare("statement","SELECT id, gloss, source, description, url FROM signs WHERE gloss=$1")
      res = conn.exec_prepared("statement", [word])

      return [false,"I'm a work in progress. I do not know '%s' yet." % word] if res.count == 0
      # use this to sort sources (best -> worst)
      $sources = %w(aslu handspeak signingsavvy aslstemforum ritsciencesigns aslpro)
      res = res.sort_by{|item| $sources.index(item["source"])}
      message = res.map do |row|
         "%s <%s> (%d)" % [row["source"], shorten(row["url"]), row["id"]]
      end
      [true, message*" | "]

    rescue PG::ConnectionBad
      [false,"My brain is disconnected."]
    rescue PG::SyntaxError
      [false,"I have a headache. Not now honey."]
    end
    
    def info_lookup(id)
      return [false,"I don't know what sign you want"] if id.nil?
      conn = PG.connect(dbname: "kratsg")
      conn.prepare("statement","SELECT gloss, source, description, url FROM signs WHERE id=$1")
      res = conn.exec_prepared("statement", [id])

      return [false,"I cannot seem to find the id '%d' yet. Are you sure it's right?" % id] if res.count == 0
      # use this to sort sources (best -> worst)
      message = res.map do |row|
        row["url"] = shorten(row["url"])
        row.map{|k,v| "%s: %s" % [k,v]}*", "
      end
      [true, message*""]

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

  on :message, /^(!|handsy(?::)? |)shorten url (.*)/ do |m, callee, url|
    return if m.channel? and callee == ""
    m.reply("%s: %s" % [m.user.nick, shorten(url)] )
  end

 on :message, /^(!|handsy(?::)? |)tell ([a-zA-Z0-9]+)(?: about)? the signs? for (.*)/ do |m, callee, u, word|
    return if m.channel? and callee == ""
    lookup_success, signs = asl_lookup word
    user = User(u)
    m.reply("Hey %s. The sign for '%s'. %s" % [User(user).nick, word, signs] ) if user.online? and lookup_success
    m.reply("Hey %s. %s" % [m.user.nick, signs]) if user.online? and not lookup_success
    m.reply("That user is not online.") unless user.online?
  end

  on :message, /^(!|handsy(?::)? |)(?:(?!tell).*?)(?:signs? for )([^?!.,"'\s]+)(?: and )?([^?!.,"'\s]+)?/ do |m, callee, word1, word2|
    return if m.channel? and callee == ""
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

  on :message, /^(!|handsy(?::)? |)\?$/ do |m, callee|
    return if m.channel? and callee == ""
    m.reply("You can ask me about the sign for baz. You can also ask me about the sign for foo and bar!")
  end

  on :message, /^(!|handsy(?::)? |)(?:.*?)(?:info (?:for|on) )(\d+)/ do |m, callee, identifier|
    return if m.channel? and callee == ""
    lookup_success, info = info_lookup identifier
    m.reply("%s, here's the info you requested! %s" % [m.user.nick, info]) if lookup_success
    m.reply("%s, I had an issue. %s" % [m.user.nick, info]) unless lookup_success
  end

end

bot.start
