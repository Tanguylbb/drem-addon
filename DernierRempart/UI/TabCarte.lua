-- Onglet « Qui est là » (clé interne : carte). Il n'y a plus de carte dans la
-- fenêtre : les membres qui partagent leur position sont déjà sur la carte du
-- monde du jeu (UI/MapPins.lua). Ici : la liste de ceux qui sont en ligne, où
-- ils sont, pourquoi on ne voit pas les autres, et les réglages de partage.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local GuildMap = DR.GuildMap

local Tab = {}
UI:RegisterTab("carte", "Qui est là", Tab)
Tab.icon = "tab_presents"
Tab.tip = "Qui est en ligne, où, et qui apparaît sur la carte du jeu."

local RIGHT_W = 300
local ROW_H = 28

function Tab:Create(f, width, height)
  self.f = f
  local lw = width - RIGHT_W - 12
  self.lw = lw

  -- À gauche : les membres en ligne.
  self.listHeader = W.Header(f, lw)
  self.listHeader:SetPoint("TOPLEFT", 0, 0)
  self.listHeader.box:Hide()
  self.listHeader:SetLabel("En ligne maintenant", 0)
  local box, list = W.BlackList(f, {
    width = lw, height = height - 30, rowHeight = ROW_H,
    create = function(row)
      row.sep = row:CreateTexture(nil, "BACKGROUND")
      row.sep:SetPoint("TOPLEFT", 0, 0)
      row.sep:SetPoint("TOPRIGHT", 0, 0)
      row.sep:SetHeight(1)
      row.sep:SetColorTexture(C.rule[1], C.rule[2], C.rule[3], 1)
      row.dot = W.Dot(row, 8)
      row.dot:SetPoint("LEFT", 10, 0)
      -- Trois colonnes de largeur fixe : un nom long se coupe par « … », il ne
      -- passe jamais sur la zone.
      row.name = T.Text(row, "body", 13)
      row.name:SetPoint("LEFT", 26, 0)
      row.name:SetWidth(200)
      row.place = T.Text(row, "body", 12, C.brume)
      row.place:SetPoint("LEFT", 236, 0)
      row.place:SetPoint("RIGHT", -136, 0)
      row.note = T.Text(row, "body", 11, C.muted)
      row.note:SetPoint("RIGHT", -12, 0)
      row.note:SetWidth(118)
      row.note:SetJustifyH("RIGHT")
    end,
    update = function(row, m)
      row.dot:SetColor(m.color)
      row.name:SetText(T.Hex(C.goldText) .. Util.ClassName(m.name, m.class) .. "|r")
      row.place:SetText(m.place or "")
      row.note:SetText(m.text)
      T.Color(row.note, m.textColor)
    end,
    click = function(m)
      if m.pos then
        self:OpenWorldMap(m.pos.m)
      else
        UI:Toast(Util.ShortName(m.name) .. " : " .. m.text .. ".", "info")
      end
    end,
  })
  box:SetPoint("TOPLEFT", 0, -30)
  self.members, self.membersBox = list, box

  -- À droite : la fiche marine.
  local right = W.Navy(f, true)
  right:SetPoint("TOPLEFT", lw + 12, 0)
  right:SetSize(RIGHT_W, height)
  self.right = right
  local pad = 16
  self.phrase = T.Text(right, "title", 15, { 1, 1, 1 })
  self.phrase:SetPoint("TOPLEFT", pad, -pad)
  self.phrase:SetPoint("RIGHT", -pad, 0)
  self.addons = T.Text(right, "body", 11, C.brume)
  self.addons:SetPoint("TOPLEFT", self.phrase, "BOTTOMLEFT", 0, -5)
  self.addons:SetPoint("RIGHT", -pad, 0)

  self.help = T.Para(right, "body", 12, C.brume, RIGHT_W - 2 * pad)
  self.help:SetPoint("TOPLEFT", pad, -76)
  self.help:SetText("Les membres qui partagent leur position apparaissent directement sur la carte du monde du jeu (touche M), à la couleur de leur classe. Clique sur un nom pour ouvrir la carte à sa zone.")

  self.alone = T.Para(right, "body", 12, C.amber, RIGHT_W - 2 * pad)
  self.alone:SetPoint("TOPLEFT", pad, -170)
  self.alone:SetText("Personne d'autre ne partage sa position pour l'instant : les points n'apparaissent que si un autre membre a l'add-on et partage la sienne.")

  self.pinsCheck = W.Check(right, "Montrer la guilde sur la carte du monde", function(on)
    DR.db.settings.showMapPins = on
    DR:Emit("SETTINGS_CHANGED", "showMapPins")
  end)
  self.pinsCheck:SetPoint("TOPLEFT", pad - 2, -248)

  local shareLabel = T.Text(right, "body", 12, C.brume)
  shareLabel:SetPoint("TOPLEFT", pad, -284)
  shareLabel:SetText("Partager ma position")
  self.share = W.Button(right, "Oui", "toggle", 64, 24)
  self.share:SetPoint("TOPRIGHT", -pad, -279)
  self.share:SetScript("OnClick", function()
    DR.db.settings.sharePosition = not DR.db.settings.sharePosition
    DR:Emit("SETTINGS_CHANGED", "sharePosition")
    self:Refresh()
  end)
  W.Tip(self.share, "Partager ma position",
    "Les autres membres qui ont l'add-on voient où tu es, seulement quand ils regardent une carte. Rien n'est envoyé en donjon, en raid ni en champ de bataille.")

  self.limits = T.Para(right, "body", 11, C.muted, RIGHT_W - 2 * pad)
  self.limits:SetPoint("TOPLEFT", pad, -316)
  self.limits:SetText("Les positions n'arrivent que quand quelqu'un regarde une carte, en quelques secondes, et jamais en donjon, en raid ni en champ de bataille.")

  local world = W.Button(right, "Ouvrir la carte du monde", "red", RIGHT_W - 2 * pad, 30)
  world:SetPoint("BOTTOM", 0, 14)
  world:SetScript("OnClick", function() self:OpenWorldMap(nil) end)

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
  DR:Listen("POSITIONS_CHANGED", function() if f:IsVisible() then self:Refresh() end end)
