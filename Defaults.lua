local ADDON_NAME, ns = ...

ns.name = ADDON_NAME or "BanterBlocker"
ns.title = "BanterBlocker"
ns.version = "2.0.0"
ns.MAX_WORD_BYTES = 160
ns.MAX_LIST_NAME_BYTES = 40
ns.MAX_IMPORT_BYTES = 262144

-- Toggles. Blizzard splits some categories into "normal" and "leader" events.
ns.CHAT_TYPES = {
  { key = "channel",   label = "Public channels",   default = true,  events = { "CHAT_MSG_CHANNEL" } },
  { key = "say",       label = "Say",               default = true,  events = { "CHAT_MSG_SAY" } },
  { key = "yell",      label = "Yell",              default = true,  events = { "CHAT_MSG_YELL" } },
  { key = "whisper",   label = "Whispers/AFK/DND",  default = false, events = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_AFK", "CHAT_MSG_DND" } },
  { key = "bnet",      label = "Battle.net",        default = false, events = { "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_BN_CONVERSATION", "CHAT_MSG_BN_INLINE_TOAST_BROADCAST", "CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM" } },
  { key = "party",     label = "Party",             default = false, events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_PARTY_GUIDE" } },
  { key = "raid",      label = "Raid",              default = false, events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" } },
  { key = "instance",  label = "Instance / BG",     default = false, events = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" } },
  { key = "guild",     label = "Guild",             default = false, events = { "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER" } },
  { key = "community", label = "Communities",       default = false, events = { "CHAT_MSG_COMMUNITIES_CHANNEL" } },
  { key = "emote",     label = "Emotes",            default = false, events = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" } },
}

ns.EVENT_TO_KEY = {}
for _, chatType in ipairs(ns.CHAT_TYPES) do
  for _, event in ipairs(chatType.events) do
    ns.EVENT_TO_KEY[event] = chatType.key
  end
end

-- Optional starter lists, imported on demand from the options panel or
-- /banter import <name>. They are plain editable lists, nothing special.
ns.STARTER_LISTS = {
  {
    name = "Politics",
    words = {
      -- figures
      "trump", "biden", "kamala", "aoc", "desantis", "newsom", "obama",
      "hillary", "pelosi", "gaetz", "boebert", "fauci", "putin", "zelensky",
      "netanyahu", "elon musk", "epstein", "soros", "hunter biden",
      "klaus schwab", "bill gates", "nick fuentes", "joe rogan", "ben shapiro",
      "tucker carlson", "alex jones", "george floyd", "ashli babbitt",
      "rothschild", "pinochet",
      -- slurs and slogans
      "libtard", "sheeple", "soyboy", "commie", "groomer", "groomers",
      "bootlicker", "sjw", "maga", "magat", "rino", "globalist",
      "whataboutism", "redpill", "psyop", "plandemic", "eat the rich",
      "go woke go broke", "climate hoax", "climate cult", "lamestream",
      "crisis actor", "controlled opposition", "mind virus",
      "helicopter rides", "dog whistle", "anchor baby", "terf", "misgender",
      "eat the bugs", "died suddenly", "trust the plan", "pizzagate",
      "second amendment solution", "white genocide", "fuck the police",
      "acab", "j6er", "groyper", "groypers", "tradwife", "virtue signal",
      "check your privilege", "stay woke", "decolonize", "from the river",
      "intifada", "sleepy joe", "crooked hillary", "let's go brandon",
      "lets go brandon", "dark maga", "not my president", "laptop from hell",
      "russia hoax", "no collusion", "cultural marxism", "great replacement",
      "replacement theory", "white privilege", "white supremacy",
      "christian nationalist", "apartheid", "zionist", "sharia", "jihad",
      "islamophobia", "antisemitism", "radical islam", "grooming gangs",
      "biological male", "biological female", "dei hire",
      -- left-coded terms
      "democrat", "democrats", "liberal", "liberals", "progressive", "leftist",
      "left-wing", "far-left", "socialist", "communist", "marxist", "blm",
      "black lives matter", "antifa", "build back better", "green new deal",
      "defund the police", "cancel culture", "pro-choice", "gun control",
      "open borders", "sanctuary city", "climate change", "global warming",
      "net zero", "degrowth", "vaccine mandate", "mask mandate",
      "mail-in ballot", "transgender", "drag queen", "puberty blocker",
      "trans rights", "affirmative action", "reparations", "wealth tax",
      "daca", "land back", "cnn", "msnbc", "safe space", "microaggression",
      "intersectionality", "extinction rebellion", "just stop oil",
      "deplatform", "shadowban", "filibuster", "iran deal", "unrwa",
      "palestine", "gaza", "hamas", "ukraine", "never trump",
      "steele dossier", "impeach", "impeachment", "special counsel",
      "hunter laptop", "lolita express",
      -- right-coded terms
      "republican", "republicans", "gop", "conservative", "conservatives",
      "right-wing", "far-right", "alt-right", "america first", "pro-life",
      "second amendment", "ar-15", "border wall", "deportation",
      "illegal immigrant", "mass deportation", "gotaway", "ms-13", "fentanyl",
      "parental rights", "don't say gay", "book ban", "qanon", "project 2025",
      "drain the swamp", "deep state", "stop the steal", "stolen election",
      "rigged election", "voter fraud", "january 6", "jan 6", "insurrection",
      "political prisoner", "proud boys", "oath keepers", "cpac", "tpusa",
      "fox news", "breitbart", "daily wire", "thin blue line", "censorship",
      "lab leak", "antivax", "mar-a-lago", "classified documents", "lawfare",
      "two-tier justice", "indicted", "14th amendment", "insurrection clause",
      "electoral college", "gerrymander", "martial law", "patriot act",
      "national divorce", "tiktok ban", "spy balloon", "great reset", "davos",
      "world economic forum", "you will own nothing", "15 minute city",
      "cbdc", "social credit", "social credit score", "section 230",
      "big tech", "state media", "sedition", "collusion", "grand jury",
      "whistleblower", "executive order", "israel", "war on terror",
      "taliban", "isis", "houthi", "hezbollah", "nord stream",
      "dead internet", "astroturf", "october surprise", "bilderberg",
    },
  },
  {
    name = "Spam",
    words = {
      "buy gold", "cheap gold", "wow gold", "buy wow gold", "gold for sale",
      "wts gold", "fast delivery", "safe delivery", "powerleveling",
      "power leveling", "raid carry", "m+ carry", "mythic carry", "arena carry",
      "boosting service", "sell runs", "visit our site", "cheapest price",
      "discord.gg", "dsc.gg", "bit.ly", "tinyurl", "g2g", "playerauctions",
      "onlyfans", ".com", "www.",
    },
  },
}
