-- Fenêtre principale, dans les codes des fenêtres du jeu : cadre bronze, barre de
-- titre fine, médaillon à la tour, bouton fermer rouge, onglets d'icônes sur le
-- bord droit, et une ligne en bas qui dit si la synchro est à jour.

local _, DR = ...
local UI = DR:NewModule("UI")
local T, W, Util = DR.Theme, DR.Widgets, DR.Util
local C = T.C

UI.WIDTH, UI.HEIGHT = 880, 620
UI.tabs = {}       -- clé -> { label, icon, tip, Create(self, parent), Refresh(self) }
UI.TAB_ORDER = { "sorties", "artisans", "carte", "effort", "officiers" }

-- Anciens noms d'onglets, gardés pour /rempart et les raccourcis.
UI.ALIAS = { persos = "artisans", pont = "officiers", banque = "effort" }

function UI:RegisterTab(key, label, def)
  def.key, def.label = key, label
  self.tabs[key] = def
end

local TITLE_H = 28
local FOOT_H = 20

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function UI:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "DernierRempartFrame", UIParent)
  f:SetSize(UI.WIDTH, UI.HEIGHT)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:Hide()
  table.insert(UISpecialFrames, "DernierRempartFrame")
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  T.Gradient(f.bg, C.panel, C.night)
  T.Border(f, C.bronze, 1, 3)
  T.InnerBorder(f, C.bronzeHi, 1, 3)
  self.frame = f

  local pos = DR.db.settings.window
  if pos and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    f:SetPoint("CENTER", 0, 40)
  end
  f:SetScale(DR.db.settings.scale or 1)

  -- Barre de titre ------------------------------------------------------------
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT", 3, -3)
  head:SetPoint("TOPRIGHT", -3, -3)
  head:SetHeight(TITLE_H)
  head.bg = head:CreateTexture(nil, "BACKGROUND")
  head.bg:SetAllPoints()
  T.Gradient(head.bg, { 0.204, 0.125, 0.059 }, { 0.09, 0.047, 0.024 })
  local hl = T.Line(head, { 0.48, 0.35, 0.19 }, 1)
  hl:SetPoint("TOPLEFT"); hl:SetPoint("TOPRIGHT")
  local hrule = T.Line(head, { 0, 0, 0 }, 1)
  hrule:SetPoint("BOTTOMLEFT"); hrule:SetPoint("BOTTOMRIGHT")
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:StartMoving() end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, relPoint, x, y = f:GetPoint()
    DR.db.settings.window = { point = point, relPoint = relPoint, x = x, y = y }
  end)
  self.brand = T.Text(head, "brand", 15, C.goldPale)
  self.brand:SetText("Dernier Rempart")
  self.sep = T.Text(head, "body", 13, { 0.55, 0.45, 0.26 })
  self.sep:SetText("·")
  self.section = T.Text(head, "body", 13, C.ivory)

  -- Médaillon : la tour du blason, au coin, comme le portrait des fenêtres du jeu.
  local medal = CreateFrame("Frame", nil, f)
  medal:SetSize(70, 70)
  medal:SetPoint("TOPLEFT", -18, 18)
  medal:SetFrameLevel(f:GetFrameLevel() + 12)
  medal.tex = medal:CreateTexture(nil, "ARTWORK")
  medal.tex:SetAllPoints()
  medal.tex:SetTexture(T.Icon("medaillon"))
  medal:EnableMouse(true)
  W.Tip(medal, "Dernier Rempart", "Version " .. DR.version .. " · " .. DR.SITE, "/rempart pour la liste des commandes.")
  self.medal = medal

  -- Bouton fermer : carré rouge à croix dorée.
  local close = CreateFrame("Button", nil, f)
  close:SetSize(24, 24)
  close:SetPoint("TOPRIGHT", 4, 4)
  close:SetFrameLevel(f:GetFrameLevel() + 12)
  close.bg = close:CreateTexture(nil, "BACKGROUND")
  close.bg:SetAllPoints()
  T.Gradient(close.bg, { 0.77, 0.14, 0.06 }, { 0.43, 0.043, 0.02 })
  T.Border(close, { 0, 0, 0 }, 1)
  T.InnerBorder(close, { 0.85, 0.68, 0.16 }, 1, 1)
  close.x = close:CreateTexture(nil, "OVERLAY")
  close.x:SetSize(14, 14)
  close.x:SetPoint("CENTER")
  close.x:SetTexture(T.Icon("croix"))
  close.x:SetVertexColor(C.goldText[1], C.goldText[2], C.goldText[3])
  local chl = close:CreateTexture(nil, "HIGHLIGHT")
  chl:SetAllPoints()
  chl:SetColorTexture(1, 1, 1, 0.15)
  close:SetScript("OnClick", function() f:Hide() end)
  self.close = close

  -- Onglets d'icônes sur le bord droit ----------------------------------------
  local items = {}
  for _, key in ipairs(UI.TAB_ORDER) do
    local def = self.tabs[key]
    if def then items[#items + 1] = { key = key, label = def.label, icon = def.icon or "tab_" .. key, tip = def.tip } end
  end
  self.sideTabs = W.SideTabs(f, items, function(key) self:ShowTab(key) end)
  self.sideTabs:SetPoint("TOPLEFT", f, "TOPRIGHT", -8, -86)
  local help = CreateFrame("Button", nil, f)
  help:SetSize(40, 48)
  help:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -3, 60)
  help.label = T.Text(help, "brand", 40, { 0.88, 0.13, 0.13 })
  T.SetFont(help.label, "brand", 40, "OUTLINE")
  help.label:SetPoint("CENTER", 0, 0)
  help.label:SetJustifyH("CENTER")
  help.label:SetText("?")
  help:SetScript("OnClick", function() DR:HandleSlash("aide") end)
  W.Tip(help, "Aide", "Écrit dans la discussion les commandes de l'add-on (/rempart).")

  -- Contenu -------------------------------------------------------------------
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -(3 + TITLE_H + 10))
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 3 + FOOT_H + 8)
  self.content = content
  self.CONTENT_W = UI.WIDTH - 30
  self.CONTENT_H = UI.HEIGHT - (3 + TITLE_H + 10) - (3 + FOOT_H + 8)

  -- Pied de page : l'état de la synchro (un point de couleur) et le dernier message.
  local foot = CreateFrame("Frame", nil, f)
  foot:SetPoint("BOTTOMLEFT", 15, 7)
  foot:SetPoint("BOTTOMRIGHT", -15, 7)
  foot:SetHeight(FOOT_H)
  self.freshDot = W.Dot(foot, 10)
  self.freshDot:SetPoint("LEFT", 2, 0)
  self.freshText = T.Text(foot, "body", 11, C.muted)
  self.freshText:SetPoint("LEFT", self.freshDot, "RIGHT", 7, 0)
  self.freshText:SetWidth(330)
  local hover = CreateFrame("Frame", nil, foot)
  hover:SetPoint("TOPLEFT", 0, 0)
  hover:SetSize(360, FOOT_H)
  hover:EnableMouse(true)
  hover:SetScript("OnEnter", function(h)
    GameTooltip:SetOwner(h, "ANCHOR_TOP")
    GameTooltip:SetText("Synchro avec la guilde", C.goldText[1], C.goldText[2], C.goldText[3])
    for _, line in ipairs(UI:FooterLines()) do GameTooltip:AddLine(line, C.ivory[1], C.ivory[2], C.ivory[3], true) end
    GameTooltip:Show()
  end)
  hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.toastText = T.Text(foot, "semi", 12, C.goldText)
  self.toastText:SetPoint("RIGHT", 0, 0)
  self.toastText:SetJustifyH("RIGHT")
  self.toastText:SetPoint("LEFT", hover, "RIGHT", 20, 0)

  f:SetScript("OnShow", function()
    self:RefreshHeader()
    self:UpdateOfficerTabs()
    if self.current then self:RefreshTab(self.current) end
    DR:Emit("UI_SHOWN")
  end)
  f:SetScript("OnHide", function() DR:Emit("UI_HIDDEN") end)

  self:UpdateOfficerTabs()
  local last = DR.db.settings.lastTab
  last = UI.ALIAS[last or ""] or last
  if not last or not self.tabs[last] then last = "sorties" end
  self.sideTabs:Select(last)
  return f
