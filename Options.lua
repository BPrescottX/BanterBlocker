local _, ns = ...
local Engine = ns.Engine

local ROW_H = 20
local WIN_W, WIN_H = 640, 680
local MIN_W, MIN_H = 620, 660
local MAX_W, MAX_H = 1600, 1400

local ICON_PATH = "Interface\\AddOns\\BanterBlocker\\BanterBlockerIcon.tga"
local HOMEPAGE = "https://www.deploycat.app"
local SORT_LABELS = { added = "Added", name = "A-Z", count = "Most used" }
local SORT_NEXT = { added = "name", name = "count", count = "added" }

local window, settingsPanel

-- ── small control factories ─────────────────────────────────────────────────

local function label(parent, text, x, y, width, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetWidth(width)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetText(text)
  return fs
end

local function boxed(parent, alpha)
  local frame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.04, alpha or 0.4)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
  end
  return frame
end

local function button(parent, text, x, y, w, callback)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", callback)
  return b
end

local function checkbox(parent, text, x, y, width, getter, setter)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local fs = cb.Text or cb.text
  if not fs then
    fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  end
  fs:SetWidth(width)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  cb:SetChecked(getter())
  cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
  return cb
end

-- ── popups ──────────────────────────────────────────────────────────────────

if not StaticPopupDialogs["BANTERBLOCKER_NAME_LIST"] then
  StaticPopupDialogs["BANTERBLOCKER_NAME_LIST"] = {
    text = "%s",
    button1 = "OK",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 40,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    exclusive = true,
    preferredIndex = 3,
    OnAccept = function(self, data)
      local eb = self.editBox or self.EditBox
      local text = eb and eb:GetText() or ""
      if data and data.action == "rename" then
        local ok, err = ns.RenameList(data.name, text)
        if not ok then ns.Print(err) end
      else
        local ok, result = ns.NewList(text)
        if not ok then ns.Print(result) end
      end
    end,
  }
  StaticPopupDialogs["BANTERBLOCKER_DELETE_LIST"] = {
    text = "Delete list '%s' and all its words?",
    button1 = "Delete",
    button2 = "Cancel",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    exclusive = true,
    preferredIndex = 3,
    OnAccept = function(self, data)
      if data then ns.DeleteList(data.name) end
    end,
  }
  -- WoW can't open a browser, so the "hyperlink" shows a copyable URL.
  StaticPopupDialogs["BANTERBLOCKER_URL"] = {
    text = "Copy this link:",
    button1 = "Done",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    exclusive = true,
    preferredIndex = 3,
    OnShow = function(self)
      local eb = self.editBox or self.EditBox
      if eb then
        eb:SetText(HOMEPAGE)
        eb:HighlightText()
        eb:SetFocus()
      end
    end,
  }
end

local function popupNameList(action, name)
  local prompt = action == "rename" and ("Rename '" .. name .. "' to:") or "New list name:"
  local dialog = StaticPopup_Show("BANTERBLOCKER_NAME_LIST", prompt, nil, { action = action, name = name })
  if dialog then
    local eb = dialog.editBox or dialog.EditBox
    if eb then
      eb:SetText(action == "rename" and name or "")
      eb:HighlightText()
    end
  end
end

-- ── main window ─────────────────────────────────────────────────────────────

