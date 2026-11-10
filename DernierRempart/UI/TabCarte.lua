-- Onglet Carte : la carte de la zone avec les membres de la guilde qui
-- partagent leur position, et la liste de qui est en ligne et où.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local GuildMap = DR.GuildMap

local Tab = {}
UI:RegisterTab("carte", "Carte", Tab)

local MAP_W, MAP_H = 560, 374

function Tab:Create(f, width, height)
  self.f = f
  self.zone = T.Text(f, "title", 20, C.goldText)
  self.zone:SetPoint("TOPLEFT", 0, -4)
  self.up = W.Button(f, "Monter", "ghost", 80, 26)
  self.up:SetPoint("TOPLEFT", MAP_W - 80, 0)
  self.up:SetScript("OnClick", function()
    local info = self.mapID and C_Map.GetMapInfo(self.mapID)
    if info and info.parentMapID and info.parentMapID > 0 then self:Show(info.parentMapID) end
  end)
  W.Tip(self.up, "Voir la carte au-dessus (continent)")
  self.here = W.Button(f, "Ma zone", "ghost", 80, 26)
  self.here:SetPoint("RIGHT", self.up, "LEFT", -6, 0)
  self.here:SetScript("OnClick", function() self:Show(nil) end)

  local canvas = CreateFrame("Frame", nil, f)
  canvas:SetPoint("TOPLEFT", 0, -34)
  canvas:SetSize(MAP_W, MAP_H)
  T.Fill(canvas, C.sunk)
  T.Border(canvas, C.line)
  if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
  self.canvas = canvas
  self.tiles, self.pins = {}, {}
  self.noMap = T.Para(canvas, "body", 13, C.brume, MAP_W - 40)
  self.noMap:SetPoint("CENTER")
  self.noMap:SetJustifyH("CENTER")

  -- Réglages sous la carte.
  self.share = W.Check(f, "Partager ma position avec la guilde", function(on)
    DR.db.settings.sharePosition = on
    DR:Emit("SETTINGS_CHANGED", "sharePosition")
  end)
  self.share:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -10)
  self.pinsCheck = W.Check(f, "Montrer la guilde sur la carte du monde", function(on)
    DR.db.settings.showMapPins = on
    DR:Emit("SETTINGS_CHANGED", "showMapPins")
  end)
  self.pinsCheck:SetPoint("TOPLEFT", self.share, "BOTTOMLEFT", 0, -6)
  local world = W.Button(f, "Ouvrir la carte du monde", "slate", 220, 30)
  world:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT", 0, -10)
  world:SetScript("OnClick", function()
    if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then WorldMapFrame:Show() end
    if self.mapID and WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(self.mapID) end
  end)
  local note = T.Para(f, "body", 11, C.muted, MAP_W)
  note:SetPoint("TOPLEFT", self.pinsCheck, "BOTTOMLEFT", 0, -8)
  note:SetText("Les positions ne circulent que quand quelqu'un regarde la carte, et jamais en donjon, en raid ni en champ de bataille.")

  -- Qui est en ligne.
  local lw = width - MAP_W - 16
  self.count = T.Text(f, "title", 18, C.ivory)
  self.count:SetPoint("TOPLEFT", MAP_W + 16, -4)
  self.members = W.List(f, {
    width = lw, height = height - 34, rowHeight = 34,
    create = function(row)
      row.dot = W.Dot(row, 8)
      row.dot:SetPoint("LEFT", 6, 0)
      row.name = T.Text(row, "semi", 12)
      row.name:SetPoint("TOPLEFT", 22, -3)
      row.name:SetPoint("RIGHT", -4, 0)
      row.zone = T.Text(row, "body", 11, C.muted)
      row.zone:SetPoint("BOTTOMLEFT", 22, 3)
      row.zone:SetPoint("RIGHT", -4, 0)
    end,
    update = function(row, m)
      local c = m.pos and C.teal or C.line2
      row.dot:SetColorTexture(c[1], c[2], c[3], 1)
      row.name:SetText(Util.ClassName(m.name, m.class) .. T.Hex(C.muted) .. "  " .. (m.level or "") .. "|r")
      local zone = m.zone or "?"
      if m.pos then zone = GuildMap.MapName(m.pos.m) .. T.Hex(C.teal) .. " · sur la carte|r" end
      row.zone:SetText(zone)
    end,
    click = function(m)
      if m.pos then
        self:Show(m.pos.m)
      else
        UI:Toast(Util.ShortName(m.name) .. " ne partage pas sa position (zone : " .. (m.zone or "?") .. ").", "info")
      end
    end,
  })
  self.members:SetPoint("TOPLEFT", MAP_W + 16, -34)

  f:SetScript("OnShow", function()
    GuildMap:SetWatching("onglet", true)
    self.ticker = DR.Every(2, function() self:Refresh() end)
  end)
  f:SetScript("OnHide", function()
    GuildMap:SetWatching("onglet", false)
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
  end)
  GuildMap:SetWatching("onglet", true)
  self.ticker = DR.Every(2, function() self:Refresh() end)
  DR:Listen("POSITIONS_CHANGED", function() if f:IsVisible() then self:RefreshPins() end end)
end