end

-- Le titre : « Dernier Rempart · Sorties », centré dans la barre.
function UI:SetSection(label)
  if not self.brand then return end
  self.section:SetText(label or "")
  local bw, sw, tw = self.brand:GetStringWidth() or 100, self.sep:GetStringWidth() or 4, self.section:GetStringWidth() or 40
  local total = bw + 8 + sw + 8 + tw
  self.brand:ClearAllPoints()
  self.brand:SetPoint("LEFT", self.brand:GetParent(), "CENTER", -total / 2, 0)
  self.sep:ClearAllPoints()
  self.sep:SetPoint("LEFT", self.brand, "RIGHT", 8, 0)
  self.section:ClearAllPoints()
  self.section:SetPoint("LEFT", self.sep, "RIGHT", 8, 0)
end

function UI:UpdateOfficerTabs()
  if not self.sideTabs then return end
  local officer = DR.Guild:IAmOfficer()
  self.sideTabs:SetHidden("officiers", not officer)
  if not officer and self.current == "officiers" then self:ShowTab("sorties") end
end

function UI:ShowTab(key)
  key = UI.ALIAS[key or ""] or key
  local def = self.tabs[key]
  if not def then return end
  if key == "officiers" and not DR.Guild:IAmOfficer() then key, def = "sorties", self.tabs.sorties end
  for k, d in pairs(self.tabs) do
    if d.frame and k ~= key then d.frame:Hide() end
  end
  if not def.frame then
    def.frame = CreateFrame("Frame", nil, self.content)
    def.frame:SetAllPoints(self.content)
    def:Create(def.frame, self.CONTENT_W, self.CONTENT_H)
  end
  def.frame:Show()
  if def.OnShow then def:OnShow() end
  self.current = key
  DR.db.settings.lastTab = key
  if self.sideTabs then self.sideTabs:Mark(key) end
  self:SetSection(def.label)
  self:RefreshTab(key)
  self:RefreshBadges()
