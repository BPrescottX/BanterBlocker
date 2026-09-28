local _, ns = ...

local MAX_COUNT = 999999999999
local ID_CACHE_SIZE = 2048
local DECISION_CACHE_SIZE = 2048
local FALLBACK_CACHE_SIZE = 256

local idSeen, idQueue, idCursor = {}, {}, 0
local fallback, fallbackTime, fallbackSize = {}, nil, 0
local anonymousFrame = {}

local decisions, decisionQueue, decisionCursor = {}, {}, 0

local function finite(value)
  return type(value) == "number" and value == value
      and value > -math.huge and value < math.huge
end
ns.IsFiniteNumber = finite

local function safeCount(value)
  if not finite(value) or value < 0 then return 0 end
  return math.min(MAX_COUNT, math.floor(value))
end

function ns.FormatCount(value)
  local digits = string.format("%.0f", safeCount(value))
  local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (grouped:gsub("^,", ""))
end

function ns.InitStats()
  local stats = type(ns.db.stats) == "table" and ns.db.stats or {}
  ns.db.stats = stats
  stats.total = safeCount(stats.total)
  stats.byList = type(stats.byList) == "table" and stats.byList or {}
  stats.byWord = type(stats.byWord) == "table" and stats.byWord or {}
  ns.sessionBlocked = 0
end

-- Normal chat events carry a line ID (event argument 11) shared by every chat
-- window that receives the message. Secret/protected values yield nil.
function ns.UsableLineID(value)
  if not ns.IsReadable(value) then return nil end
  if type(value) == "string" then
    if not value:match("^%d+$") then return nil end
    value = tonumber(value)
  end
  if finite(value) and value > 0 and value == math.floor(value) then
    return string.format("%.0f", value)
  end
end

-- Bounded ring of recently delivered line IDs.
local function firstIDDelivery(event, lineID)
  local key = event .. ":" .. lineID
  if idSeen[key] then return false end
  idCursor = idCursor % ID_CACHE_SIZE + 1
  local old = idQueue[idCursor]
  if old then idSeen[old] = nil end
  idQueue[idCursor], idSeen[key] = key, true
  return true
end

-- Events without a line ID: within one render tick, count the maximum number
-- of deliveries to any single frame rather than the sum across frames. That
-- counts two identical messages correctly even when several frames see both.
local function firstFallbackDelivery(frame, event, message, author)
  local now = type(GetTime) == "function" and GetTime() or 0
  if now ~= fallbackTime then
    fallback, fallbackTime, fallbackSize = {}, now, 0
  end
  local key = event .. "\031" .. tostring(author) .. "\031" .. tostring(message)
  local state = fallback[key]
  if not state then
    if fallbackSize >= FALLBACK_CACHE_SIZE then
      fallback, fallbackSize = {}, 0
    end
    state = { frames = {}, maximum = 0 }
    fallback[key], fallbackSize = state, fallbackSize + 1
  end
  frame = frame or anonymousFrame
  local count = (state.frames[frame] or 0) + 1
  state.frames[frame] = count
  if count <= state.maximum then return false end
  state.maximum = count
  return true
end

-- True only for the first delivery of a message to any chat frame.
function ns.FirstDelivery(frame, event, message, author, ...)
  local lineID = ns.UsableLineID(select(9, ...)) -- arg 11 after frame/event/msg/author
  if lineID then
    return firstIDDelivery(event, lineID)
  end
  return firstFallbackDelivery(frame, event, message, author)
end

-- Match decisions are deterministic per message, so cache them: each message
-- is evaluated once, not once per chat frame. The cache is wiped whenever the
-- matcher changes (RebuildMatcher / option toggles).
function ns.CachedDecision(key, compute)
  if key then
    local cached = decisions[key]
    if cached ~= nil then return cached end
  end
  local result = compute()
  if result == nil then result = false end
  if key then
    decisionCursor = decisionCursor % DECISION_CACHE_SIZE + 1
    local old = decisionQueue[decisionCursor]
    if old then decisions[old] = nil end
    decisionQueue[decisionCursor] = key
    decisions[key] = result
  end
  return result
end

function ns.WipeCaches()
  decisions, decisionQueue, decisionCursor = {}, {}, 0
  idSeen, idQueue, idCursor = {}, {}, 0
  fallback, fallbackTime, fallbackSize = {}, nil, 0
end

-- Caller is responsible for the delivery check (ns.FirstDelivery).
function ns.CountBlocked(entry)
  local stats = ns.db.stats
  stats.total = math.min(MAX_COUNT, stats.total + 1)
  ns.sessionBlocked = math.min(MAX_COUNT, (ns.sessionBlocked or 0) + 1)
  if entry and entry.list then
    stats.byList[entry.list] = (stats.byList[entry.list] or 0) + 1
  end
  if entry and entry.word then
    stats.byWord[entry.word] = (stats.byWord[entry.word] or 0) + 1
  end
  if ns.RefreshStatus then ns.RefreshStatus() end
end

function ns.ResetStats()
  local stats = ns.db.stats
  stats.total = 0
  wipe(stats.byList)
  wipe(stats.byWord)
  ns.sessionBlocked = 0
  -- Delivery caches stay: another frame may still be mid-delivery of a
  -- message counted just before the reset.
  if ns.RefreshStatus then ns.RefreshStatus() end
end
