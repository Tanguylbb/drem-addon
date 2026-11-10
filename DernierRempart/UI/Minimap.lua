-- Bouton de la minicarte : clic pour ouvrir, glisser pour déplacer, et une
-- infobulle qui résume la prochaine sortie et la fraîcheur des données.

local _, DR = ...
local MB = DR:NewModule("MinimapButton")
local T, Util = DR.Theme, DR.Util
local C = T.C

local function place(b)
  local angle = math.rad(DR.db.settings.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 6
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function MB:ShowTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText("Dernier Rempart", C.goldText[1], C.goldText[2], C.goldText[3])
  if DR.Store:IsReady() then
    local ev = DR.Calendar:Next()
    if ev then
      GameTooltip:AddLine("Prochaine sortie : " .. ev.t, C.ivory[1], C.ivory[2], C.ivory[3])
      GameTooltip:AddLine(Util.ShortDate(ev.d) .. " · " .. Util.Until(ev.d), 0.8, 0.82, 0.9)
    else
      GameTooltip:AddLine("Aucune sortie prévue", C.muted[1], C.muted[2], C.muted[3])
    end
    local level, at = DR.Bridge:Freshness()
    local c = level == "vert" and C.green or (level == "orange" and C.amber or C.red)
    GameTooltip:AddLine("Données du site : " .. (at and Util.Ago(at) or "pas encore reçues"), c[1], c[2], c[3])
    local waiting = #DR.Calendar:AwaitingAnswer()
    if waiting > 0 then
      GameTooltip:AddLine(waiting .. " sortie(s) attendent ta réponse", C.amber[1], C.amber[2], C.amber[3])
    end
    local orders = 0
    for _, o in ipairs(DR.Crafts:Orders("craft", "forme")) do if o.s == "demandee" then orders = orders + 1 end end
    if orders > 0 then
      GameTooltip:AddLine(orders .. " commande(s) d'artisan pour toi", C.amber[1], C.amber[2], C.amber[3])
    end
    local pending = DR.Comm:Pending()
    if pending > 0 then
      GameTooltip:AddLine(pending .. " message(s) en attente d'envoi", C.amber[1], C.amber[2], C.amber[3])
    end
  else
    GameTooltip:AddLine(IsInGuild() and "Chargement de la guilde…" or "Pas de guilde", C.muted[1], C.muted[2], C.muted[3])
  end
  GameTooltip:AddLine("Clic : ouvrir · Clic droit : artisans · Glisser : déplacer", C.muted[1], C.muted[2], C.muted[3])
  GameTooltip:Show()
end

function MB:OnLogin()
  if not Minimap then return end
  local b = CreateFrame("Button", "DernierRempartMinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(28, 28)
  icon:SetPoint("CENTER")
  icon:SetTexture(T.Icon("minimap"))
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetSize(34, 34)
  ring:SetPoint("CENTER")
  ring:SetTexture(T.Icon("ring"))
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetSize(28, 28)
  hl:SetPoint("CENTER")
  hl:SetTexture(T.Icon("dot"))
  hl:SetVertexColor(1, 1, 1, 0.18)

  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then DR.UI:Open("artisans") else DR.UI:Toggle() end
  end)
  b:SetScript("OnEnter", function(btn) MB:ShowTooltip(btn) end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnDragStart", function(btn)
    btn:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      px, py = px / scale, py / scale
      DR.db.settings.minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
      place(btn)
    end)
  end)
  b:SetScript("OnDragStop", function(btn) btn:SetScript("OnUpdate", nil) end)
  self.button = b
  place(b)
  b:SetShown(not DR.db.settings.minimap.hide)
  DR:Listen("SETTINGS_CHANGED", function(what)
    if what == "minimap" then b:SetShown(not DR.db.settings.minimap.hide) end
  end)
end
