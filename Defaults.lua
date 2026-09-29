local ADDON_NAME, ns = ...

ns.name = ADDON_NAME or "BanterBlocker"
ns.title = "BanterBlocker"
ns.version = "2.0.1"
ns.MAX_WORD_BYTES = 160
ns.MAX_LIST_NAME_BYTES = 40
ns.MAX_IMPORT_BYTES = 262144

-- Toggles. Blizzard splits some categories into "normal" and "leader" events.
ns.CHAT_TYPES = {
  { key = "channel",   label = "Public channels",   default = true,  events = { "CHAT_MSG_CHANNEL" } },
  { key = "say",       label = "Say",               default = false, events = { "CHAT_MSG_SAY" } },
  { key = "yell",      label = "Yell",              default = false, events = { "CHAT_MSG_YELL" } },
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
local function wordList(text)
  local words = {}
  for word in text:gmatch("[^\r\n]+") do
    word = word:match("^%s*(.-)%s*$")
    if word ~= "" then words[#words + 1] = word end
  end
  return words
end

ns.STARTER_LISTS = {
  {
    name = "People",
    words = wordList([[
abbott
abrams
alito
alexjones
alvin
amash
andrewtate
aoc
ayanna
bachmann
bannon
barack
barrett
barron
beck
bernie
beto
bibi
biden
biggs
boebert
bolton
booker
boris
bowman
bragg
bush
buttigieg
candace
carlson
castro
charliekirk
cheney
christie
clinton
comey
cortez
cotton
coulter
crockett
crowder
cruz
cuomo
desantis
diddy
donjr
durham
elon
epstein
farage
fauci
fetterman
flynn
fuentes
gabbard
gaetz
garland
gates
gavin
ghislaine
gingrich
ginsburg
giuliani
glennbeck
gohmert
gosar
gorsuch
graham
greene
hakeem
haley
hannity
harris
hawley
hochul
homan
ilhan
ingraham
ivanka
jacksmith
jamaal
jasmine
jeb
jeffries
jinping
jongun
jordan
julian
kagan
kamala
kanye
kasich
kavanaugh
kemp
kennedy
ketanji
khamenei
khomeini
kim
kirk
klaus
klobuchar
knowles
kushner
landry
lepen
letitia
levin
limbaugh
lindsey
macron
maduro
malkin
manafort
marianne
marine
massie
maxine
maxwell
mayorkas
mccain
mccarthy
mcconnell
meadows
melania
merkel
michelle
mitch
mtg
mueller
musk
nadler
netanyahu
newsom
nickfuentes
nikki
obama
ocasio
omar
orban
orourke
ossoff
owens
palin
paxton
pelosi
pence
peterson
poilievre
pompeo
prager
pressley
pritzker
putin
ramaswamy
rashida
rfk
rishi
rogan
romney
rubio
rudy
sanders
scalise
scalia
schiff
schumer
schwab
shapiro
smith
soros
sotomayor
starmer
stacey
sunak
swalwell
tate
tlaib
trudeau
trump
trumpy
tuberville
tucker
tulsi
vance
vivek
vladimir
volodymyr
walz
warnock
warren
waters
weinstein
whitmer
williamson
willis
wray
xi
yang
ye
youngkin
zelensky
zelenskyy
zuck
zuckerberg
bessent
bondi
curtis
hegseth
karoline
karolineleavitt
kash
kashpatel
kristi
kristinoem
leavitt
lutnick
mamdani
mikejohnson
noem
pambondi
patel
petehegseth
sliwa
stephenmiller
susie
thune
wiles
zohran
hassan
piker
asmon
asmongold
]]),
  },
  {
    name = "Politics",
    words = wordList([[
abortion
acab
affirmative
alien
aliens
allyship
alt-right
altright
americafirst
antichrist
antifa
antiracist
antisemite
antisemitic
antisemitism
antivax
antivaxxer
antivaxxers
aoc
asylum
atheist
authoritarian
authoritarianism
bathroom
beaner
biden
bigot
bigoted
bigotry
biphobia
bipoc
birthing
blasphemy
blm
bootlicker
border
brocialist
cancel
canceled
cancelled
chink
christianism
cis
cisgender
cishet
climate
clinton
colonizer
commie
communism
communist
conservatard
conservative
conservatives
cope
cracker
crt
cuck
cuckservative
cult45
davos
deadname
deadnaming
decolonize
defund
dei
democrat
democrats
demonrat
deport
deportation
deplatform
desantis
detrans
detransition
dhs
dnc
drag
elon
enby
endtimes
equity
evangelical
evangelicals
fauci
fascism
fascist
fatphobia
fbi
felon
femcel
fetus
gook
gop
globalism
globalist
groomer
groomers
grooming
harris
harris2024
heretic
heteronormative
hillary
holocaust
homophobe
homophobia
homophobic
ice
ideology
illegal
illegals
incel
inclusion
inclusive
indoctrinate
indoctrination
infidel
intersectional
intersectionality
islamist
islamophobia
islamophobic
ivermectin
j6
jihad
jihadi
jihadist
kamala
karen
kike
lesbophobia
lefties
leftist
leftists
lefty
lgbtq
lgbtqia
liberal
liberals
libtard
libtards
maga
magat
mail-in
marxism
marxist
microaggression
migrant
migrants
moderna
musk
nationalism
nationalist
nazi
nazis
neocon
neocons
neoconservative
neoliberal
neonazi
nonbinary
non-binary
npc
nwo
obama
oppressed
oppression
oppressor
othering
patriarchy
pedo
pedophile
pedophilia
pelosi
pfizer
pinko
populism
populist
privilege
pro-choice
pro-life
prochoice
prolife
pronoun
pronouns
puberty
queer
raghead
rapture
racist
racism
racists
refugee
refugees
reparations
replacement
republicunt
republican
republicans
rino
rnc
sanctuary
satanic
satanism
schumer
seethe
sharia
sheeple
shemale
simp
simps
sjw
sjws
sleepy
snowflake
snowflakes
socialism
socialist
soyboy
stakeholders
stolen
supremacist
supremacy
swamp
systemic
tankie
tucker
tds
terf
terfs
theocrat
theocracy
they/them
thinblue
totalitarian
towelhead
tradcath
tradwife
traitor
tranny
trans
transgender
transphobe
transphobia
transphobic
transsexual
treason
triggered
triggering
trump
trumpy
trumpism
trumpist
undocumented
unhoused
vance
vax
vaxxed
vegan
virtue
wef
wetback
whitey
woke
wokeism
wokeness
wokes
wokies
xenophobe
xenophobia
zionism
zionist
zoomer
politics
political
ads
government
discriminatory
indian
indians
violent
violence
]]),
  },
  {
    name = "Spam",
    words = wordList([[
buy gold
cheap gold
wow gold
buy wow gold
gold for sale
wts gold
fast delivery
safe delivery
powerleveling
power leveling
raid carry
m+ carry
mythic carry
arena carry
boosting service
sell runs
visit our site
cheapest price
discord.gg
dsc.gg
bit.ly
tinyurl
g2g
playerauctions
onlyfans
.com
www.
]]),
  },
  {
    name = "Slurs",
    words = wordList([[
anal
pussy
]]),
  },
  {
    name = "WoW",
    words = wordList([[
thunderfury
]]),
  },
}