end

function UI:RefreshTab(key)
  local def = self.tabs[key or self.current or ""]
  if def and def.frame and def.frame:IsShown() and def.Refresh then def:Refresh() end
end

---------------------------------------------------------------------------
-- Pied de page : synchro, et pastilles des onglets
---------------------------------------------------------------------------
local LEVEL_TEXT = {
  ok = { C.green, "À jour avec la guilde" },
  wait = { C.amber, "Synchro en cours…" },
  alone = { C.muted, "Personne d'autre n'a l'add-on en ligne" },
  late = { C.amber, "Pas de réponse de la guilde" },
}

function UI:RefreshHeader()
  if not self.frame then return end
  local lv, text
  if not DR.Store:IsReady() then
    lv = { C.muted, IsInGuild() and "Chargement de la guilde…" or "Pas de guilde : rien n'est partagé" }
  else
    local s = DR.Sync:Status()
    lv = LEVEL_TEXT[s.level] or LEVEL_TEXT.wait
    local pending = DR.Comm:Pending()
    if DR.Comm:Locked() and pending > 0 then
      lv = { C.amber, pending .. " message(s) en attente : envoi après le combat" }
    elseif pending > 0 then
      lv = { C.amber, "Envoi à la guilde en cours (" .. pending .. ")" }
    end
  end
  text = lv[2]
  self.freshDot:SetColor(lv[1])
  self.freshText:SetText(text)
  self:RefreshBadges()
end

