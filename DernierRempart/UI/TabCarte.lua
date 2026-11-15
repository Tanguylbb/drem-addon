-- Onglet Carte : la carte de la zone avec les membres de la guilde qui
-- partagent leur position. À droite, une phrase au lieu de trois compteurs, et
-- la liste de ceux qu'on ne voit pas sur la carte, avec la raison.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local GuildMap = DR.GuildMap

local Tab = {}
UI:RegisterTab("carte", "Carte", Tab)
Tab.icon = "tab_carte"
Tab.tip = "Où sont les membres de la guilde qui partagent leur position."

local MAP_W, MAP_H = 548, 360
local SHORT = 6 -- combien de lignes avant « Voir les autres »

function Tab:Create(f, width, height)
  self.f = f
  self.zone = T.Text(f, "title", 18, C.goldText)
  self.zone:SetPoint("TOPLEFT", 2, -5)
  self.up = W.Button(f, "Monter", "sec", 80, 24)
  self.up:SetPoint("TOPLEFT", MAP_W - 80, 0)
  self.up:SetScript("OnClick", function()
    local info = self.mapID and C_Map.GetMapInfo(self.mapID)
    if info and info.parentMapID and info.parentMapID > 0 then self:Show(info.parentMapID) end
  end)
  W.Tip(self.up, "Voir la carte au-dessus (continent)")
  self.here = W.Button(f, "Ma zone", "sec", 80, 24)
  self.here:SetPoint("RIGHT", self.up, "LEFT", -6, 0)
  self.here:SetScript("OnClick", function() self:Show(nil) end)

  local canvas = CreateFrame("Frame", nil, f)
  canvas:SetPoint("TOPLEFT", 0, -34)
  canvas:SetSize(MAP_W, MAP_H)
  T.Fill(canvas, { 0, 0, 0 })
  T.Border(canvas, C.bronze, 1, 2)
  if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
  self.canvas = canvas
  self.tiles, self.pins = {}, {}
  self.noMap = T.Para(canvas, "body", 13, C.brume, MAP_W - 40)
  self.noMap:SetPoint("CENTER")
  self.noMap:SetJustifyH("CENTER")
  -- Quand personne d'autre ne partage sa position : le dire au lieu de rester muette.
  self.alone = W.Badge(canvas)
  self.alone:SetPoint("BOTTOM", 0, 12)
  self.alone:SetFrameLevel(canvas:GetFrameLevel() + 8)
  self.alone:Set("Personne d'autre ne partage sa position dans cette zone", C.brume)

  local note = T.Para(f, "body", 11, C.muted, MAP_W)
  note:SetPoint("TOPLEFT", 2, -34 - MAP_H - 10)
  note:SetText("Les positions n'arrivent que quand quelqu'un regarde une carte, en quelques secondes, et jamais en donjon, en raid ni en champ de bataille.")

  self.pinsCheck = W.Check(f, "Montrer la guilde sur la carte du monde", function(on)
    DR.db.settings.showMapPins = on
    DR:Emit("SETTINGS_CHANGED", "showMapPins")
  end)
  self.pinsCheck:SetPoint("TOPLEFT", 2, -34 - MAP_H - 46)
  local world = W.Button(f, "Ouvrir la carte du monde", "sec", 200, 26)
  world:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT", 0, -42)
  world:SetScript("OnClick", function()
    -- Ouvrir un panneau de Blizzard depuis un add-on est refusé en combat et
    -- à la manette : on le dit au lieu d'essayer.
    local why = DR.Guard.PanelLocked()
    if why then
      DR.UI:Toast("Impossible " .. why .. " : ouvre la carte avec ta touche habituelle.", "warn")
      return
    end
    if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then WorldMapFrame:Show() end
    if self.mapID and WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(self.mapID) end
  end)

  -- Qui est là, et pourquoi on ne le voit pas.
  local rx = MAP_W + 12
  local rw = width - rx
  local right = W.Navy(f, true)
  right:SetPoint("TOPLEFT", rx, 0)
  right:SetSize(rw, height)
  self.right = right
  self.phrase = T.Text(right, "title", 15, { 1, 1, 1 })
  self.phrase:SetPoint("TOPLEFT", 14, -14)
  self.phrase:SetPoint("RIGHT", -14, 0)
  self.addons = T.Text(right, "body", 11, C.brume)
  self.addons:SetPoint("TOPLEFT", self.phrase, "BOTTOMLEFT", 0, -5)

  self.listHeader = W.Header(right, rw - 28)
  self.listHeader:SetPoint("TOPLEFT", 14, -62)
  self.listHeader:SetLabel("Pas sur la carte", 0)
  self.listH = 30 * 12 -- la place pour tout déplier
  local box, list = W.BlackList(right, {
    width = rw - 28, height = self.listH + 2, rowHeight = 30,
    create = function(row)
      row.sep = row:CreateTexture(nil, "BACKGROUND")
      row.sep:SetPoint("TOPLEFT", 0, 0)
      row.sep:SetPoint("TOPRIGHT", 0, 0)
      row.sep:SetHeight(1)
      row.sep:SetColorTexture(C.rule[1], C.rule[2], C.rule[3], 1)
      row.dot = W.Dot(row, 8)
      row.dot:SetPoint("LEFT", 10, 0)
      row.name = T.Text(row, "body", 12)
      row.name:SetPoint("LEFT", 26, 0)
      row.name:SetWidth(112)
      row.why = T.Text(row, "body", 11, C.muted)
      row.why:SetPoint("LEFT", 142, 0)
      row.why:SetPoint("RIGHT", -8, 0)
      row.why:SetJustifyH("RIGHT")
    end,
    update = function(row, m)
      row.dot:SetColor(m.color)
      row.name:SetText(T.Hex(C.goldText) .. Util.ClassName(m.name, m.class) .. "|r")
      row.why:SetText(m.text)
      T.Color(row.why, m.textColor)
    end,
    click = function(m)
      if m.pos then
        self:Show(m.pos.m)
      else
        UI:Toast(Util.ShortName(m.name) .. " : " .. m.text .. ".", "info")
      end
    end,
  })
  box:SetPoint("TOPLEFT", 14, -92)
  self.members, self.membersBox = list, box
  self.moreBtn = W.Button(right, "Voir les autres", "sec", rw - 28, 22)
  self.moreBtn:SetPoint("TOPLEFT", 14, -92 - 30 * SHORT - 8)
  self.moreBtn:SetScript("OnClick", function()
    self.showAll = not self.showAll
    self:Refresh()
  end)

  local foot = CreateFrame("Frame", nil, right)
  foot:SetPoint("BOTTOMLEFT", 1, 1)
  foot:SetPoint("BOTTOMRIGHT", -1, 1)
  foot:SetHeight(44)
  local frule = T.Line(foot, C.navyLine, 1)
  frule:SetPoint("TOPLEFT"); frule:SetPoint("TOPRIGHT")
  local fl = T.Text(foot, "body", 12, C.brume)
  fl:SetPoint("LEFT", 14, 0)
  fl:SetText("Partager ma position")
  self.share = W.Button(foot, "Oui", "toggle", 64, 24)
  self.share:SetPoint("RIGHT", -12, 0)
  self.share:SetScript("OnClick", function()
    DR.db.settings.sharePosition = not DR.db.settings.sharePosition
    DR:Emit("SETTINGS_CHANGED", "sharePosition")
    self:Refresh()
  end)
  W.Tip(self.share, "Partager ma position",
    "Les autres membres qui ont l'add-on voient où tu es, seulement quand ils regardent une carte. Rien n'est envoyé en donjon, en raid ni en champ de bataille.")

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