end

-- Ouvre la carte du monde du jeu (à la zone demandée). Ouvrir un panneau de
-- Blizzard depuis un add-on est refusé en combat et à la manette : on le dit
-- au lieu d'essayer.
function Tab:OpenWorldMap(mapID)
  local why = DR.Guard.PanelLocked()
  if why then
    UI:Toast("Impossible " .. why .. " : ouvre la carte avec ta touche habituelle.", "warn")
    return
  end
  if not (WorldMapFrame and WorldMapFrame:IsShown()) then
    if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then WorldMapFrame:Show() end
  end
  mapID = mapID or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
  if mapID and WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
end

-- Pourquoi ce membre est-il (ou non) sur la carte ? Rend le texte, sa couleur,
-- la couleur de la pastille, le groupe (1 = sur la carte, 2 = pas de position,
-- 3 = pas d'add-on) et sa position.
local function describe(m, positions)
  local reason = GuildMap:Reason(m.name)
  local pos = positions[m.name]
  if reason == "pos" and pos then return "sur la carte", C.green, C.green, 1, pos end
  if reason == "instance" then return "en donjon", C.muted, C.muted, 2 end
  if reason == "coupe" then return "position coupée", C.muted, C.muted, 2 end
  if reason == "cache" then return "position cachée", C.muted, C.muted, 2 end
  if reason == "aucune" then return "ne partage pas", C.muted, C.muted, 2 end
  return "pas d'add-on", C.amber, C.amber, 3
end

function Tab:Refresh()
  if not self.f or not self.f:IsVisible() then return end
  self.pinsCheck:SetChecked(DR.db.settings.showMapPins)
  local sharing = DR.db.settings.sharePosition
  self.share:SetLabel(sharing and "Oui" or "Non")
  self.share:SetActive(sharing)
  local positions = GuildMap:Positions()
  local online, onMap, withAddon, others, items = 0, 0, 0, 0, {}
  for _, m in ipairs(DR.Guild:OnlineMembers()) do
    local text, textColor, dotColor, group, pos = describe(m, positions)
    online = online + 1
    if DR.Guild:HasAddon(m.name) then withAddon = withAddon + 1 end
    if group == 1 then
      onMap = onMap + 1
      if not pos.me then others = others + 1 end
    end
    items[#items + 1] = {
      name = m.name, class = m.class, pos = pos, text = text, textColor = textColor,
      color = dotColor, group = group,
      place = pos and GuildMap.MapName(pos.m) or m.zone,
    }
  end
  table.sort(items, function(a, b)
    if a.group ~= b.group then return a.group < b.group end
    return a.name < b.name
  end)
  self.phrase:SetText(online .. " en ligne · " .. onMap .. " sur la carte")
  self.addons:SetText(withAddon .. " ont l'add-on")
  self.listHeader:SetLabel("En ligne maintenant", online)
  self.listHeader:SetExtra(onMap > 0 and (onMap .. " sur la carte du jeu") or "", C.green)
  self.members:SetEmptyText(IsInGuild() and "Personne d'autre en ligne." or "Pas de guilde.")
  self.members:SetItems(items, true)
  -- Carte vide : on dit pourquoi, au lieu de laisser croire à une panne.
  self.alone:SetShown(IsInGuild() and others == 0)
end

function Tab:OnShow() end