local function createWindow()
  window = CreateFrame("Frame", "BanterBlockerWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  window:SetSize(WIN_W, WIN_H)
  window:SetPoint("CENTER", UIParent, "CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  if window.SetBackdrop then
    window:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    window:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    window:SetBackdropBorderColor(0.55, 0.5, 0.35, 1)
  end
  if type(UISpecialFrames) == "table" then
    UISpecialFrames[#UISpecialFrames + 1] = "BanterBlockerWindow"
  end

  -- Draggable title bar
  local drag = CreateFrame("Frame", nil, window)
  drag:SetPoint("TOPLEFT", 4, -4)
  drag:SetPoint("TOPRIGHT", -36, -4)
  drag:SetHeight(40)
  drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function() window:StartMoving() end)
  drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)

  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() window:Hide() end)

  -- Bottom-right resize grip
  if window.SetResizeBounds then
    window:SetResizable(true)
    window:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
  elseif window.SetMinResize then
    window:SetResizable(true)
    window:SetMinResize(MIN_W, MIN_H)
  end
  local grip = CreateFrame("Button", nil, window)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function(_, btn)
    if btn == "LeftButton" then window:StartSizing("BOTTOMRIGHT") end
  end)
  grip:SetScript("OnMouseUp", function() window:StopMovingOrSizing() end)

  local titleIcon = window:CreateTexture(nil, "ARTWORK")
  titleIcon:SetTexture(ICON_PATH)
  titleIcon:SetSize(24, 24)
  titleIcon:SetPoint("TOPLEFT", 16, -11)
  label(window, "BanterBlocker  |cff8c8c8cv" .. ns.version .. "|r", 48, -16, 460, "GameFontNormalLarge")
  label(window, "Free Trade Chat! Leave the real world behind and enjoy Azeroth!", 22, -42, 540)

  -- Global options, two rows
  window.filterButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
  window.filterButton:SetSize(150, 34)
  window.filterButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -20, -62)
  window.filterButton:SetScript("OnClick", function()
    ns.db.enabled = not ns.db.enabled
    ns.RefreshStatus()
  end)
  local function updateFilterButton()
    local enabled = ns.db.enabled
    window.filterButton:SetText(enabled and "Filtering ON" or "Filtering OFF")
    for _, region in ipairs({ window.filterButton:GetRegions() }) do
      if region:GetObjectType() == "Texture" then
        region:SetDesaturated(enabled)
        region:SetVertexColor(enabled and 0.2 or 1, 1, enabled and 0.2 or 1)
      end
    end
  end
  window.cbWhole = checkbox(window, "Whole words", 20, -66, 120,
    function() return ns.db.wholeWords end,
    function(v) ns.db.wholeWords = v; ns.RebuildMatcher(); ns.RefreshStatus() end)
  window.cbOwn = checkbox(window, "Hide my messages", 20, -90, 140,
    function() return ns.db.filterOwn end,
    function(v) ns.db.filterOwn = v end)
  window.cbLog = checkbox(window, "Log to tab", 170, -90, 130,
    function() return ns.db.logTab end,
    function(v) ns.db.logTab = v end)
  window.cbMini = checkbox(window, "Minimap button", 310, -90, 140,
    function() return not ns.db.minimap.hide end,
    function(v) ns.db.minimap.hide = not v; ns.UpdateMinimapButton() end)

  label(window, "Apply the filter to:", 22, -120, 300, "GameFontNormal")
  window.chatChecks = {}
  for i, chatType in ipairs(ns.CHAT_TYPES) do
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    local key = chatType.key
    window.chatChecks[key] = checkbox(window, chatType.label,
      20 + col * 140, -142 - row * 24, 128,
      function() return ns.db.chatTypes[key] end,
      function(v) ns.db.chatTypes[key] = v; ns.RefreshStatus() end)
  end

  -- ── left column: lists ──
  label(window, "Lists", 20, -226, 150, "GameFontNormal")
  local listsBox = boxed(window)
  listsBox:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -246)
  listsBox:SetSize(178, 122)
  local listsScroll = CreateFrame("ScrollFrame", "BanterBlockerListsScroll", listsBox, "UIPanelScrollFrameTemplate")
  listsScroll:SetPoint("TOPLEFT", 4, -4)
  listsScroll:SetPoint("BOTTOMRIGHT", -4, 4)
  local listsChild = CreateFrame("Frame")
  listsChild:SetSize(148, 1)
  listsScroll:SetScrollChild(listsChild)

  local listRows = {}
  local RefreshWords -- forward declaration; defined with the word list below
  local function RefreshLists()
    for _, r in ipairs(listRows) do r:Hide() end
    local active = ns.ActiveList()
    for i, list in ipairs(ns.db.lists) do
      local row = listRows[i]
      if not row then
        row = CreateFrame("Button", nil, listsChild)
        row:SetSize(148, ROW_H)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(0.35, 0.6, 0.5, 0.35)
        row.cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.cb:SetPoint("LEFT", -4, 0)
        row.cb:SetScale(0.75)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 22, 0)
        row.text:SetPoint("RIGHT", -2, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        listRows[i] = row
      end
      row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
      row.text:SetText(list.name)
      row.cb:SetChecked(list.enabled)
      row.cb:SetScript("OnClick", function(self)
        ns.SetListEnabled(list.name, self:GetChecked())
      end)
      row:SetScript("OnClick", function()
        ns.db.activeList = list.name
        RefreshLists()
        RefreshWords()
        window.RefreshStatus()
      end)
      row.hl:SetShown(list == active)
      row:Show()
    end
    listsChild:SetHeight(math.max(#ns.db.lists * ROW_H, 1))
  end

  button(window, "New", 20, -374, 50, function() popupNameList("new") end)
  button(window, "Rename", 74, -374, 58, function()
    local active = ns.ActiveList()
    if active then popupNameList("rename", active.name) end
  end)
  button(window, "Delete", 140, -374, 58, function()
    local active = ns.ActiveList()
    if active then
      StaticPopup_Show("BANTERBLOCKER_DELETE_LIST", active.name, nil, { name = active.name })
    end
  end)

  label(window, "Add a starter list:", 20, -404, 178)
  for i, starter in ipairs(ns.STARTER_LISTS) do
    local short = starter.name:gsub(" words", "")
    button(window, "+ " .. short, 20, -424 - (i - 1) * 24, 178, function()
      local ok, name, added = ns.ImportStarter(starter.name)
      if ok then
        ns.Print("Imported %d words into '%s'.", added, name)
      else
        ns.Print(name)
      end
    end)
  end

  -- ── right column: words in the active list ──
  window.listHeader = label(window, "", 222, -226, 400, "GameFontNormal")

  local addBox = CreateFrame("EditBox", "BanterBlockerAddBox", window, "InputBoxTemplate")
  addBox:SetSize(178, 26)
  addBox:SetPoint("TOPLEFT", window, "TOPLEFT", 226, -250)
  addBox:SetAutoFocus(false)
  addBox:SetMaxLetters(4096)
  addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local function tryAdd()
    local list = ns.ActiveList()
    if not list then
      ns.Print("Create a list first.")
      return
    end
    local text = Engine.Trim(addBox:GetText() or "")
    if text == "" then return end
    local ok, added, skipped = ns.AddWords(list.name, text)
    if ok then
      addBox:SetText("")
      if added == 0 and skipped > 0 then
        ns.Print("Already listed.")
      end
    else
      ns.Print(added)
    end
    addBox:ClearFocus()
  end

  local addBtn = button(window, "Add", 412, -251, 60, tryAdd)
  addBtn:SetHeight(24)
  addBox:SetScript("OnEnterPressed", tryAdd)

  -- The word list box stretches with the window.
  local wordsBox = boxed(window)
  wordsBox:SetPoint("TOPLEFT", window, "TOPLEFT", 222, -282)
  wordsBox:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -20, 120)

  local wordsScroll = CreateFrame("ScrollFrame", "BanterBlockerWordsScroll", wordsBox, "UIPanelScrollFrameTemplate")
  wordsScroll:SetPoint("TOPLEFT", 4, -4)
  wordsScroll:SetPoint("BOTTOMRIGHT", -4, 4)
  local wordsChild = CreateFrame("Frame")
  wordsChild:SetSize(340, 1)
  wordsScroll:SetScrollChild(wordsChild)

  local emptyText = wordsBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  emptyText:SetPoint("CENTER")
  emptyText:SetText("No words yet - add some above.")

  local wordRows = {}
  local function ensureWordRows(n)
    for i = #wordRows + 1, n do
      local row = CreateFrame("Frame", nil, wordsChild)
      row:SetSize(340, ROW_H)
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.text:SetPoint("LEFT", 4, 0)
      row.text:SetJustifyH("LEFT")
      row.text:SetWordWrap(false)
      row.count = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      row.count:SetPoint("RIGHT", -30, 0)
      row.count:SetJustifyH("RIGHT")
      row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      row.remove:SetSize(22, 18)
      row.remove:SetPoint("RIGHT", -4, 0)
      row.remove:SetText("X")
      row.text:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
      wordRows[i] = row
    end
  end

  RefreshWords = function()
    local list = ns.ActiveList()
    local words = list and list.words or {}
    -- Display order only; list.words itself keeps insertion order for the matcher.
    local sorted = words
    if #words > 1 and ns.db.wordSort ~= "added" then
      sorted = {}
      for i, w in ipairs(words) do sorted[i] = w end
      if ns.db.wordSort == "count" then
        local counts = ns.db.stats.byWord
        table.sort(sorted, function(a, b)
          local ca, cb = counts[a] or 0, counts[b] or 0
          if ca ~= cb then return ca > cb end
          return a < b
        end)
      else
        table.sort(sorted)
      end
    end
    local visRows = math.max(1, math.floor(wordsScroll:GetHeight() / ROW_H))
    ensureWordRows(visRows)
    local rowW = math.max(80, wordsChild:GetWidth())
    local offset = math.floor(wordsScroll:GetVerticalScroll() / ROW_H + 0.5)
    for i, row in ipairs(wordRows) do
      local idx = offset + i
      local word = sorted[idx]
      if i <= visRows and word then
        row:SetWidth(rowW)
        row:SetPoint("TOPLEFT", 0, -(idx - 1) * ROW_H)
        row.text:SetText(word)
        local n = ns.db.stats.byWord[word] or 0
        row.count:SetText(n > 0 and ("x" .. ns.FormatCount(n)) or "")
        row.remove:SetScript("OnClick", function() ns.RemoveWord(list.name, word) end)
        row:Show()
      else
        row:Hide()
      end
    end
    wordsChild:SetHeight(math.max(#sorted * ROW_H, 1))
    emptyText:SetShown(#sorted == 0)
    window.listHeader:SetText(list
      and string.format("Words in '%s'  |cff8c8c8c%d words, %s hidden|r", list.name,
        #words, ns.FormatCount(ns.db.stats.byList[list.name] or 0))
      or "No list selected.")
  end
  wordsScroll:SetScript("OnVerticalScroll", RefreshWords)
  wordsScroll:SetScript("OnShow", RefreshWords)
  wordsScroll:SetScript("OnSizeChanged", function()
    wordsChild:SetWidth(math.max(80, wordsScroll:GetWidth()))
    RefreshWords()
  end)
  window:SetScript("OnSizeChanged", function()
    wordsChild:SetWidth(math.max(80, wordsScroll:GetWidth()))
    RefreshWords()
  end)

  local clearBtn = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
  clearBtn:SetSize(80, 22)
  clearBtn:SetPoint("TOPRIGHT", wordsBox, "BOTTOMRIGHT", -96, -4)
  clearBtn:SetText("Clear list")
  clearBtn:SetScript("OnClick", function(self)
    if not self.confirm then
      self.confirm = true
      self:SetText("Confirm?")
      return
    end
    self.confirm = false
    self:SetText("Clear list")
    local list = ns.ActiveList()
    if list then ns.ClearList(list.name) end
  end)

  local pasteBtn = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
  pasteBtn:SetSize(90, 22)
  pasteBtn:SetPoint("TOPRIGHT", wordsBox, "BOTTOMRIGHT", 0, -4)
  pasteBtn:SetText("Import list")
  pasteBtn:SetScript("OnClick", function() ns.OpenImport() end)

  local exportBtn = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
  exportBtn:SetSize(90, 22)
  exportBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)
  exportBtn:SetText("Export list")
  exportBtn:SetScript("OnClick", function()
    local list = ns.ActiveList()
    if list then ns.OpenExport(list.name) else ns.Print("Select a list first.") end
  end)

  -- Display-order cycle for the word list; the stored order is untouched.
  local sortBtn = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
  sortBtn:SetSize(120, 22)
  sortBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
  local function updateSortBtn()
    sortBtn:SetText("Sort: " .. (SORT_LABELS[ns.db.wordSort] or SORT_LABELS.added))
  end
  sortBtn:SetScript("OnClick", function()
    ns.db.wordSort = SORT_NEXT[ns.db.wordSort] or "added"
    updateSortBtn()
    RefreshWords()
  end)
  sortBtn:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Word order", 1, 1, 1)
    GameTooltip:AddLine("Added: order words were entered. A-Z: alphabetical. Most used: highest block count first.", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
  end)
  sortBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  updateSortBtn()

  -- Footer band: framed stats + status, visually distinct from the window body.
  local footer = boxed(window)
  footer:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 20, 24)
  footer:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -30, 24)
  footer:SetHeight(46)
  if footer.SetBackdropBorderColor then
    footer:SetBackdropBorderColor(0.25, 0.65, 0.55, 0.9) -- teal accent, not gold
  end

  local cap1 = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  cap1:SetPoint("TOPLEFT", 12, -6)
  cap1:SetText("BLOCKED")
  window.totalVal = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  window.totalVal:SetPoint("TOPLEFT", cap1, "BOTTOMLEFT", 0, 0)
  window.totalVal:SetJustifyH("LEFT")

  local cap2 = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  cap2:SetPoint("TOPLEFT", 150, -6)
  cap2:SetText("THIS SESSION")
  window.sessionVal = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  window.sessionVal:SetPoint("TOPLEFT", cap2, "BOTTOMLEFT", 0, 0)
  window.sessionVal:SetJustifyH("LEFT")

  window.status = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  window.status:SetPoint("RIGHT", -108, 0)
  window.status:SetWidth(300)
  window.status:SetJustifyH("RIGHT")

  local resetBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
  resetBtn:SetSize(90, 22)
  resetBtn:SetPoint("RIGHT", -8, 0)
  resetBtn:SetText("Reset")
  resetBtn:SetScript("OnClick", function(self)
    if not self.confirm then
      self.confirm = true
      self:SetText("Confirm?")
      return
    end
    self.confirm = false
    self:SetText("Reset")
    ns.ResetStats()
  end)

  -- Credit line along the bottom edge; the whole line acts as a link.
  local credit = CreateFrame("Button", nil, window)
  credit:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 20, 6)
  credit:SetSize(470, 14)
  local creditText = credit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  creditText:SetAllPoints()
  creditText:SetJustifyH("LEFT")
  local CREDIT_TEXT = "Developed by the team behind www.deploycat.app - Game Hosting"
  creditText:SetText("|cff5f9fdf" .. CREDIT_TEXT .. "|r")
  credit:SetScript("OnEnter", function()
    creditText:SetText("|cff9fd0ff" .. CREDIT_TEXT .. "|r")
  end)
  credit:SetScript("OnLeave", function()
    creditText:SetText("|cff5f9fdf" .. CREDIT_TEXT .. "|r")
  end)
  credit:SetScript("OnClick", function() StaticPopup_Show("BANTERBLOCKER_URL") end)

  function window.RefreshStatus()
    window.totalVal:SetText("|cff59f0c8" .. ns.FormatCount(ns.db.stats.total) .. "|r")
    window.sessionVal:SetText("|cff59f0c8" .. ns.FormatCount(ns.sessionBlocked or 0) .. "|r")
    window.status:SetText(ns.StatusText())
    updateFilterButton()
  end

  local function RefreshAll()
    window.cbWhole:SetChecked(ns.db.wholeWords)
    window.cbOwn:SetChecked(ns.db.filterOwn)
    window.cbLog:SetChecked(ns.db.logTab)
    window.cbMini:SetChecked(not ns.db.minimap.hide)
    for key, cb in pairs(window.chatChecks) do
      cb:SetChecked(ns.db.chatTypes[key])
    end
    RefreshLists()
    RefreshWords()
    window.RefreshStatus()
  end

  window:SetScript("OnShow", function()
    -- Keep the window usable on small screens.
    local scale = math.min(1, (UIParent:GetHeight() - 30) / window:GetHeight(),
      (UIParent:GetWidth() - 30) / window:GetWidth())
    window:SetScale(math.max(0.5, scale))
    RefreshAll()
  end)
  window:SetScript("OnHide", function()
    addBox:ClearFocus()
  end)

  window.RefreshAll = RefreshAll
  window.RefreshLists = RefreshLists
  window.RefreshWords = RefreshWords
  ns.window = window

  -- Core calls this after any data change.
  ns.RefreshStatus = function()
    if window:IsShown() then
      RefreshLists()
      RefreshWords()
    end
    window.RefreshStatus()
  end

  window:Hide()
  return window
end

-- ── paste-import window ─────────────────────────────────────────────────────

local importWin
local function createImportWindow()
  importWin = CreateFrame("Frame", "BanterBlockerImport", UIParent,
    BackdropTemplateMixin and "BackdropTemplate")
  local f = importWin
  f:SetSize(500, 340)
  f:SetPoint("CENTER", UIParent, "CENTER")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
    f:SetBackdropBorderColor(0.55, 0.5, 0.35, 1)
  end
  if type(UISpecialFrames) == "table" then
    UISpecialFrames[#UISpecialFrames + 1] = "BanterBlockerImport"
  end

  f.title = label(f, "Import a word list", 18, -14, 400, "GameFontNormalLarge")
  f.description = label(f, "Paste words or phrases copied from a text file. New lines, commas or semicolons separate entries.", 18, -40, 460)

  f.nameLabel = label(f, "List name (created if it doesn't exist):", 18, -72, 300)
  local nameBox = CreateFrame("EditBox", "BanterBlockerImportName", f, "InputBoxTemplate")
  nameBox:SetSize(240, 24)
  nameBox:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -92)
  nameBox:SetAutoFocus(false)
  nameBox:SetMaxLetters(ns.MAX_LIST_NAME_BYTES)
  nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.nameBox = nameBox

  local textBox = boxed(f)
  textBox:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -124)
  textBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 50)

  local scroll = CreateFrame("ScrollFrame", "BanterBlockerImportScroll", textBox, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -6, 6)

  local edit = CreateFrame("EditBox", "BanterBlockerImportEdit", scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetMaxLetters(ns.MAX_IMPORT_BYTES)
  edit:SetWidth(440)
  scroll:SetScrollChild(edit)
  f.edit = edit

  -- Measure wrapped text with a hidden FontString (GetStringHeight isn't an
  -- EditBox API) so the scroll range is right for long pasted lists.
  local measure = textBox:CreateFontString(nil, "OVERLAY")
  measure:SetFontObject(ChatFontNormal)
  measure:SetAlpha(0)
  local function resizeEdit()
    local w = math.max(80, scroll:GetWidth() - 4)
    edit:SetWidth(w)
    measure:SetWidth(w)
    measure:SetText((edit:GetText() or "") .. "\n ")
    local _, lh = edit:GetFont()
    local lines = select(2, (edit:GetText() or ""):gsub("\n", ""))
    local h = math.max(measure:GetStringHeight() + 6, (lines + 2) * (lh or 14) + 6)
    edit:SetHeight(math.max(scroll:GetHeight(), h))
    scroll:UpdateScrollChildRect()
  end
  edit:SetScript("OnTextChanged", resizeEdit)
  scroll:SetScript("OnSizeChanged", resizeEdit)

  -- Keep the tall EditBox from swallowing clicks below its visible area.
  local function updateHit()
    local offset = scroll:GetVerticalScroll()
    local viewport = math.max(1, scroll:GetHeight())
    edit:SetHitRectInsets(0, 0, offset, math.max(0, edit:GetHeight() - offset - viewport))
  end
  scroll:HookScript("OnVerticalScroll", updateHit)
  scroll:SetScript("OnShow", function() resizeEdit() updateHit() end)

  f.status = label(f, "", 18, -308, 270)

  f.importButton = button(f, "Import", 300, -304, 90, function()
    local name = Engine.Trim(nameBox:GetText() or "")
    if name == "" then
      f.status:SetText("|cffff8c8cGive the list a name first.|r")
      return
    end
    local text = edit:GetText() or ""
    if Engine.Trim(text) == "" then
      f.status:SetText("|cffff8c8cPaste some words first.|r")
      return
    end
    if not ns.FindList(name) then
      local ok, err = ns.NewList(name)
      if not ok then f.status:SetText("|cffff8c8c" .. err .. "|r") return end
    end
    local ok, added, skipped = ns.AddWords(name, text)
    if not ok then
      f.status:SetText("|cffff8c8c" .. added .. "|r")
      return
    end
    local list = ns.FindList(name)
    if list then ns.db.activeList = list.name end
    f.status:SetText(string.format("|cff88d899Imported %d words into '%s'%s.|r",
      added, name, skipped > 0 and ("; " .. skipped .. " duplicates skipped") or ""))
    edit:SetText("")
    ns.Print("Imported %d words into '%s'.", added, name)
  end)
  button(f, "Close", 400, -304, 80, function() f:Hide() end)

  f:SetScript("OnShow", function()
    if f.exportMode then
      f.status:SetText("Select all text and press Ctrl+C to copy.")
      f.edit:SetFocus()
      f.edit:HighlightText()
    else
      if f.nameBox:GetText() == "" then
        local active = ns.ActiveList()
        if active then f.nameBox:SetText(active.name) end
      end
      f.status:SetText("")
    end
  end)
  f:Hide()
  return f
end

function ns.OpenImport()
  local f = importWin or createImportWindow()
  if f.exportMode then f.edit:SetText("") end
  f.exportMode = false
  f.title:SetText("Import a word list")
  f.description:SetText("Paste words or phrases copied from a text file. New lines, commas or semicolons separate entries.")
  f.nameLabel:SetText("List name (created if it doesn't exist):")
  f.nameBox:Show()
  f.importButton:Show()
  f:Show()
  f:Raise()
end

function ns.OpenExport(name)
  local list = ns.FindList(name)
  if not list then
    ns.Print("List not found.")
    return
  end
  local f = importWin or createImportWindow()
  f.exportMode = true
  f.exportListEmpty = #list.words == 0
  f.title:SetText("Export a word list")
  f.description:SetText("Copy these words to back up or transfer this list.")
  f.nameLabel:SetText("List: " .. list.name)
  f.nameBox:SetText(list.name)
  f.nameBox:Hide()
  f.importButton:Hide()
  f.edit:SetText(table.concat(list.words, "\n"))
  f:Show()
  f:Raise()
  f.status:SetText(f.exportListEmpty and "This list is empty." or "Select all text and press Ctrl+C to copy.")
  if not f.exportListEmpty then
    f.edit:SetFocus()
    f.edit:HighlightText()
  end
end

-- A minimal entry in the native Settings list that opens the real window;
-- the canvas layout assumptions are left deliberately small.
function ns.RegisterSettings()
  if settingsPanel then return end
  settingsPanel = CreateFrame("Frame", "BanterBlockerSettingsPage", UIParent)
  settingsPanel.name = "BanterBlocker"
  settingsPanel:Hide()
  label(settingsPanel, "BanterBlocker", 16, -16, 500, "GameFontNormalLarge")
  label(settingsPanel, "Manage filter lists, chat types and matching options. You can also type /banter or /bb anywhere in game.", 16, -48, 560)
  button(settingsPanel, "Open BanterBlocker settings", 16, -96, 240, function() ns.OpenOptions() end)
  label(settingsPanel, "Filtering hides messages only in your own chat display. Your ignore list and outgoing messages are never changed.", 16, -140, 560)

  if type(Settings) == "table" and Settings.RegisterCanvasLayoutCategory then
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, settingsPanel, settingsPanel.name)
    if ok and category then
      Settings.RegisterAddOnCategory(category)
      ns.settingsCategory = category
    end
  elseif type(InterfaceOptions_AddCategory) == "function" then
    pcall(InterfaceOptions_AddCategory, settingsPanel)
  end
