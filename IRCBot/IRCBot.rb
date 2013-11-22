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
    @conn = nil
    @asl_lookup_statement = nil
    @info_lookup_statement = nil
    @history_record_statement = nil
  end

  helpers do
    def conn
      p "executing db connection"
      if @conn.nil? or (not @conn.nil? and @conn.finished?) then
        @conn = PG.connect(dbname: "handsy")
        prepare_statements
      end
      @conn
    rescue PG::ConnectionBad
      [false,"My brain is disconnected."]
    end

    def prepare_statement
      @asl_lookup_statement = @conn.prepare("asl_lookup_statement","SELECT id, gloss, source, description, url FROM signs WHERE gloss=$1")
      @info_lookup_statement = @conn.prepare("info_lookup_statement","SELECT gloss, source, description, url FROM signs WHERE id=$1")
      @history_record_statement = @conn.prepare("history_record_statement","INSERT INTO signs_history (nick, word, success) VALUES ($1, $2, $3)")
    rescue PG::SyntaxError
      [false,"I have a headache. Not now honey."]
    end

    def asl_lookup(word)
      return [false,"I don't know what sign you want"] if word.nil?
      word.strip.downcase!
      res = @conn.exec_prepared("asl_lookup_statement", [word])
      return [false,"I'm a work in progress. I do not know '%s' yet." % word] if res.count == 0
      # use this to sort sources (best -> worst)
      $sources = %w(spreadthesign aslu handspeak signingsavvy aslstemforum ritsciencesigns aslpro)
      res = res.sort_by{|item| $sources.index(item["source"])}
      message = res.map do |row|
         "%s <%s> (%d, %s)" % [row["source"], shorten(row["url"]), row["id"], row["description"]]
      end
      [true, message*" | "]
    end
    
    def info_lookup(id)
      return [false,"I don't know what sign you want"] if id.nil?
      res = @conn.exec_prepared("info_lookup_statement", [id])

      return [false,"I cannot seem to find the id '%d' yet. Are you sure it's right?" % id] if res.count == 0
      # use this to sort sources (best -> worst)
      message = res.map do |row|
        row["url"] = shorten(row["url"])
        row.map{|k,v| "%s: %s" % [k,v]}*", "
      end
      [true, message*""]
    end

    def shorten(url)
      response = HTTParty.get("http://tinyurl.com/api-create.php?url=#{URI.escape(url)}")
      (response.code == 200 ? response.body : url)
    end

    def history_record(nick, word, success)
      res = @conn.exec_prepared("history_record_statement", [nick, word, success])
      return [true, res]
    end

    def history_vomit
      res = @conn.exec("SELECT nick, word FROM signs_history ORDER BY timestamp_requested DESC LIMIT 10")
      response = res.map do |row|
        "%s (%s)" % [row["word"], row["nick"]]
      end
      response*" | "
    end

    def history_total
      res1 = @conn.exec("SELECT COUNT(*) as total FROM signs_history")
      res2 = @conn.exec("SELECT timestamp_requested as timestamp FROM signs_history ORDER BY timestamp_requested DESC LIMIT 1")
      [res1[0]["total"], Time.new(res2[0]["timestamp"]).strftime("%m/%d/%Y, %I:%M%p")]
    end

  end

  on :connect do
    p conn
  end

  on :message, /^(!|handsy(?::)? |)shorten url (.*)/ do |m, callee, url|
    return if m.channel? and callee == ""
    m.reply("%s: %s" % [m.user.nick, shorten(url)] )
  end

#  on :message, /^(!|handsy(?::)? |)tell ([a-zA-Z0-9_]+)(?: about)? the signs? for (.*)/ do |m, callee, u, word|
#    return if m.channel? and callee == "" or word.nil?
#    lookup_success, signs = asl_lookup word
#
#    user = User(u)
#    m.reply("Hey %s. The sign for '%s'. %s" % [User(user).nick, word, signs] ) if user.online? and lookup_success
#    m.reply("Hey %s. %s" % [m.user.nick, signs]) if user.online? and not lookup_success
#    m.reply("That user is not online.") unless user.online?
# 
#    history_record(m.user.nick, word, lookup_success)
#  end

  on :message, /^(!|handsy(?::)? |)(?:(?!tell).*?)(?:signs? (?:for )?)([^?!.,"']+)/ do |m, callee, word|
    return if m.channel? and callee == ""
    lookup_success, signs = asl_lookup word

    nice_response = ["you asked for","you asked about","here's what I found for","some signs for","I think I found something for","you wanted to know about","here's some info about"].sample
    m.reply("%s, %s '%s'. %s" % [m.user.nick, nice_response, word, signs] ) if lookup_success
    m.reply("%s, %s" % [m.user.nick, signs]) unless lookup_success

    history_record(m.user.nick, word, lookup_success) unless word.nil?
  end

  on :message, /^(!|handsy(?::)? |)\?$/ do |m, callee|
    return if m.channel? and callee == ""
    m.reply("You can ask me about the sign for baz. You can also ask me about the sign for foo and bar!")
  end

  on :message, /^(!|handsy(?::)? |)(?:.*?)(?:info (?:for |on |))(\d+)/ do |m, callee, identifier|
    return if m.channel? and callee == ""
    lookup_success, info = info_lookup identifier
    m.reply("%s, here's the info you requested! %s" % [m.user.nick, info]) if lookup_success
    m.reply("%s, I had an issue. %s" % [m.user.nick, info]) unless lookup_success
  end

  on :message, /^how (?:do i|to) sign (\w+)/i do |m, word|
    m.reply("Just prefix how to sign something with an exclamation mark, like so: !What is the sign for %s?" % word)
  end

  on :message, /^(!|handsy(?::)? |)history( count)?$/ do |m, callee, total|
    return if m.channel? and callee == ""
    m.reply("Here are 10 most recent calls. %s" % history_vomit) if total.nil?
    m.reply("There have been %d lookups since %s." % history_total) unless total.nil?
  end
end

bot.start
