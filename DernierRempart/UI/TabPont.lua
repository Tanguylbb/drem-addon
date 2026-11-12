-- Onglet Pont (officiers) : l'état du relais automatique depuis le PC d'un
-- officier, et le copier-coller qui reste en secours.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Bridge = DR.Bridge

local Tab = {}
UI:RegisterTab("pont", "Pont", Tab)

local RELAY_H = 218
local MAX_BADGES = 5

local LEVELS = {
  ok = { color = C.green, text = "Relais connecté" },
  late = { color = C.amber, text = "Relais en retard" },
  stopped = { color = C.red, text = "Relais arrêté" },
  none = { color = C.muted, text = "Pas de relais détecté" },
}

function Tab:Create(f, width, height)
  self.f = f

  -- Le relais automatique ---------------------------------------------------
  local relay = T.Card(f)
  relay:SetPoint("TOPLEFT", 0, 0)
  relay:SetSize(width, RELAY_H)
  local h1 = T.Text(relay, "caps", 11, C.muted)
  h1:SetPoint("TOPLEFT", 16, -14)
  h1:SetText("RELAIS AUTOMATIQUE DEPUIS MON PC")
  self.relayText = T.Text(relay, "semi", 12, C.muted)
  self.relayText:SetPoint("TOPRIGHT", -16, -13)
  self.relayText:SetJustifyH("RIGHT")
  self.relayDot = W.Dot(relay, 8)
  self.relayDot:SetPoint("RIGHT", self.relayText, "LEFT", -7, 0)

  local half = math.floor((width - 32 - 12) / 2)
  self.boxes = {}
  for i, title in ipairs({ "JEU VERS LE SITE", "SITE VERS LE JEU" }) do
    local box = T.Card(relay, C.sunk)
    box:SetPoint("TOPLEFT", 16 + (i - 1) * (half + 12), -38)
    box:SetSize(half, 66)
    local label = T.Text(box, "caps", 10, C.muted)
    label:SetPoint("TOPLEFT", 12, -9)
    label:SetText(title)
    box.when = T.Text(box, "semi", 12, C.ivory)
    box.when:SetPoint("TOPLEFT", 12, -26)
    box.counts = T.Text(box, "body", 12, C.muted)
    box.counts:SetPoint("TOPLEFT", 12, -44)
    box.counts:SetPoint("RIGHT", -12, 0)
    self.boxes[i] = box
  end

  self.relayHelp = T.Para(relay, "body", 12, C.brume, width - 32)
  self.relayHelp:SetPoint("TOPLEFT", 16, -114)
  local rl = T.Text(relay, "caps", 11, C.muted)
  rl:SetPoint("TOPLEFT", 16, -158)
  rl:SetText("QUI ASSURE LE RELAIS")
  self.badges = {}
  for i = 1, MAX_BADGES do
    local b = W.Badge(relay)
    if i == 1 then b:SetPoint("TOPLEFT", 16, -178) else b:SetPoint("LEFT", self.badges[i - 1], "RIGHT", 8, 0) end
    self.badges[i] = b
  end

  -- Le copier-coller ----------------------------------------------------------
  local top = RELAY_H + 10
  local paste = T.Card(f)
  paste:SetPoint("TOPLEFT", 0, -top)
  paste:SetSize(width, height - top - 36)
  local h2 = T.Text(paste, "caps", 11, C.muted)
  h2:SetPoint("TOPLEFT", 16, -14)
  h2:SetText("COPIER-COLLER, SI LE RELAIS NE TOURNE PAS")
  local colW = half
  local boxH = 54

  -- Du site vers le jeu.
  local l1 = T.Text(paste, "semi", 13, C.ivory)
  l1:SetPoint("TOPLEFT", 16, -38)
  l1:SetText("Du site vers le jeu")
  self.inBox = W.CodeBox(paste, colW, boxH)
  self.inBox:SetPoint("TOPLEFT", 16, -58)
  self.inBox.edit:HookScript("OnTextChanged", function(_, user)
    if user then self.preview = nil; self:RefreshImport() end
  end)
  self.check = W.Button(paste, "Vérifier", "slate", 100, 26)
  self.check:SetPoint("TOPLEFT", self.inBox, "BOTTOMLEFT", 0, -8)
  self.check:SetScript("OnClick", function() self:Check() end)
  self.import = W.Button(paste, "Importer", "slate", 110, 26)
  self.import:SetPoint("LEFT", self.check, "RIGHT", 8, 0)
  self.import:SetScript("OnClick", function() self:Import() end)
  W.Tip(self.inBox, "Du site vers le jeu",
    "Sur " .. DR.SITE .. ", page Pont jeu, copie le code. Colle-le ici avec Ctrl+V, puis Vérifier : tu vois ce qui va changer avant de valider.")
  self.inResult = T.Para(paste, "body", 11, C.ivory, colW)
  self.inResult:SetPoint("TOPLEFT", self.check, "BOTTOMLEFT", 0, -6)
  self.inResult:SetMaxLines(4)

  -- Du jeu vers le site.
  local x2 = 16 + colW + 12
  local l2 = T.Text(paste, "semi", 13, C.ivory)
  l2:SetPoint("TOPLEFT", x2, -38)
  l2:SetText("Du jeu vers le site")
  self.outBox = W.CodeBox(paste, colW, boxH)
  self.outBox:SetPoint("TOPLEFT", x2, -58)
  self.gen = W.Button(paste, "Générer le code", "slate", 140, 26)
  self.gen:SetPoint("TOPLEFT", self.outBox, "BOTTOMLEFT", 0, -8)
  self.gen:SetScript("OnClick", function() self:Generate() end)
  self.select = W.Button(paste, "Tout sélectionner", "slate", 140, 26)
  self.select:SetPoint("LEFT", self.gen, "RIGHT", 8, 0)
  self.select:SetScript("OnClick", function() self.outBox:SelectAll() end)
  W.Tip(self.select, "Tout sélectionner", "Le jeu ne laisse pas un add-on copier pour toi : une fois le code sélectionné, tape Ctrl+C.")
  self.all = W.Check(paste, "Tout renvoyer", function(on) self.sendAll = on; self:Refresh() end)
  self.all:SetPoint("LEFT", self.select, "RIGHT", 10, 0)
  W.Tip(self.all, "Tout renvoyer", "Met dans le code toutes les données, pas seulement ce qui a changé depuis le dernier code. Sans risque : le site ne compte rien deux fois.")
  self.pending = T.Text(paste, "body", 11, C.ivory)
  self.pending:SetPoint("TOPLEFT", self.gen, "BOTTOMLEFT", 0, -8)
  self.pending:SetPoint("RIGHT", -16, 0)
  self.outHelp = T.Para(paste, "body", 11, C.ivory, colW)
  self.outHelp:SetPoint("TOPLEFT", self.pending, "BOTTOMLEFT", 0, -4)
  self.outHelp:SetMaxLines(3)

  -- Réglage des rangs officiers (chef de guilde) et synchro -------------------
  self.rankText = T.Text(f, "body", 11, C.muted)
  self.rankText:SetPoint("BOTTOMLEFT", 2, 8)
  self.rankMinus = W.Button(f, "–", "ghost", 26, 22)
  self.rankMinus:SetPoint("LEFT", self.rankText, "RIGHT", 10, 0)
  self.rankMinus:SetScript("OnClick", function() DR.Guild:SetOfficerRank(DR.Guild:OfficerRank() - 1) end)
  self.rankPlus = W.Button(f, "+", "ghost", 26, 22)
  self.rankPlus:SetPoint("LEFT", self.rankMinus, "RIGHT", 4, 0)
  self.rankPlus:SetScript("OnClick", function() DR.Guild:SetOfficerRank(DR.Guild:OfficerRank() + 1) end)
  self.syncBtn = W.Button(f, "Synchroniser la guilde", "gold", 210, 30)
  self.syncBtn:SetPoint("BOTTOMRIGHT", 0, 2)
  self.syncBtn:SetScript("OnClick", function()
    DR.Sync:Request("manuel")
    UI:Toast("Demande de synchro envoyée aux membres en ligne.", "ok")
  end)