end

function ns.OpenOptions()
  if not ns.ready then ns.InitDB() end
  local win = window or createWindow()
  if not win:IsShown() and win.RefreshAll then win.RefreshAll() end
  win:Show()
  win:Raise()
end

-- ── minimap button ──────────────────────────────────────────────────────────

local miniBtn

function ns.UpdateMinimapButton()
  if not miniBtn then return end
  if ns.db.minimap.hide then
    miniBtn:Hide()
    return
  end
  local angle = math.rad(ns.db.minimap.angle or 225)
  local radius = (Minimap:GetWidth() / 2) + 10
  miniBtn:ClearAllPoints()
  miniBtn:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(angle) * radius, math.sin(angle) * radius)
  miniBtn:Show()
end

local function miniTooltip(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("BanterBlocker v" .. ns.version, 0.35, 0.94, 0.78)
  GameTooltip:AddLine(ns.StatusText(), 0.9, 0.9, 0.9, true)
  GameTooltip:AddLine(string.format("Blocked: %s total, %s this session",
    ns.FormatCount(ns.db.stats.total), ns.FormatCount(ns.sessionBlocked or 0)),
    0.75, 0.75, 0.75)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Left-click: settings", 0.9, 0.9, 0.9)
  GameTooltip:AddLine("Right-click: pause / resume filtering", 0.9, 0.9, 0.9)
  GameTooltip:AddLine("Middle-click: toggle blocked-messages tab", 0.9, 0.9, 0.9)
  GameTooltip:AddLine("Drag: move button", 0.9, 0.9, 0.9)
  GameTooltip:Show()
end

function ns.CreateMinimapButton()
  if miniBtn or not Minimap then return end
  miniBtn = CreateFrame("Button", "BanterBlockerMinimapButton", Minimap)
  local b = miniBtn
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  b:RegisterForDrag("LeftButton")

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ICON_PATH)
  icon:SetSize(21, 21)
  icon:SetPoint("CENTER", b, "CENTER", 0, -2)
  icon:SetTexCoord(0.02, 0.98, 0.02, 0.98)

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(56, 56)
  border:SetPoint("TOPLEFT")

  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  -- Dragging slides the button around the minimap edge; angle is saved.
  b:SetScript("OnDragStart", function(self)
    self.moved = true
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      ns.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
      ns.UpdateMinimapButton()
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  b:SetScript("OnMouseDown", function(self) self.moved = false end)

  b:SetScript("OnClick", function(self, mouseButton)
    if self.moved then self.moved = false return end
    if mouseButton == "RightButton" then
      ns.db.enabled = not ns.db.enabled
      ns.Print(ns.db.enabled and "Filtering enabled." or "Filtering paused.")
      ns.RefreshStatus()
    elseif mouseButton == "MiddleButton" then
      ns.db.logTab = not ns.db.logTab
      ns.Print(ns.db.logTab and "Blocked-message tab enabled." or "Blocked-message tab disabled.")
    else
      ns.OpenOptions()
    end
    miniTooltip(self)
  end)

  b:SetScript("OnEnter", miniTooltip)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  ns.UpdateMinimapButton()
end