---------------------------------------------------------------------------
-- Dessin de la carte (tuiles de la zone, comme la carte du monde)
---------------------------------------------------------------------------
function Tab:Show(mapID)
  self.follow = (mapID == nil)
  if not mapID and C_Map and C_Map.GetBestMapForUnit then mapID = C_Map.GetBestMapForUnit("player") end
  self:Render(mapID)
  self:RefreshPins()
end

function Tab:Render(mapID)
  self.mapID = mapID
  for _, t in ipairs(self.tiles) do t:Hide() end
  local layers = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
  local layer = layers and layers[1]
  local textures = layer and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1)
  self.zone:SetText(mapID and GuildMap.MapName(mapID) or "Carte")
  local info = mapID and C_Map.GetMapInfo(mapID)
  self.up:SetEnabled(info and info.parentMapID and info.parentMapID > 0 or false)
  if not layer or not textures or #textures == 0 then
    self.noMap:SetText("Pas de carte à montrer ici (donjon, ou carte inconnue). La liste à droite dit où sont les membres.")
    self.noMap:Show()
    self.drawW, self.drawH = MAP_W, MAP_H
    return
  end
  self.noMap:Hide()
  local scale = MAP_W / layer.layerWidth
  if layer.layerHeight * scale > MAP_H then scale = MAP_H / layer.layerHeight end
  self.drawW, self.drawH = layer.layerWidth * scale, layer.layerHeight * scale
  self.offX, self.offY = (MAP_W - self.drawW) / 2, (MAP_H - self.drawH) / 2
  local cols = math.ceil(layer.layerWidth / layer.tileWidth)
  local tw, th = layer.tileWidth * scale, layer.tileHeight * scale
  for i, fileID in ipairs(textures) do
    local tile = self.tiles[i]
    if not tile then
      tile = self.canvas:CreateTexture(nil, "ARTWORK")
      self.tiles[i] = tile
    end
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    tile:SetTexture(fileID)
    tile:SetSize(tw, th)
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", self.offX + col * tw, -(self.offY + row * th))
    tile:Show()
  end
end

local function acquirePin(self, i)
  local pin = self.pins[i]
  if pin then return pin end
  pin = CreateFrame("Frame", nil, self.canvas)
  pin:SetSize(16, 16)
  pin:SetFrameLevel(self.canvas:GetFrameLevel() + 5)
  pin.dot = pin:CreateTexture(nil, "ARTWORK")
  pin.dot:SetAllPoints()
  pin.dot:SetTexture(T.Icon("dot"))
  pin.ring = pin:CreateTexture(nil, "OVERLAY")
  pin.ring:SetAllPoints()
  pin.ring:SetTexture(T.Icon("ring"))
  pin:EnableMouse(true)
  pin:SetScript("OnEnter", function(p)
    GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
    GameTooltip:SetText(Util.ClassName(p.name, p.class))
    local m = DR.Guild:Get(p.name)
    if m then GameTooltip:AddLine("Niveau " .. (m.level or "?") .. " · " .. (m.zone or ""), 0.73, 0.76, 0.82) end
    GameTooltip:Show()
  end)
  pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.pins[i] = pin
  return pin
end

function Tab:RefreshPins()
  if not self.canvas then return end
  local i = 0
  if self.mapID and self.noMap and not self.noMap:IsShown() then
    for name, p in pairs(GuildMap:Positions()) do
      local x, y = GuildMap.ToMap(p, self.mapID)
      if x then
        i = i + 1
        local pin = acquirePin(self, i)
        pin.name = name
        pin.class = DR.Profile:ClassOf(name)
        local r, g, b = Util.ClassColor(pin.class)
        pin.dot:SetVertexColor(r, g, b)
        local size = p.me and 18 or 14
        pin:SetSize(size, size)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", self.canvas, "TOPLEFT", self.offX + x * self.drawW, -(self.offY + y * self.drawH))
        pin:Show()
      end
    end
  end
  for k = i + 1, #self.pins do self.pins[k]:Hide() end
end

function Tab:Refresh()
  if not self.f or not self.f:IsVisible() then return end
  self.share:SetChecked(DR.db.settings.sharePosition)
  self.pinsCheck:SetChecked(DR.db.settings.showMapPins)
  if self.follow ~= false then
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if here ~= self.mapID or not self.drawW then self:Render(here) end
  end
  self:RefreshPins()
  local positions = GuildMap:Positions()
  local list = {}
  for _, m in ipairs(DR.Guild:OnlineMembers()) do
    list[#list + 1] = { name = m.name, class = m.class, level = m.level, zone = m.zone, pos = positions[m.name] }
  end
  table.sort(list, function(a, b)
    if (a.pos ~= nil) ~= (b.pos ~= nil) then return a.pos ~= nil end
    return a.name < b.name
  end)
  local shared = 0
  for _, m in ipairs(list) do if m.pos then shared = shared + 1 end end
  self.count:SetText("En ligne  " .. T.Hex(C.muted) .. #list .. "|r" .. (shared > 0 and (T.Hex(C.teal) .. "  · " .. shared .. " sur la carte|r") or ""))
  self.members:SetEmptyText(IsInGuild() and "Personne d'autre en ligne." or "Pas de guilde.")
  self.members:SetItems(list, true)
end

function Tab:OnShow()
  if self.follow == nil then self.follow = true end
end