end

---------------------------------------------------------------------------
-- Du site vers le jeu (copier-coller)
---------------------------------------------------------------------------
function Tab:Check()
  local payload, err = Bridge.Decode(self.inBox:GetText())
  if not payload then
    self.preview = nil
    self.inResult:SetText(T.Hex(C.amber) .. err .. "|r")
    self:RefreshImport()
    return
  end
  self.payload = payload
  self.preview = Bridge:Preview(payload)
  self:RefreshImport()
end

function Tab:RefreshImport()
  local p = self.preview
  self.import:SetEnabled(p ~= nil and p.total > 0)
  if not p then
    if self.inBox:GetText() == "" then self.inResult:SetText("") end
    return
  end
  local lines = {}
  local when = p.at and (" (données du site du " .. Util.ShortDate(p.at) .. ")") or ""
  if p.total == 0 then
    lines[1] = T.Hex(C.teal) .. "Rien de nouveau : tout est déjà à jour" .. when .. ".|r"
  else
    lines[1] = T.Hex(C.goldText) .. "Ce qui va changer" .. when .. " :|r"
    for _, l in ipairs(p.lines) do lines[#lines + 1] = "• " .. l end
  end
  if p.older > 0 then lines[#lines + 1] = T.Hex(C.muted) .. p.older .. " ligne(s) ignorée(s) : le jeu a plus récent.|r" end
  if p.rejected > 0 then lines[#lines + 1] = T.Hex(C.amber) .. p.rejected .. " ligne(s) illisible(s), ignorée(s).|r" end
  self.inResult:SetText(table.concat(lines, "\n"))
end

function Tab:Import()
  if not self.payload then return end
  local counts, err = Bridge:Import(self.payload, "manuel")
  if not counts then
    self.inResult:SetText(T.Hex(C.amber) .. err .. "|r")
    return
  end
  local parts = {}
  for _, ds in ipairs(Bridge.FROM_SITE) do
    if counts[ds] then parts[#parts + 1] = counts[ds] .. " " .. Bridge.LABELS[ds] end
  end
  self.inResult:SetText(T.Hex(C.teal) .. "Importé : " .. (#parts > 0 and table.concat(parts, ", ") or "rien de nouveau")
    .. ".|r\nPartagé avec la guilde connectée.")
  self.inBox:SetText("")
  self.preview, self.payload = nil, nil
  self.import:SetEnabled(false)
  UI:Toast("Données du site importées et partagées.", "ok")
end

---------------------------------------------------------------------------
-- Du jeu vers le site (copier-coller)
---------------------------------------------------------------------------
function Tab:Generate()
  local code, n = Bridge:Export(self.sendAll)
  if not code then
    UI:Toast(n or "Impossible de générer le code.", "warn")
    return
  end
  self.outBox:SetText(code)
  self.outBox:SelectAll()
  self.outHelp:SetText(T.Hex(C.teal) .. "Code prêt : " .. n .. " ligne(s).|r " .. T.Hex(C.goldText) .. "Ctrl+C|r"
    .. ", puis colle-le sur " .. DR.SITE .. ", page Pont jeu.")
  self:Refresh()
end

---------------------------------------------------------------------------
-- Rafraîchir
---------------------------------------------------------------------------
local function agoOr(t, fallback)
  if not t or t == 0 then return fallback end
  return Util.Ago(t)
end

function Tab:RefreshRelay()
  local st = Bridge:RelayStatus()
  local lv = LEVELS[st.level] or LEVELS.none
  self.relayDot:SetColorTexture(lv.color[1], lv.color[2], lv.color[3], 1)
  self.relayText:SetText(lv.text)
  T.Color(self.relayText, lv.color)

  local sent, recv = self.boxes[1], self.boxes[2]
  if st.lastSent then
    sent.when:SetText("Envoyé " .. agoOr(st.lastSent.when or st.lastSent.at, "récemment"))
    local text = Bridge.CountsText(st.lastSent.counts)
    sent.counts:SetText(text ~= "" and text or "Rien de nouveau à envoyer")
  else
    sent.when:SetText(st.present and "Pas encore d'envoi confirmé" or "Rien envoyé")
    sent.counts:SetText("Le relais le note ici dès que le site a reçu un code.")
  end
  if st.lastApply then
    recv.when:SetText("Reçu " .. agoOr(st.lastApply.at, "récemment") .. (st.lastApply.via == "manuel" and " · à la main" or ""))
    local text = Bridge.CountsText(st.lastApply.counts)
    recv.counts:SetText(text ~= "" and text or "Tout était déjà à jour")
  else
    recv.when:SetText("Rien reçu")
    recv.counts:SetText("Ce que le site envoie entre ici à la connexion ou au /reload.")
  end

  if st.level == "none" then
    self.relayHelp:SetText("Aucun relais détecté sur ce PC. Un petit programme chez un officier lit la sauvegarde de l'add-on, l'envoie au site et dépose ce que le site a de nouveau (voir docs/RELAIS.md). Sans lui, le copier-coller ci-dessous fait le même travail.")
  else
    self.relayHelp:SetText("Ce que le site envoie entre dans le jeu à la prochaine connexion ou au prochain /reload. Ce que le jeu écrit part au site quand tu te déconnectes ou fais /reload.")
  end

  -- Qui assure le relais.
  local list = st.relayers
  for i, b in ipairs(self.badges) do b:Hide() end
  local shown = 0
  for i, r in ipairs(list) do
    if i > MAX_BADGES - 1 then break end
    local b = self.badges[i]
    local role = i == 1 and "actif" or "secours"
    local text = r.name .. (r.me and " · toi" or "") .. " · " .. role
    if i > 1 or not r.me then text = text .. " · vu " .. Util.Ago(r.at):gsub("^il y a ", "") end
    b:Show()
    b:Set(text, (i == 1) and C.teal or C.brume)
    shown = i
  end
  local warn = nil
  if #list == 0 then warn = "Aucun officier n'assure le relais"
  elseif #list == 1 then warn = "Aucun secours"
  elseif #list == 2 then warn = "Aucun 2e secours" end
  if warn then
    local b = self.badges[shown + 1]
    b:Show()
    b:Set(warn, C.amber)
  end
end

function Tab:Refresh()
  if not self.f then return end
  self:RefreshRelay()
  local n, others = Bridge:PendingCount(self.sendAll)
  if self.sendAll then
    self.pending:SetText(T.Hex(C.goldText) .. n .. "|r ligne(s) en tout.")
  elseif n == 0 then
    self.pending:SetText("Rien de neuf depuis le dernier code.")
  else
    self.pending:SetText(T.Hex(C.goldText) .. n .. "|r changement(s) en attente"
      .. (others > 0 and (", dont " .. T.Hex(C.goldText) .. others .. "|r d'autres membres.") or "."))
  end
  local g = DR:GetGuildDB()
  local last = g and g.pont.lastExportAt or 0
  if last > 0 and not self.sendAll then
    self.pending:SetText(self.pending:GetText() .. T.Hex(C.muted) .. " Dernier code " .. Util.Ago(last) .. ".|r")
  end
  local rank = DR.Guild:OfficerRank()
  self.rankText:SetText("Seuil des officiers : rang " .. rank .. " (" .. DR.Guild:RankName(rank) .. ")"
    .. (DR.Guild:IAmLeader() and "" or " · réglé par le chef de guilde"))
  self.rankMinus:SetShown(DR.Guild:IAmLeader())
  self.rankPlus:SetShown(DR.Guild:IAmLeader())
  self:RefreshImport()
end
