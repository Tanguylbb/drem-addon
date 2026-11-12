-- Fenêtre principale : en-tête au blason, point de fraîcheur des données,
-- onglets soulignés, pied de page avec le dernier message.

local _, DR = ...
local UI = DR:NewModule("UI")
local T, W, Util = DR.Theme, DR.Widgets, DR.Util
local C = T.C

UI.WIDTH, UI.HEIGHT = 900, 640
UI.tabs = {}       -- clé -> { label, Create(self, parent), Refresh(self) }
UI.TAB_ORDER = { "sorties", "artisans", "carte", "effort", "persos", "pont" }

function UI:RegisterTab(key, label, def)
  def.key, def.label = key, label
  self.tabs[key] = def
end

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
  T.Fill(f, C.night)
  T.Border(f, C.gold, 0.85)
  self.frame = f

  local pos = DR.db.settings.window
  if pos and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    f:SetPoint("CENTER", 0, 40)
  end
  f:SetScale(DR.db.settings.scale or 1)

  -- En-tête -----------------------------------------------------------------
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", -1, -1)
  head:SetHeight(66)
  T.Fill(head, C.header)
  local rule = T.Line(head, C.gold, 0.6)
  rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:StartMoving() end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, relPoint, x, y = f:GetPoint()
    DR.db.settings.window = { point = point, relPoint = relPoint, x = x, y = y }
  end)

  local logo = head:CreateTexture(nil, "ARTWORK")
  logo:SetSize(46, 46)
  logo:SetPoint("LEFT", 14, 0)
  logo:SetTexture(T.Icon("logo"))

  local title = T.Text(head, "title", 24, C.goldText)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -4)
  title:SetText("Dernier Rempart")
  local motto = T.Text(head, "body", 11, C.brume)
  motto:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)
  motto:SetText("Avancer ensemble, durer ensemble.")

  local close = W.IconButton(head, "close", 28, C.brume, "Fermer")
  close:SetPoint("RIGHT", -12, 0)
  close:SetScript("OnClick", function() f:Hide() end)

  self.freshDot = W.Dot(head, 8)
  self.freshText = T.Text(head, "body", 12, C.ivory)
  self.freshText:SetPoint("TOPRIGHT", close, "TOPLEFT", -14, -2)
  self.freshText:SetJustifyH("RIGHT")
  self.freshDot:SetPoint("RIGHT", self.freshText, "LEFT", -7, 0)
  self.syncText = T.Text(head, "body", 11, C.muted)
  self.syncText:SetPoint("TOPRIGHT", self.freshText, "BOTTOMRIGHT", 0, -6)
  self.syncText:SetJustifyH("RIGHT")
  local freshHover = CreateFrame("Frame", nil, head)
  freshHover:SetPoint("TOPRIGHT", self.freshText, "TOPRIGHT", 4, 4)
  freshHover:SetSize(300, 40)
  freshHover:EnableMouse(true)
  W.Tip(freshHover, "Fraîcheur des données",
    "Vert : le site a été relié au jeu il y a moins d'un jour. Orange : moins de 3 jours. Rouge : plus.",
    "Les officiers font le lien dans l'onglet Pont.")

  -- Onglets ------------------------------------------------------------------
  local items = {}
  for _, key in ipairs(UI.TAB_ORDER) do
    local def = self.tabs[key]
    if def then items[#items + 1] = { key = key, label = def.label } end
  end
  self.tabBar = W.Tabs(f, items, function(key) self:ShowTab(key) end)
  self.tabBar:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 20, -6)
  self.tabBar:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -20, -6)

  -- Contenu -------------------------------------------------------------------
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", self.tabBar, "BOTTOMLEFT", -6, -12)
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 34)
  self.content = content
  self.CONTENT_W = UI.WIDTH - 28
  self.CONTENT_H = UI.HEIGHT - 66 - 6 - 34 - 12 - 34

  -- Pied de page --------------------------------------------------------------
  local foot = CreateFrame("Frame", nil, f)
  foot:SetPoint("BOTTOMLEFT", 14, 1)
  foot:SetPoint("BOTTOMRIGHT", -14, 1)
  foot:SetHeight(30)
  local frule = T.Line(foot, C.gold, 0.3)
  frule:SetPoint("TOPLEFT"); frule:SetPoint("TOPRIGHT")
  local ver = T.Text(foot, "body", 11, C.muted)
  ver:SetPoint("LEFT", 0, 0)
  ver:SetText("v" .. DR.version .. " · /rempart · " .. DR.SITE)
  self.toastText = T.Text(foot, "semi", 12, C.goldText)
  self.toastText:SetPoint("RIGHT", 0, 0)
  self.toastText:SetJustifyH("RIGHT")
  self.toastText:SetPoint("LEFT", ver, "RIGHT", 20, 0)

  f:SetScript("OnShow", function()
    self:RefreshHeader()
    self:UpdateOfficerTabs()
    if self.current then self:RefreshTab(self.current) end
    DR:Emit("UI_SHOWN")
  end)
  f:SetScript("OnHide", function() DR:Emit("UI_HIDDEN") end)

  self:UpdateOfficerTabs()
  self.tabBar:Select(DR.db.settings.lastTab or "sorties")
  return f
