local ADDON_NAME, ns = ...
local Engine = ns.Engine

local registered = {}
ns.registrationCount = 0
ns.registrationFailures = 0
ns.apiName = "unavailable"

local function readable(value)
  if type(canaccessvalue) == "function" and not canaccessvalue(value) then return false end
  if type(issecretvalue) == "function" and issecretvalue(value) then return false end
  return true
end
ns.IsReadable = readable

function ns.Print(fmt, ...)
  if not (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage) then return end
  local msg = select("#", ...) > 0 and string.format(tostring(fmt), ...) or tostring(fmt)
  -- Never let a user-supplied word inject chat markup into our output.
  DEFAULT_CHAT_FRAME:AddMessage("|cff59f0c8BanterBlocker:|r " .. msg:gsub("|", "||"))
end

function ns.RefreshStatus()
  if ns.window and ns.window.RefreshStatus then ns.window:RefreshStatus() end
end

-- ── SavedVariables ──────────────────────────────────────────────────────────

local function cleanWords(raw)
  local out, seen = {}, {}
  if type(raw) == "table" then
    for _, w in ipairs(raw) do
      if type(w) == "string" then
        local word = Engine.Normalize(w)
        if word ~= "" and #word <= ns.MAX_WORD_BYTES and not seen[word] then
          out[#out + 1] = word
          seen[word] = true
        end
      end
    end
  end
  return out
end

local function newList(name)
  return { name = name, enabled = true, words = {} }
end

local function validListName(name)
  if type(name) ~= "string" then return nil end
  name = Engine.Trim(name)
  if name == "" or #name > ns.MAX_LIST_NAME_BYTES then return nil end
  return name
end

function ns.FindList(name)
  if not ns.db or type(name) ~= "string" then return nil end
  local wanted = Engine.Lower(name)
  for _, list in ipairs(ns.db.lists) do
    if Engine.Lower(list.name) == wanted then return list end
  end
end

local function mergeFileLists(db)
  if not ns.useFileLists or type(ns.fileLists) ~= "table" then return end
  for _, fileList in ipairs(ns.fileLists) do
    if type(fileList) == "table" then
      local name = validListName(fileList.name)
      local parsed
      if type(fileList.words) == "string" then
        parsed = Engine.ParseWords(fileList.words)
      elseif type(fileList.words) == "table" then
        parsed = cleanWords(fileList.words)
      end
      if name and parsed then
        local list = ns.FindList(name)
        if not list then
          list = newList(name)
          list.enabled = fileList.enabled ~= false
          table.insert(db.lists, list)
        end
        local existing = {}
        for _, w in ipairs(list.words) do existing[w] = true end
        for _, w in ipairs(parsed) do
          if not existing[w] then
            table.insert(list.words, w)
            existing[w] = true
          end
        end
      end
    end
  end
end

function ns.InitDB()
  if ns.ready then return end
  -- Adopt pre-rename NoNoiseChatDB data; both names are declared in the toc
  -- so the old table is still loaded by the client. New keys win on conflict.
  local db = type(BanterBlockerDB) == "table" and BanterBlockerDB or {}
  if type(NoNoiseChatDB) == "table" then
    for k, v in pairs(NoNoiseChatDB) do
      if db[k] == nil then db[k] = v end
    end
    if type(db.lists) ~= "table" or #db.lists == 0 then
      db.lists = NoNoiseChatDB.lists
    end
  end
  BanterBlockerDB = db

  for key, default in pairs({ enabled = true, wholeWords = true, filterOwn = false, logTab = true }) do
    if type(db[key]) ~= "boolean" then db[key] = default end
  end

  if type(db.chatTypes) ~= "table" then db.chatTypes = {} end
  for _, chatType in ipairs(ns.CHAT_TYPES) do
    if type(db.chatTypes[chatType.key]) ~= "boolean" then
      db.chatTypes[chatType.key] = chatType.default
    end
  end

  if type(db.minimap) ~= "table" then db.minimap = {} end
  if type(db.minimap.hide) ~= "boolean" then db.minimap.hide = false end
  if type(db.minimap.angle) ~= "number" or db.minimap.angle ~= db.minimap.angle
      or math.abs(db.minimap.angle) > 10000 then
    db.minimap.angle = 225
  end
  if db.wordSort ~= "added" and db.wordSort ~= "name" and db.wordSort ~= "count" then
    db.wordSort = "added"
  end

  -- Validate/repair the named-list structure; migrate v1's flat db.words.
  if type(db.lists) ~= "table" then db.lists = {} end
  local cleaned, seenNames = {}, {}
  for _, entry in ipairs(db.lists) do
    if type(entry) == "table" then
      local name = validListName(entry.name)
      if name and not seenNames[Engine.Lower(name)] then
        seenNames[Engine.Lower(name)] = true
        cleaned[#cleaned + 1] = {
          name = name,
          enabled = entry.enabled ~= false,
          words = cleanWords(entry.words),
        }
      end
    end
  end
  db.lists = cleaned
  ns.db = db
  if type(db.words) == "table" then
    local legacy = ns.FindList("Custom") or newList("Custom")
    legacy.words = cleanWords(db.words)
    if not ns.FindList("Custom") then table.insert(db.lists, 1, legacy) end
    db.words = nil
  end

  mergeFileLists(db)

  if type(db.activeList) ~= "string" or not ns.FindList(db.activeList) then
    db.activeList = db.lists[1] and db.lists[1].name or nil
  end

  ns.InitStats()
  ns.RebuildMatcher()
  ns.ready = true
end

-- ── Matcher ─────────────────────────────────────────────────────────────────

function ns.RebuildMatcher()
  local entries = {}
  if ns.db then
    for _, list in ipairs(ns.db.lists) do
      if list.enabled then
        for _, word in ipairs(list.words) do
          entries[#entries + 1] = { word = word, list = list.name }
        end
      end
    end
  end
  ns.matcher = Engine.BuildMatcher(entries)
  ns.wordCount = #entries
  ns.WipeCaches()
end

-- ── List operations ─────────────────────────────────────────────────────────

function ns.NewList(name)
  name = validListName(name)
  if not name then return false, "Invalid list name." end
  if ns.FindList(name) then return false, "A list with that name already exists." end
  local list = newList(name)
  table.insert(ns.db.lists, list)
  ns.db.activeList = list.name
  if ns.RefreshStatus then ns.RefreshStatus() end
  return true, list
end

function ns.RenameList(name, newName)
  local list = ns.FindList(name)
  if not list then return false, "List not found." end
  newName = validListName(newName)
  if not newName then return false, "Invalid list name." end
  if Engine.Lower(newName) ~= Engine.Lower(list.name) and ns.FindList(newName) then
    return false, "A list with that name already exists."
  end
  local old = list.name
  list.name = newName
  if ns.db.activeList == old then ns.db.activeList = newName end
  if ns.db.stats.byList[old] then
    ns.db.stats.byList[newName] = ns.db.stats.byList[old]
    ns.db.stats.byList[old] = nil
  end
  ns.RebuildMatcher()
  if ns.RefreshStatus then ns.RefreshStatus() end
  return true
end

function ns.DeleteList(name)
  local list = ns.FindList(name)
  if not list then return false, "List not found." end
  for i, l in ipairs(ns.db.lists) do
    if l == list then table.remove(ns.db.lists, i) break end
  end
  if ns.db.activeList == list.name then
    ns.db.activeList = ns.db.lists[1] and ns.db.lists[1].name or nil
  end
  ns.RebuildMatcher()
  if ns.RefreshStatus then ns.RefreshStatus() end
  return true
end

function ns.SetListEnabled(name, on)
  local list = ns.FindList(name)
  if not list then return false end
  list.enabled = on and true or false
  ns.RebuildMatcher()
  if ns.RefreshStatus then ns.RefreshStatus() end
  return true
end

function ns.ActiveList()
  return (ns.db.activeList and ns.FindList(ns.db.activeList)) or ns.db.lists[1]
end

-- Text may hold several words separated by newlines/commas/semicolons.
-- Returns counts: added, skippedDuplicates.
function ns.AddWords(listName, text)
  local list = ns.FindList(listName)
  if not list then return false, "List not found." end
  local parsed, err = Engine.ParseWords(text)
  if not parsed then return false, err end
  local existing = {}
  for _, w in ipairs(list.words) do existing[w] = true end
  local added, skipped = 0, 0
  for _, w in ipairs(parsed) do
    if existing[w] then
      skipped = skipped + 1
    else
      table.insert(list.words, w)
      existing[w] = true
      added = added + 1
    end
  end
  if added > 0 then ns.RebuildMatcher() end
  if ns.RefreshStatus then ns.RefreshStatus() end
  return true, added, skipped
end

function ns.RemoveWord(listName, word)
  local list = ns.FindList(listName)
  if not list then return false, "List not found." end
  local wanted = Engine.Normalize(word)
  for i, w in ipairs(list.words) do
    if w == wanted then
      table.remove(list.words, i)
      ns.RebuildMatcher()
      if ns.RefreshStatus then ns.RefreshStatus() end
      return true
    end
  end
  return false, "Not in that list."
end

function ns.ClearList(name)
  local list = ns.FindList(name)
  if not list then return false end
  wipe(list.words)
  ns.RebuildMatcher()
  if ns.RefreshStatus then ns.RefreshStatus() end
  return true
end

function ns.ImportStarter(name)
  local wanted = Engine.Lower(name or "")
  for _, starter in ipairs(ns.STARTER_LISTS) do
    if Engine.Lower(starter.name):find(wanted, 1, true) then
      local list = ns.FindList(starter.name)
      if not list then
        list = newList(starter.name)
        table.insert(ns.db.lists, list)
      end
      local existing = {}
      for _, w in ipairs(list.words) do existing[w] = true end
      local added = 0
      for _, w in ipairs(starter.words) do
        local word = Engine.Normalize(w)
        if word ~= "" and not existing[word] then
          table.insert(list.words, word)
          existing[word] = true
          added = added + 1
        end
      end
      ns.db.activeList = list.name
      ns.RebuildMatcher()
      if ns.RefreshStatus then ns.RefreshStatus() end
      return true, starter.name, added
    end
  end
  return false, "Unknown starter list."
end

-- ── Filtering ───────────────────────────────────────────────────────────────

local outgoing = {
  CHAT_MSG_WHISPER_INFORM = true,
  CHAT_MSG_BN_WHISPER_INFORM = true,
  CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM = true,
}

function ns.CapturePlayer()
  ns.playerGUID = type(UnitGUID) == "function" and UnitGUID("player") or nil
  local name, realm
  if type(UnitFullName) == "function" then
    name, realm = UnitFullName("player")
  elseif type(UnitName) == "function" then
    name, realm = UnitName("player")
  end
  if not readable(name) or type(name) ~= "string" then return end
  ns.playerName = Engine.Lower(name)
  if (not realm or realm == "") and type(GetRealmName) == "function" then
    realm = GetRealmName()
  end
  if readable(realm) and type(realm) == "string" and realm ~= "" then
    ns.playerFullName = ns.playerName .. "-" .. Engine.Lower(realm:gsub("%s", ""))
  end
end

function ns.Evaluate(event, message, author, ...)
  if not ns.ready or not ns.db.enabled or not ns.matcher then return false end
  local group = ns.EVENT_TO_KEY[event]
  if not group or not ns.db.chatTypes[group] then return false end
  if not readable(message) or type(message) ~= "string" then return false end

  -- GM / developer messages are deliberately left untouched.
  local flags = select(4, ...)
  if readable(flags) and (flags == "GM" or flags == "DEV") then return false end

  if not ns.db.filterOwn then
    if outgoing[event] then return false end
    local guid = select(10, ...)
    if readable(guid) and readable(ns.playerGUID) and guid and guid == ns.playerGUID then
      return false
    end
    if readable(author) and type(author) == "string" then
      local authorLower = Engine.Lower(author)
      if authorLower == ns.playerFullName or authorLower == ns.playerName then
        return false
      end
    end
  end

  -- The match result is deterministic per message; cache it so each message
  -- is evaluated once instead of once per chat frame.
  local lineID = ns.UsableLineID(select(9, ...))
  local key = lineID and (event .. "\031" .. lineID)
      or (event .. "\031" .. tostring(author) .. "\031" .. message)
  return ns.CachedDecision(key, function()
    return Engine.Match(Engine.VisibleText(message), ns.matcher, ns.db.wholeWords)
  end)
end

-- ── Blocked-message log tab ────────────────────────────────────────────────

local logFrame

-- Returns (or lazily creates) the dedicated "Blocked" chat window. Reuses a
-- window that survived a previous session instead of duplicating it.
function ns.GetLogFrame()
  if logFrame and logFrame:IsShown() then return logFrame end
  logFrame = nil
  if type(FCF_GetChatWindowInfo) == "function" then
    for i = 1, (NUM_CHAT_WINDOWS or 20) do
      local name = FCF_GetChatWindowInfo(i)
      if name == "Blocked" then
        local f = _G["ChatFrame" .. i]
        if f and f.AddMessage then logFrame = f return f end
      end
    end
  end
  if type(FCF_OpenNewWindow) == "function" then
    local ok, f = pcall(FCF_OpenNewWindow, "Blocked")
    if ok and f and f.AddMessage then logFrame = f return f end
  end
end

function ns.LogBlocked(entry, event, message, author, ...)
  if not ns.db.logTab then return end
  local f = ns.GetLogFrame()
  if not f then return end
  local source = ns.EVENT_TO_KEY[event] or event
  local chName = select(7, ...) -- channel base name
  if event == "CHAT_MSG_CHANNEL" and readable(chName) and type(chName) == "string"
      and chName ~= "" then
    source = chName
  end
  f:AddMessage(("|cff8c8c8c[%s|%s]|r |cffffd36b%s:|r %s"):format(
    tostring(source), tostring(entry.word), tostring(author or "?"),
    tostring(message)))
end

-- Return only true/false: never hand modified arguments back into the shared
-- filter pipeline, and never let an error unblock a message or spam the UI.
function ns.Filter(frame, event, message, author, ...)
  local ok, entry = pcall(ns.Evaluate, event, message, author, ...)
  if not ok then
    if not ns.filterError then
      ns.filterError = "A chat filter error occurred; the affected message was left visible."
      ns.Print(ns.filterError .. " Run /banter status.")
    end
    return false
  end
  if entry then
    -- One dedupe serves both the counter and the log tab.
    local okFirst, first = pcall(ns.FirstDelivery, frame, event, message, author, ...)
    if okFirst and first then
      local counted = pcall(ns.CountBlocked, entry)
      if not counted and not ns.counterError then
        ns.counterError = "Counter update failed; chat filtering continues."
        ns.Print(ns.counterError .. " Run /banter status.")
      end
      local logged = pcall(ns.LogBlocked, entry, event, message, author, ...)
      if not logged and not ns.logError then
        ns.logError = "Blocked-message log failed; chat filtering continues."
        ns.Print(ns.logError .. " Run /banter status.")
      end
    end
  end
  return entry and true or false
end

local function getFilterAPI()
  if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.AddMessageEventFilter) == "function" then
    return ChatFrameUtil.AddMessageEventFilter, "ChatFrameUtil"
  end
  if type(ChatFrame_AddMessageEventFilter) == "function" then
    return ChatFrame_AddMessageEventFilter, "ChatFrame_AddMessageEventFilter"
  end
end

function ns.RegisterFilters()
  local addFilter, apiName = getFilterAPI()
  if not addFilter then return false end
  ns.apiName = apiName
  local failures = 0
  for event in pairs(ns.EVENT_TO_KEY) do
    local valid = true
    if type(C_EventUtils) == "table" and type(C_EventUtils.IsEventValid) == "function" then
      local ok, exists = pcall(C_EventUtils.IsEventValid, event)
      if ok and exists == false then valid = false end
    end
    if valid and not registered[event] then
      local ok = pcall(addFilter, event, ns.Filter)
      if ok then
        registered[event] = true
        ns.registrationCount = ns.registrationCount + 1
      else
        failures = failures + 1
      end
    end
  end
  ns.registrationFailures = failures
  return ns.registrationCount > 0
end

-- ── Status ──────────────────────────────────────────────────────────────────

function ns.StatusText()
  if ns.registrationCount == 0 then
    return "NOT ACTIVE: this client has no available chat filter API."
  end
  if not ns.db.enabled then return "Paused. Existing chat history is unchanged." end
  if ns.wordCount == 0 then return "No words in enabled lists: nothing is being filtered." end
  local selected = false
  for _, chatType in ipairs(ns.CHAT_TYPES) do
    if ns.db.chatTypes[chatType.key] then selected = true break end
  end
  if not selected then return "No chat types selected: nothing is being filtered." end
  local text = "Active: " .. ns.wordCount .. " words across "
      .. #ns.db.lists .. " lists / " .. ns.registrationCount .. " events"
  if ns.registrationFailures > 0 then text = text .. " (some registrations failed)" end
  if ns.filterError then text = text .. " (filter error; see /banter status)" end
  return text
end

function ns.ShowStatus()
  ns.Print("v" .. ns.version .. " | " .. ns.StatusText())
  ns.Print("API: " .. ns.apiName .. "; whole words: " .. tostring(ns.db.wholeWords)
      .. "; hide own messages: " .. tostring(ns.db.filterOwn) .. ".")
  if type(GetBuildInfo) == "function" then
    local version, build, _, interface = GetBuildInfo()
    ns.Print("Client " .. tostring(version) .. " build " .. tostring(build)
        .. "; interface " .. tostring(interface) .. ".")
  end
  ns.Print("Blocked: " .. ns.FormatCount(ns.db.stats.total) .. " total; "
      .. ns.FormatCount(ns.sessionBlocked) .. " since login / UI reload.")
  if ns.useFileLists then ns.Print("File lists ON: UserLists.lua is merged at each login.") end
  if ns.filterError then ns.Print(ns.filterError) end
  if ns.counterError then ns.Print(ns.counterError) end
end

-- ── Slash commands ──────────────────────────────────────────────────────────

-- Finds a list name at the start of `rest` (longest match wins, so list names
-- may contain spaces). Returns list, remainingText.
local function splitListPrefix(rest)
  local lowered = Engine.Lower(rest)
  local best
  for _, list in ipairs(ns.db.lists) do
    local ln = Engine.Lower(list.name)
    if lowered == ln or lowered:sub(1, #ln + 1) == ln .. " " then
      if not best or #list.name > #best.name then best = list end
    end
  end
  if best then return best, Engine.Trim(rest:sub(#best.name + 1)) end
end

function ns.Slash(input)
  if not ns.ready then ns.InitDB() end
  local command, rest = (Engine.Trim(input or "")):match("^(%S+)%s*(.-)$")
  command = Engine.Lower(command or "")

  if command == "" or command == "options" or command == "config" then
    ns.OpenOptions()
  elseif command == "on" or command == "off" then
    ns.db.enabled = command == "on"
    ns.Print(command == "on" and "Filtering enabled." or "Filtering paused.")
  elseif command == "status" then
    ns.ShowStatus()
  elseif command == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    ns.Print(ns.db.minimap.hide and "Minimap button hidden." or "Minimap button shown.")
  elseif command == "lists" then
    for _, list in ipairs(ns.db.lists) do
      ns.Print("%s%s: %d words, %s hidden%s", list.name,
        list == ns.ActiveList() and " (active)" or "",
        #list.words,
        ns.FormatCount(ns.db.stats.byList[list.name] or 0),
        list.enabled and "" or " [disabled]")
    end
    if #ns.db.lists == 0 then ns.Print("No lists. /banter newlist <name>") end
  elseif command == "newlist" then
    local ok, result = ns.NewList(rest)
    ns.Print(ok and ("Created list '" .. result.name .. "'.") or result)
  elseif command == "dellist" then
    local ok, err = ns.DeleteList(rest)
    ns.Print(ok and ("Deleted list '" .. rest .. "'.") or err)
  elseif command == "use" then
    local list = ns.FindList(rest)
    if list then
      ns.db.activeList = list.name
      ns.Print("Active list: " .. list.name)
    else
      ns.Print("No list named '" .. rest .. "'.")
    end
  elseif command == "add" or command == "addto" then
    local list, words = ns.ActiveList(), rest
    if command == "addto" then
      list, words = splitListPrefix(rest)
      if not list then ns.Print("Usage: /banter addto <list> <words>"); return end
    end
    if not list then ns.Print("No list selected. /banter newlist <name>"); return end
    local ok, added, skipped = ns.AddWords(list.name, words)
    if ok then
      ns.Print("Added %d word%s to '%s'%s.", added, added == 1 and "" or "s",
        list.name, skipped > 0 and ("; " .. skipped .. " already listed") or "")
    else
      ns.Print(added) -- error message
    end
  elseif command == "remove" or command == "del" then
    local wanted = Engine.Normalize(rest)
    local removed
    for _, list in ipairs(ns.db.lists) do
      for i, w in ipairs(list.words) do
        if w == wanted then
          table.remove(list.words, i)
          removed = list.name
          break
        end
      end
      if removed then break end
    end
    if removed then
      ns.RebuildMatcher()
      ns.Print("Removed '" .. wanted .. "' from '" .. removed .. "'.")
    else
      ns.Print("'" .. wanted .. "' is not in any list.")
    end
  elseif command == "import" then
    local ok, name, added = ns.ImportStarter(rest)
    if ok then ns.Print("Imported %d words into '%s'.", added, name) else ns.Print(name) end
  elseif command == "test" then
    if rest == "" then ns.Print("Usage: /banter test a message to check"); return end
    local entry = Engine.Match(Engine.VisibleText(rest), ns.matcher, ns.db.wholeWords)
    if entry then
      ns.Print("Match: '" .. entry.word .. "' (list: " .. entry.list .. ").")
    else
      ns.Print("No match.")
    end
    if not ns.db.enabled then ns.Print("Filtering is currently paused.") end
  elseif command == "stats" then
    ns.Print("Blocked: " .. ns.FormatCount(ns.db.stats.total) .. " total, "
      .. ns.FormatCount(ns.sessionBlocked) .. " this session.")
    for list, n in pairs(ns.db.stats.byList) do
      ns.Print("  %s: %d", list, n)
    end
  elseif command == "reset" then
    if Engine.Lower(rest or "") == "confirm" then
      ns.ResetStats()
      ns.Print("Counters reset.")
    else
      ns.Print("Type /banter reset confirm to clear the counters.")
    end
  else
    ns.Print("/banter | on | off | status | minimap | lists | newlist <n> | dellist <n> | use <n> | add <w> | addto <list> <w> | remove <w> | import <starter> | test <msg> | stats | reset")
  end
end

SLASH_BANTERBLOCKER1 = "/banter"
SLASH_BANTERBLOCKER2 = "/bb"
SlashCmdList.BANTERBLOCKER = ns.Slash

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, loadedName)
  if event == "ADDON_LOADED" then
    if loadedName == ADDON_NAME then
      ns.InitDB()
      ns.RegisterFilters()
      if ns.RegisterSettings then ns.RegisterSettings() end
    elseif ns.ready and ns.registrationCount == 0 then
      ns.RegisterFilters()
    end
  elseif event == "PLAYER_LOGIN" then
    ns.InitDB()
    ns.CapturePlayer()
    ns.RegisterFilters()
    if ns.CreateMinimapButton then ns.CreateMinimapButton() end
    if ns.RegisterSettings then ns.RegisterSettings() end
    if ns.registrationCount == 0 then
      ns.Print("NOT ACTIVE: no supported chat filter API was found. Run /banter status.")
    else
      ns.Print("v" .. ns.version .. " loaded. Type /banter for settings.")
    end
    if ns.registrationCount > 0 then loader:UnregisterEvent("ADDON_LOADED") end
    loader:UnregisterEvent("PLAYER_LOGIN")
  end
end)
