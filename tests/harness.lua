-- Faux client World of Warcraft pour tester l'add-on hors du jeu.
--
-- Chaque « client » charge l'add-on dans son propre environnement (comme un
-- joueur sur son PC). Un « réseau » commun transporte les messages d'add-on
-- du canal de guilde entre les clients et fait avancer le temps.

local H = {}

local ROOT = (arg and arg[0] and arg[0]:match("^(.*)/tests/[^/]*$")) or "."
H.ROOT = ROOT
H.ADDON_DIR = ROOT .. "/DernierRempart"

local function noop() end

---------------------------------------------------------------------------
-- Cadres et régions factices
---------------------------------------------------------------------------
local Methods = {}
local FrameMT = {
  __index = function(_, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and (k:sub(1, 1) == "_" or k:sub(1, 1):match("%l")) then return nil end
    return noop
  end,
}

local function newObject(client, otype, name, parent)
  local o = setmetatable({
    _client = client, _type = otype, _name = name, _parent = parent,
    _events = {}, _scripts = {}, _shown = true, _w = 100, _h = 20, _text = "",
    _enabled = true, _alpha = 1,
  }, FrameMT)
  if client then client.frames[#client.frames + 1] = o end
  if name and client then client.env[name] = o end
  return o
end
H.newObject = newObject

function Methods:RegisterEvent(e) self._events[e] = true end
function Methods:UnregisterEvent(e) self._events[e] = nil end
local NO_SCRIPTS = { FontString = true, Texture = true }
function Methods:SetScript(n, fn)
  assert(not NO_SCRIPTS[self._type], self._type .. " n'accepte pas de script (" .. n .. ")")
  self._scripts[n] = fn
end
function Methods:GetScript(n) return self._scripts[n] end
function Methods:HookScript(n, fn)
  assert(not NO_SCRIPTS[self._type], self._type .. " n'accepte pas de script (" .. n .. ")")
  local old = self._scripts[n]
  self._scripts[n] = function(...)
    if old then old(...) end
    fn(...)
  end
end
function Methods:RunScript(n, ...)
  local fn = self._scripts[n]
  if fn then return fn(self, ...) end
end
function Methods:Show()
  local was = self:IsVisible()
  self._shown = true
  if not was and self:IsVisible() then self:RunScript("OnShow") end
end
function Methods:Hide()
  local was = self:IsVisible()
  self._shown = false
  if was then self:RunScript("OnHide") end
end
function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
function Methods:IsShown() return self._shown end
function Methods:IsVisible()
  if not self._shown then return false end
  if self._parent and self._parent.IsVisible then return self._parent:IsVisible() end
  return true
end
function Methods:GetParent() return self._parent end
function Methods:CreateTexture()
  assert(not NO_SCRIPTS[self._type], "CreateTexture sur un " .. self._type)
  return newObject(self._client, "Texture", nil, self)
end
function Methods:CreateFontString()
  assert(not NO_SCRIPTS[self._type], "CreateFontString sur un " .. self._type)
  return newObject(self._client, "FontString", nil, self)
end
function Methods:SetSize(w, h) self._w, self._h = w, h end
function Methods:SetWidth(w) self._w = w end
function Methods:SetHeight(h) self._h = h end
function Methods:GetWidth() return self._w end
function Methods:GetHeight() return self._h end
function Methods:SetText(t)
  self._text = t == nil and "" or tostring(t)
  if self._type == "EditBox" then self:RunScript("OnTextChanged", false) end
end
function Methods:GetText() return self._text end
function Methods:Insert(t) self:SetText(self._text .. t) end
function Methods:GetStringWidth() return #(self._text or "") * 6 end
function Methods:GetFont() return "font", 12, "" end
function Methods:GetFrameLevel() return 1 end
function Methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Methods:GetCenter() return 0, 0 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetVerticalScroll() return 0 end
function Methods:GetVerticalScrollRange() return 0 end
function Methods:HasFocus() return self._focus or false end
function Methods:SetFocus()
  self._focus = true
  self:RunScript("OnEditFocusGained")
end
function Methods:ClearFocus()
  if self._focus then
    self._focus = false
    self:RunScript("OnEditFocusLost")
  end
end
function Methods:SetEnabled(on)
  self._enabled = on and true or false
  self:RunScript(on and "OnEnable" or "OnDisable")
end
function Methods:Enable() self:SetEnabled(true) end
function Methods:Disable() self:SetEnabled(false) end
function Methods:IsEnabled() return self._enabled end
function Methods:Click(button)
  if self._enabled then self:RunScript("OnClick", button or "LeftButton") end
end
function Methods:SetAlpha(a) self._alpha = a end
function Methods:GetAlpha() return self._alpha end
function Methods:SetFont() return true end

---------------------------------------------------------------------------
-- Réseau : temps, messages du canal de guilde
---------------------------------------------------------------------------
local Net = {}
Net.__index = Net

function H.NewNetwork(server)
  local net = setmetatable({ clients = {}, clock = 1000, server = server or 1794300000, roster = {}, log = {} }, Net)
  return net
end

function Net:ServerTime()
  return self.server + math.floor(self.clock - 1000)
end

function Net:Deliver(from, prefix, text, channel)
  self.log[#self.log + 1] = { from = from.name, prefix = prefix, len = #text }
  for _, c in ipairs(self.clients) do
    if c.online and c.guild == from.guild then
      c.inbox[#c.inbox + 1] = { prefix = prefix, text = text, channel = channel, sender = from.name .. "-Rempart" }
    end
  end
end

-- Fait avancer le temps : minuteurs, OnUpdate, messages reçus.
function Net:Advance(seconds, step)
  step = step or 0.1
  local stop = self.clock + seconds
  while self.clock < stop - 1e-9 do
    self.clock = self.clock + step
    for _, c in ipairs(self.clients) do
      if c.online then c:Tick(step) end
    end
  end
end

function Net:SetRoster(list)
  self.roster = list
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------
local Client = {}
Client.__index = Client

local CLASS_COLORS = {
  PALADIN = { r = 0.96, g = 0.55, b = 0.73 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PRIEST = { r = 1, g = 1, b = 1 },
  DRUID = { r = 1, g = 0.49, b = 0.04 }, ROGUE = { r = 1, g = 0.96, b = 0.41 },
}

local function tocFiles()
  local files = {}
  for line in io.lines(H.ADDON_DIR .. "/DernierRempart.toc") do
    line = line:gsub("\r", "")
    if not line:match("^#") and line:match("%.lua$") then
      files[#files + 1] = (line:gsub("\\", "/"))
    end
  end
  return files
end

function Net:AddClient(opts)
  local c = setmetatable({
    net = self, name = opts.name, class = opts.class or "PALADIN", level = opts.level or 60,
    guild = opts.guild, rankName = opts.rankName or "Membre", rankIndex = opts.rankIndex or 2,
    version = opts.version, online = true, inbox = {}, frames = {}, timers = {}, chat = {},
    sent = {}, profs = opts.profs or {}, map = opts.map, saved = opts.saved,
    lockdown = false, inInstance = false, tradeskill = nil,
  }, Client)
  self.clients[#self.clients + 1] = c
  c:Boot()
  return c
end

function Client:Boot()
  local net, c = self.net, self
  local env = setmetatable({}, { __index = _G })
  env._G = env
  self.env = env
  self.frames, self.timers, self.inbox = {}, {}, {}

  -- Temps
  env.GetTime = function() return net.clock end
  env.GetServerTime = function() return net:ServerTime() end
  env.time = function(t) if t then return os.time(t) end return net:ServerTime() end
  env.date = os.date
  env.C_Timer = {
    After = function(s, fn) c.timers[#c.timers + 1] = { at = net.clock + s, fn = fn } end,
    NewTicker = function(s, fn)
      local t = { at = net.clock + s, fn = fn, interval = s }
      t.Cancel = function() t.cancelled = true end
      c.timers[#c.timers + 1] = t
      return t
    end,
  }

  -- Cadres
  env.CreateFrame = function(otype, name, parent) return newObject(c, otype, name, parent) end
  env.UIParent = newObject(c, "Frame", "UIParent")
  env.Minimap = newObject(c, "Frame", "Minimap")
  env.GameTooltip = newObject(c, "GameTooltip", "GameTooltip")
  env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) c.chat[#c.chat + 1] = msg end }
  env.UISpecialFrames = {}
  env.SlashCmdList = {}
  env.hooksecurefunc = noop
  env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
  env.RAID_CLASS_COLORS = CLASS_COLORS
  env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
  env.GetCursorPosition = function() return 0, 0 end

  -- Joueur et guilde
  env.UnitName = function() return c.name end
  env.UnitClass = function() return "Classe", c.class end
  env.UnitRace = function() return "Humain", "Human" end
  env.UnitLevel = function() return c.level end
  env.GetNormalizedRealmName = function() return "Rempart" end
  env.GetRealmName = function() return "Rempart" end
  env.IsInGuild = function() return c.guild ~= nil end
  env.GetGuildInfo = function() if c.guild then return c.guild, c.rankName, c.rankIndex, nil end end
  env.GetNumGuildMembers = function() return #net.roster end
  env.GetGuildRosterInfo = function(i)
    local m = net.roster[i]
    if not m then return nil end
    local online = false
    for _, cl in ipairs(net.clients) do if cl.name == m.name and cl.online then online = true end end
    if m.online ~= nil then online = m.online end
    return m.name .. "-Rempart", m.rankName or "Membre", m.rankIndex or 2, m.level or 60, "Classe",
      m.zone or "Hurlevent", "", "", online, 0, m.class or "WARRIOR"
  end
  env.C_GuildInfo = { GuildRoster = function() c:Fire("GUILD_ROSTER_UPDATE") end }
  env.GuildControlGetRankName = function(i) return ({ "Seigneur du Rempart", "Officier", "Membre", "Aspirant" })[i] end

  -- Messages d'add-on
  env.Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3 } }
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) assert(#p <= 16, "préfixe trop long") return true end,
    SendAddonMessage = function(prefix, text, channel)
      assert(#text <= 255, "message de plus de 255 octets")
      assert(not text:find("\0", 1, true), "octet nul dans un message")
      c.sent[#c.sent + 1] = { prefix = prefix, text = text }
      net:Deliver(c, prefix, text, channel)
      return 0
    end,
    InChatMessagingLockdown = function() return c.lockdown end,
  }
  env.IsEncounterInProgress = function() return false end
  env.IsInInstance = function() return c.inInstance end
  env.C_AddOns = { GetAddOnMetadata = function(_, key) if key == "Version" then return c.version or "0.2.0" end end }

  -- Spé et métiers
  env.GetSpecialization = function() return 1 end
  env.GetSpecializationInfo = function() return 65, "Sacré", "", 0, "HEALER" end
  env.GetProfessions = function()
    return c.profs[1] and 1 or nil, c.profs[2] and 2 or nil, nil, nil, nil
  end
  env.GetProfessionInfo = function(i)
    local p = c.profs[i]
    if p then return p.name, 0, p.rank, p.max, 0, 0, p.id end
  end
  env.C_TradeSkillUI = {
    GetAllRecipeIDs = function() return c.tradeskill and c.tradeskill.all or {} end,
    GetRecipeInfo = function(id)
      if not c.tradeskill then return nil end
      return { recipeID = id, learned = c.tradeskill.learned[id] and true or false, name = "R" .. id }
    end,
    GetBaseProfessionInfo = function()
      if c.tradeskill then
        return { professionID = c.tradeskill.id, professionName = c.tradeskill.name, skillLevel = 280, maxSkillLevel = 300 }
      end
    end,
    IsTradeSkillReady = function() return c.tradeskill ~= nil end,
    IsTradeSkillLinked = function() return false end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
  }
  env.C_Spell = {
    GetSpellName = function(id) return (H.SPELLS[id]) or ("Sort " .. id) end,
    GetSpellTexture = function() return 134400 end,
  }

  -- Carte
  env.C_Map = {
    GetBestMapForUnit = function() return c.map and c.map.m end,
    GetPlayerMapPosition = function()
      if not c.map then return nil end
      return { GetXY = function() return c.map.x, c.map.y end }
    end,
    GetMapInfo = function(id) return { name = "Zone " .. id, parentMapID = 1414 } end,
    GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end,
    GetMapArtLayerTextures = function() local t = {} for i = 1, 12 do t[i] = i end return t end,
  }

  env.DernierRempartDB = self.saved

  -- Chargement de l'add-on, fichier par fichier, comme le jeu.
  local ns = {}
  for _, file in ipairs(tocFiles()) do
    local chunk = assert(loadfile(H.ADDON_DIR .. "/" .. file))
    setfenv(chunk, env)
    chunk("DernierRempart", ns)
  end
  self.DR = ns
  self:Fire("ADDON_LOADED", "DernierRempart")
  self:Fire("PLAYER_LOGIN")
end

function Client:Fire(event, ...)
  for _, f in ipairs(self.frames) do
    if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end

function Client:Tick(step)
  local now = self.net.clock
  -- Minuteurs échus (ceux ajoutés pendant la boucle attendent le tour suivant).
  local due = {}
  for i = #self.timers, 1, -1 do
    local t = self.timers[i]
    if t.cancelled then
      table.remove(self.timers, i)
    elseif t.at <= now + 1e-9 then
      due[#due + 1] = t
      if t.interval then t.at = t.at + t.interval else table.remove(self.timers, i) end
    end
  end
  for i = #due, 1, -1 do due[i].fn() end
  for _, f in ipairs(self.frames) do
    local up = f._scripts.OnUpdate
    if up and f:IsShown() then up(f, step) end
  end
  local inbox = self.inbox
  self.inbox = {}
  for _, m in ipairs(inbox) do
    self:Fire("CHAT_MSG_ADDON", m.prefix, m.text, m.channel, m.sender)
  end
end

-- Déconnexion : garde la sauvegarde, comme le fichier SavedVariables.
function Client:Logout()
  self.online = false
  self.saved = self.env.DernierRempartDB
end

function Client:Login()
  self.online = true
  self:Boot()
end

function Client:Slash(text)
  self.env.SlashCmdList.DERNIERREMPART(text)
end

H.SPELLS = {
  [3451] = "Potion de soins majeure", [17556] = "Potion de mana majeure",
  [20034] = "Enchanter arme - Croisé", [13868] = "Enchanter bracelets - Soins supérieurs",
  [17635] = "Flacon des Titans", [11450] = "Élixir de défense supérieure",
}

---------------------------------------------------------------------------
-- Mini cadre de tests
---------------------------------------------------------------------------
H.results = { pass = 0, fail = 0, failures = {} }
local currentFile = "?"

function H.file(name) currentFile = name end

function H.test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    H.results.pass = H.results.pass + 1
    io.write("  ok   ", name, "\n")
  else
    H.results.fail = H.results.fail + 1
    H.results.failures[#H.results.failures + 1] = currentFile .. " › " .. name .. "\n" .. tostring(err)
    io.write("  ÉCHEC ", name, "\n")
  end
end

local function show(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end

function H.eq(a, b, msg)
  if a ~= b then error((msg or "valeurs différentes") .. " : attendu " .. show(b) .. ", obtenu " .. show(a), 2) end
end

function H.ok(v, msg)
  if not v then error(msg or "condition fausse", 2) end
end

function H.deepEq(a, b, path)
  path = path or "valeur"
  if type(a) ~= type(b) then error(path .. " : types différents (" .. type(a) .. " / " .. type(b) .. ")", 2) end
  if type(a) ~= "table" then
    if a ~= b then error(path .. " : " .. show(a) .. " ≠ " .. show(b), 2) end
    return
  end
  for k, v in pairs(a) do H.deepEq(v, b[k], path .. "." .. tostring(k)) end
  for k in pairs(b) do if a[k] == nil then error(path .. "." .. tostring(k) .. " manquant à gauche", 2) end end
end

-- Une guilde de trois : Shenryu (officier), Brumelune et Pikvol (membres).
function H.Guild(opts)
  opts = opts or {}
  local net = H.NewNetwork(opts.server)
  net:SetRoster({
    { name = "Shenryu", rankIndex = 1, rankName = "Officier", class = "PALADIN" },
    { name = "Brumelune", rankIndex = 2, class = "MAGE" },
    { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
    { name = "Galdrin", rankIndex = 0, rankName = "Seigneur du Rempart", class = "PALADIN", online = false },
  })
  local clients = {}
  for _, spec in ipairs(opts.clients or {
    { name = "Shenryu", rankIndex = 1, class = "PALADIN" },
    { name = "Brumelune", rankIndex = 2, class = "MAGE" },
  }) do
    spec.guild = spec.guild or "Dernier Rempart"
    clients[#clients + 1] = net:AddClient(spec)
  end
  net:Advance(3)
  return net, clients
end

return H