end

function UI:UpdateOfficerTabs()
  if not self.tabBar then return end
  local officer = DR.Guild:IAmOfficer()
  self.tabBar:SetHidden("pont", not officer)
  if not officer and self.current == "pont" then self.tabBar:Select("sorties") end
end

function UI:ShowTab(key)
  local def = self.tabs[key]
  if not def then return end
  if key == "pont" and not DR.Guild:IAmOfficer() then key, def = "sorties", self.tabs.sorties end
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
  self:RefreshTab(key)
end

function UI:RefreshTab(key)
  local def = self.tabs[key or self.current or ""]
  if def and def.frame and def.frame:IsShown() and def.Refresh then def:Refresh() end
end

---------------------------------------------------------------------------
-- En-tête : fraîcheur et file d'attente
---------------------------------------------------------------------------
local FRESH = { vert = C.green, orange = C.amber, rouge = C.red }

function UI:RefreshHeader()
  if not self.frame then return end
  if not DR.Store:IsReady() then
    self.freshDot:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)
    self.freshText:SetText(IsInGuild() and "Chargement de la guilde…" or "Pas de guilde : rien n'est partagé")
    self.syncText:SetText("")
    return
  end
  local level, at = DR.Bridge:Freshness()
  local c = FRESH[level]
  self.freshDot:SetColorTexture(c[1], c[2], c[3], 1)
  self.freshText:SetText(at and ("Données du site : " .. Util.Ago(at)) or "Données du site : pas encore reçues")
  local pending = DR.Comm:Pending()
  if DR.Comm:Locked() and pending > 0 then
    self.syncText:SetText(pending .. " message(s) en attente : envoi après le combat")
  elseif pending > 0 then
    self.syncText:SetText("Envoi à la guilde en cours (" .. pending .. ")")
  elseif DR.Guild:IAmOfficer() then
    local n, others = DR.Bridge:PendingCount()
    if n > 0 then
      self.syncText:SetText(n .. " changement(s) à passer au site" .. (others > 0 and (" (dont " .. others .. " d'autres membres)") or ""))
    else
      self.syncText:SetText("Rien à passer au site")
    end
  else
    self.syncText:SetText((DR.Guild.online or 0) .. " membre(s) en ligne")
  end
end

---------------------------------------------------------------------------
-- Messages du pied de page
---------------------------------------------------------------------------
local TOAST = { ok = C.teal, warn = C.amber, info = C.goldText, error = C.red }

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

function UI:Open(tab)
  local f = self:Build()
  f:Show()
  local map = { sorties = "sorties", artisans = "artisans", carte = "carte", effort = "effort", persos = "persos", pont = "pont" }
  if tab and map[tab] then self.tabBar:Select(map[tab]) end
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