-- Pourquoi ce membre est-il (ou non) sur la carte ? Rend le texte, sa couleur et
-- la couleur de la pastille.
local function describe(self, m, positions)
  local reason = GuildMap:Reason(m.name)
  local pos = positions[m.name]
  if reason == "pos" and pos then
    local here = self.mapID and GuildMap.ToMap(pos, self.mapID)
    if here then return "sur la carte", C.green, C.green, 1, pos end
    return GuildMap.MapName(pos.m), C.muted, C.muted, 2, pos
  end
  if reason == "instance" then return "en donjon", C.muted, C.muted, 2 end
  if reason == "coupe" then return "position coupée", C.muted, C.muted, 2 end
  if reason == "cache" then return "position cachée", C.muted, C.muted, 2 end
  if reason == "aucune" then return m.zone or "ne partage pas sa position", C.muted, C.muted, 2 end
  return "pas d'add-on", C.amber, C.amber, 3
end

function Tab:Refresh()
  if not self.f or not self.f:IsVisible() then return end
  self.pinsCheck:SetChecked(DR.db.settings.showMapPins)
  local sharing = DR.db.settings.sharePosition
  self.share:SetLabel(sharing and "Oui" or "Non")
  self.share:SetActive(sharing)
  if self.follow ~= false then
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if here ~= self.mapID or not self.drawW then self:Render(here) end
  end
  self:RefreshPins()
  local positions = GuildMap:Positions()
  local online, onMap, withAddon, off = 0, 0, 0, {}
  for _, m in ipairs(DR.Guild:OnlineMembers()) do
    local text, textColor, dotColor, group, pos = describe(self, m, positions)
    online = online + 1
    if DR.Guild:HasAddon(m.name) then withAddon = withAddon + 1 end
    if group == 1 then
      onMap = onMap + 1
    else
      off[#off + 1] = { name = m.name, class = m.class, zone = m.zone, pos = pos, text = text,
        textColor = textColor, color = dotColor, group = group }
    end
  end
  table.sort(off, function(a, b)
    if a.group ~= b.group then return a.group < b.group end
    return a.name < b.name
  end)
  self.phrase:SetText(online .. " en ligne · " .. onMap .. " sur la carte")
  self.addons:SetText(withAddon .. " ont l'add-on")
  self.listHeader:SetLabel("Pas sur la carte", #off)

  -- Les premiers, puis « Voir les autres » : la raison n'est donnée qu'à ceux qu'on ne voit pas.
  local shown = off
  if not self.showAll and #off > SHORT then
    shown = {}
    for i = 1, SHORT do shown[i] = off[i] end
  end
  self.members:SetEmptyText(IsInGuild() and (online == 0 and "Personne d'autre en ligne." or "Tout le monde est sur la carte.") or "Pas de guilde.")
  self.members:SetItems(shown, true)
  -- La boîte noire épouse les lignes montrées ; le bouton se met juste dessous.
  local rows = math.max(1, math.min(#shown, 12))
  self.membersBox:SetHeight(rows * 30 + 2)
  self.moreBtn:ClearAllPoints()
  self.moreBtn:SetPoint("TOPLEFT", 14, -92 - rows * 30 - 10)
  self.moreBtn:SetShown(#off > SHORT)
  if #off > SHORT then
    self.moreBtn:SetLabel(self.showAll and "Voir moins" or ("Voir les " .. (#off - SHORT) .. " autres"))
  end
  -- Carte vide : on le dit.
  local others = 0
  if self.mapID and self.noMap and not self.noMap:IsShown() then
    for _, p in pairs(positions) do
      if not p.me and GuildMap.ToMap(p, self.mapID) then others = others + 1 end
    end
  end
  self.alone:SetShown(self.noMap and not self.noMap:IsShown() and others == 0)
end

function Tab:OnShow()
  if self.follow == nil then self.follow = true end
end
