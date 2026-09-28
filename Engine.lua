local _, ns = ...
local Engine = {}
ns.Engine = Engine

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end
Engine.Trim = trim

-- Explicit ASCII case folding. Locale-dependent lowering can corrupt UTF-8;
-- non-ASCII letters stay literal, which is fine for an English keyword list.
local function lowerASCII(value)
  return (value:gsub("[A-Z]", function(char)
    return string.char(string.byte(char) + 32)
  end))
end
Engine.Lower = lowerASCII

-- Bytes of multi-byte UTF-8 characters used to dodge filters.
local UTF8_FIX = {
  { "\194\160", " " },      -- no-break space
  { "\226\128\175", " " },  -- narrow no-break space
  { "\226\128\139", "" },   -- zero-width space
  { "\226\128\140", "" },   -- zero-width non-joiner
  { "\226\128\141", "" },   -- zero-width joiner
  { "\239\187\191", "" },   -- byte-order mark
  { "\226\128\152", "'" },  -- smart quotes
  { "\226\128\153", "'" },
  { "\226\128\156", '"' },
  { "\226\128\157", '"' },
  { "\226\128\147", "-" },  -- en dash
  { "\226\128\148", "-" },  -- em dash
}

function Engine.Normalize(value)
  if type(value) ~= "string" then return "" end
  for _, fix in ipairs(UTF8_FIX) do
    value = value:gsub(fix[1], fix[2])
  end
  return lowerASCII(trim((value:gsub("%s+", " "))))
end

-- Reduce chat markup to what the player actually sees.
function Engine.VisibleText(value)
  -- Protect literal escaped pipes before interpreting display markup.
  value = value:gsub("\001", " "):gsub("||", "\001")
  -- Keep the visible hyperlink label, drop item IDs and hidden payloads.
  value = value:gsub("|H.-|h(.-)|h", "%1")
  value = value:gsub("|T.-|t", " "):gsub("|A.-|a", " ")
  value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
  value = value:gsub("|cn[%w_]+:", "")
  value = value:gsub("|r", "")
  value = value:gsub("|K[^|]*|k", ""):gsub("|N[^|]*|n", ""):gsub("|W[^|]*|w", "")
  value = value:gsub("\001", "|")
  return Engine.Normalize(value)
end

-- Parse user input into normalized words. Accepts lines, commas or semicolons.
function Engine.ParseWords(text)
  if type(text) ~= "string" then return nil, "The word list must be text." end
  if #text > ns.MAX_IMPORT_BYTES then
    return nil, "Input is too large (maximum " .. ns.MAX_IMPORT_BYTES .. " bytes)."
  end
  local list, seen = {}, {}
  for entry in text:gmatch("[^\r\n,;]+") do
    local word = Engine.Normalize(entry)
    if word ~= "" and not seen[word] then
      if #word > ns.MAX_WORD_BYTES then
        return nil, "Each word or phrase must be at most " .. ns.MAX_WORD_BYTES .. " bytes."
      end
      if word:find("[%z\1-\31\127]") then
        return nil, "Words cannot contain control characters."
      end
      list[#list + 1] = word
      seen[word] = true
    end
  end
  return list
end

-- Whole-word matching needs UTF-8-aware boundaries: a boundary may sit on a
-- continuation byte, so decode the character containing the position. Common
-- Unicode punctuation, symbols and emoji count as separators ("trump🙂"
-- still matches "trump"), other letters do not.
local function isWordByte(text, pos)
  if pos < 1 or pos > #text then return false end
  local byte = string.byte(text, pos)
  if byte < 128 then
    return (byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 122)
        or (byte >= 65 and byte <= 90) or byte == 95
  end
  local start = pos
  while start > 1 and byte >= 128 and byte < 192 do
    start = start - 1
    byte = string.byte(text, start)
  end
  local length, code
  if byte >= 194 and byte <= 223 then length, code = 2, byte - 192
  elseif byte >= 224 and byte <= 239 then length, code = 3, byte - 224
  elseif byte >= 240 and byte <= 244 then length, code = 4, byte - 240
  else return true end -- malformed UTF-8: treat conservatively as a word byte
  for index = 1, length - 1 do
    local nextByte = string.byte(text, start + index)
    if not nextByte or nextByte < 128 or nextByte > 191 then return true end
    code = code * 64 + nextByte - 128
  end
  if (code >= 0x2000 and code <= 0x206F) or (code >= 0x2E00 and code <= 0x2E7F)
      or (code >= 0x3000 and code <= 0x303F) or (code >= 0x2600 and code <= 0x27BF)
      or (code >= 0x1F000 and code <= 0x1FAFF) or (code >= 0xFE00 and code <= 0xFE0F)
      or (code >= 0xFF01 and code <= 0xFF0F) or (code >= 0xFF1A and code <= 0xFF20)
      or (code >= 0xFF3B and code <= 0xFF40) or (code >= 0xFF5B and code <= 0xFF65)
      or (code >= 0xA0 and code <= 0xBF and code ~= 0xAA and code ~= 0xB5 and code ~= 0xBA) then
    return false
  end
  return true
end
Engine.IsWordByte = isWordByte

-- Aho-Corasick: build a trie of all words plus failure links, then matching is
-- one pass over the message regardless of list size. Entries carry the list
-- name so a hit can be attributed for stats.
function Engine.BuildMatcher(entries)
  local root = { next = {}, out = {} }
  for _, entry in ipairs(entries) do
    local node = root
    for i = 1, #entry.word do
      local b = string.byte(entry.word, i)
      local nxt = node.next[b]
      if not nxt then
        nxt = { next = {}, out = {} }
        node.next[b] = nxt
      end
      node = nxt
    end
    node.out[#node.out + 1] = entry
  end

  local queue = {}
  for _, child in pairs(root.next) do
    child.fail = root
    queue[#queue + 1] = child
  end
  local head = 1
  while head <= #queue do
    local node = queue[head]
    head = head + 1
    for b, child in pairs(node.next) do
      local f = node.fail
      while f ~= root and not f.next[b] do
        f = f.fail
      end
      local fallback = f.next[b]
      child.fail = (fallback and fallback ~= child) and fallback or root
      for i = 1, #child.fail.out do
        child.out[#child.out + 1] = child.fail.out[i]
      end
      queue[#queue + 1] = child
    end
  end
  return root
end

-- Returns the first matching entry ({ word, list }) or nil. Words are literal
-- bytes, never Lua patterns.
function Engine.Match(text, root, wholeWords)
  if not root or text == "" then return nil end
  local node = root
  for i = 1, #text do
    local b = string.byte(text, i)
    while node ~= root and not node.next[b] do
      node = node.fail
    end
    node = node.next[b] or root
    local outs = node.out
    for j = 1, #outs do
      local entry = outs[j]
      local word = entry.word
      local first = i - #word + 1
      if not wholeWords or
          ((not isWordByte(word, 1) or not isWordByte(text, first - 1)) and
           (not isWordByte(word, #word) or not isWordByte(text, i + 1))) then
        return entry
      end
    end
  end
  return nil
end