-- Ce que dit l'infobulle du pied de page : le détail de la synchro et des données du site.
function UI:FooterLines()
  local lines = {}
  if not DR.Store:IsReady() then
    lines[1] = IsInGuild() and "Chargement de la guilde…" or "Pas de guilde : rien n'est partagé."
    return lines
  end
  lines[#lines + 1] = DR.Sync:Status().text
  local level, at = DR.Bridge:Freshness()
  local word = ({ vert = "à jour", orange = "à rafraîchir", rouge = "anciennes" })[level] or ""
  lines[#lines + 1] = at and ("Données du site : " .. Util.Ago(at) .. " (" .. word .. ").") or "Données du site : pas encore reçues."
  local pending = DR.Comm:Pending()
  if pending > 0 then lines[#lines + 1] = pending .. " message(s) en attente d'envoi." end
  if DR.Guild:IAmOfficer() then
    local n, others = DR.Bridge:PendingCount()
    if n > 0 then
      lines[#lines + 1] = n .. " changement(s) à passer au site" .. (others > 0 and (" (dont " .. others .. " d'autres membres)") or "") .. "."
    else
      lines[#lines + 1] = "Rien à passer au site."
    end
  end
  lines[#lines + 1] = "Pour relire ta fiche : /rempart fiche."
  return lines
end

-- Pastille orange d'un onglet : « il y a quelque chose à faire ».
function UI:RefreshBadges()
  if not self.sideTabs then return end
  for key, def in pairs(self.tabs) do
    if def.Badge then
      local n, tip = def:Badge()
      self.sideTabs:SetBadge(key, n, tip)
    end
  end
end

---------------------------------------------------------------------------
-- Messages du pied de page
---------------------------------------------------------------------------
local TOAST = { ok = C.green, warn = C.amber, info = C.goldText, error = C.red }

function UI:Toast(msg, kind)
  if not self.toastText then
    if kind == "warn" or kind == "error" then DR:Print(msg) end
    return
  end
  T.Color(self.toastText, TOAST[kind or "info"] or C.goldText)
  self.toastText:SetText(msg or "")
  self.toastAt = GetTime()
  local stamp = self.toastAt
  DR.After(8, function()
    if self.toastAt == stamp then self.toastText:SetText("") end
  end)
end

---------------------------------------------------------------------------
-- Ouvrir, fermer
---------------------------------------------------------------------------
function UI:Toggle()
  local f = self:Build()
  if f:IsShown() then f:Hide() else f:Show() end
end

-- tab : sorties | artisans | carte | effort | officiers (ou un ancien nom :
-- banque, persos, pont). « banque » ouvre le journal de la banque.
function UI:Open(tab)
  local f = self:Build()
  f:Show()
  local key = tab and (UI.ALIAS[tab] or tab)
  if key and self.tabs[key] then
    self.sideTabs:Select(key)
    if tab == "banque" and self.tabs.effort.SetView then self.tabs.effort:SetView("journal") end
  end
end

function UI:OnLogin()
  W.HookLinks()
  local refresh = DR.Debounce(0.3, function()
    if self.frame and self.frame:IsShown() then
      self:RefreshHeader()
      self:RefreshTab()
    end
  end)
  for _, name in ipairs({ "DATA_CHANGED", "ROSTER_UPDATED", "GUILD_READY", "STORE_BOUND", "PROFILE_UPDATED",
    "BRIDGE_IMPORTED", "EVENTS_CHANGED", "SIGNUP_CHANGED", "EFFORT_CHANGED", "BANK_READ", "BRIDGE_RELAY",
    "SYNC_REPLY" }) do
    DR:Listen(name, refresh)
  end
  DR:Listen("ROSTER_UPDATED", function() self:UpdateOfficerTabs() end)
  DR:Listen("COMM_QUEUE", function()
    if self.frame and self.frame:IsShown() then self:RefreshHeader() end
  end)
  DR.Every(30, function()
    if self.frame and self.frame:IsShown() then self:RefreshHeader() end
  end)
end
