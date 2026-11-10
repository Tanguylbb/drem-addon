-- Carte de la guilde : où sont les membres qui ont l'add-on.
--
-- Pour ne pas encombrer le canal, les positions ne circulent que quand
-- quelqu'un regarde : ouvrir la carte du monde ou l'onglet Carte envoie un
-- « je regarde » ("W"), et chacun partage alors sa position pendant 75 s.
-- Rien n'est envoyé en donjon, en raid ou en champ de bataille, ni si le
-- joueur a coupé le partage.
--
-- Format (préfixe DRemP) : "P:<carte>:<x*10000>:<y*10000>", "H" (caché), "W".

local _, DR = ...
local Map = DR:NewModule("GuildMap")

Map.positions = {}   -- nom complet -> { m, x, y, t }
local STALE = 120
local CHECK_EVERY = 5
local HEARTBEAT = 40
local MOVE = 0.004
local STREAM = 75
local WATCH_PING = 30

Map.streamUntil = 0
Map.watching = {}

function Map:OnLogin()
  DR:Listen("COMM_POSITION", function(sender, text) self:OnPosition(sender, text) end)
  DR:Listen("ROSTER_UPDATED", function()
    for name in pairs(self.positions) do
      if not DR.Guild:IsOnline(name) then self.positions[name] = nil end
    end
  end)
  DR:Listen("SETTINGS_CHANGED", function(what)
    if what == "sharePosition" and not DR.db.settings.sharePosition then
      DR.Comm:SendPosition("H")
      self.last = { hidden = true, t = GetTime() }
    end
  end)
  DR.Every(CHECK_EVERY, function() self:Tick() end)
end

function Map:MyPosition()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local inInstance = IsInInstance()
  if inInstance then return nil end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if not x or (x == 0 and y == 0) then return nil end
  return mapID, x, y
end

function Map:Tick()
  local now = GetTime()
  -- Je regarde : je rappelle aux autres de partager.
  if next(self.watching) and (not self.lastPing or now - self.lastPing >= WATCH_PING) then
    self.lastPing = now
    DR.Comm:SendPosition("W")
  end
  if not DR.db.settings.sharePosition or not IsInGuild() then return end
  if now > self.streamUntil and not self.force then return end
  local m, x, y = self:MyPosition()
  local L = self.last
  if not m then
    if L and not L.hidden then
      DR.Comm:SendPosition("H")
      self.last = { hidden = true, t = now }
    end
    return
  end
  local moved = not L or L.hidden or L.m ~= m or math.abs(L.x - x) > MOVE or math.abs(L.y - y) > MOVE
  if self.force or moved or now - L.t >= HEARTBEAT then
    self.force = false
    DR.Comm:SendPosition(string.format("P:%d:%d:%d", m, math.floor(x * 10000), math.floor(y * 10000)))
    self.last = { m = m, x = x, y = y, t = now }
  end
end

function Map.Parse(text)
  local m, x, y = text:match("^P:(%d+):(%d+):(%d+)$")
  if not m then return nil end
  x, y = tonumber(x) / 10000, tonumber(y) / 10000
  if x > 1 or y > 1 then return nil end
  return tonumber(m), x, y
end

function Map:OnPosition(sender, text)
  if text == "W" then
    self.streamUntil = GetTime() + STREAM
    self.force = true
    return
  end
  if text == "H" then
    self.positions[sender] = nil
    DR:Emit("POSITIONS_CHANGED")
    return
  end
  local m, x, y = Map.Parse(text)
  if not m then return end
  self.positions[sender] = { m = m, x = x, y = y, t = GetTime() }
  DR:Emit("POSITIONS_CHANGED")
end

-- L'interface signale qu'elle montre une carte (clé : "monde", "onglet").
function Map:SetWatching(who, on)
  local was = next(self.watching) ~= nil
  self.watching[who] = on or nil
  if on and not was then
    self.lastPing = GetTime()
    DR.Comm:SendPosition("W")
  end
end

-- Positions fraîches, la mienne comprise.
function Map:Positions()
  local now, out = GetTime(), {}
  for name, p in pairs(self.positions) do
    if now - p.t > STALE then
      self.positions[name] = nil
    else
      out[name] = p
    end
  end
  -- Ma propre position s'affiche toujours chez moi, partage ou non.
  local m, x, y = self:MyPosition()
  if m then out[DR.playerName] = { m = m, x = x, y = y, t = now, me = true } end
  return out
end

-- Ramène une position sur une autre carte (zone -> continent, etc.).
local translateCache = {}
function Map.ToMap(p, mapID)
  if p.m == mapID then return p.x, p.y end
  if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  local key = p.m .. ":" .. p.x .. ":" .. p.y .. ">" .. mapID
  local hit = translateCache[key]
  if hit ~= nil then
    if hit then return hit[1], hit[2] end
    return nil
  end
  local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, p.m, CreateVector2D(p.x, p.y))
  local x, y
  if ok and cont and world then
    local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, world, mapID)
    if ok2 and pos then
      x, y = pos:GetXY()
      if x < 0 or x > 1 or y < 0 or y > 1 then x, y = nil, nil end
    end
  end
  if Map.cacheSize and Map.cacheSize > 2000 then
    translateCache = {}
    Map.cacheSize = 0
  end
  Map.cacheSize = (Map.cacheSize or 0) + 1
  translateCache[key] = x and { x, y } or false
  return x, y
end

function Map.MapName(mapID)
  local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or "?"
end
