-- Onglet Officiers : tout ce que seuls les officiers font, au même endroit et
-- invisible pour les membres. Le relais depuis le PC (son état en quelques
-- lignes), les réglages de la banque (lecture, qui voit les montants), le
-- seuil des officiers, la synchro, et le copier-coller de secours, replié.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Bridge = DR.Bridge
local Effort = DR.Effort

local Tab = {}
UI:RegisterTab("officiers", "Officiers", Tab)
Tab.icon = "tab_officiers"
Tab.tip = "Le relais avec le site, la lecture de la banque et les réglages. Réservé aux officiers."

local LEFT_W = 520
local RIGHT_X = 530
local MAX_BADGES = 5

local LEVELS = {
  ok = { color = C.green, text = "Relais connecté" },
  late = { color = C.amber, text = "Relais en retard" },
  stopped = { color = C.red, text = "Relais arrêté" },
  none = { color = C.muted, text = "Pas de relais détecté" },
}

local function section(parent, text, x, y, w)
  local h = W.Header(parent, w)
  h:SetPoint("TOPLEFT", x, y)
  h:SetLabel(text)
  h.box:Hide()
  return h
end

function Tab:Create(f, width, height)
  self.f = f
  local rw = width - RIGHT_X

  -- Le relais automatique (à gauche) ---------------------------------------------
  self.relayHeader = section(f, "Relais depuis mon PC", 0, 0, LEFT_W)
  local half = math.floor((LEFT_W - 8) / 2)
  self.boxes = {}
  for i, title in ipairs({ "Jeu vers le site", "Site vers le jeu" }) do
    local box = W.Inset(f)
    box:SetPoint("TOPLEFT", (i - 1) * (half + 8), -30)
    box:SetSize(half, 66)
    local label = T.Text(box, "body", 10, C.muted)
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetText(title:upper())
    box.when = T.Text(box, "body", 12, C.goldText)
    box.when:SetPoint("TOPLEFT", 10, -25)
    box.counts = T.Text(box, "body", 11, C.brume)
    box.counts:SetPoint("TOPLEFT", 10, -43)
    box.counts:SetPoint("RIGHT", -10, 0)
    self.boxes[i] = box
  end
  self.relayHelp = T.Para(f, "body", 11, C.brume, LEFT_W)
  self.relayHelp:SetPoint("TOPLEFT", 2, -106)
  local rl = T.Text(f, "body", 11, C.muted)
  rl:SetPoint("TOPLEFT", 2, -164)
  rl:SetText("QUI ASSURE LE RELAIS")
  self.badges = {}
  for i = 1, MAX_BADGES do
    local b = W.Badge(f)
    if i == 1 then b:SetPoint("TOPLEFT", 2, -184) else b:SetPoint("LEFT", self.badges[i - 1], "RIGHT", 8, 0) end
    self.badges[i] = b
  end

  -- La banque de guilde (à droite) ------------------------------------------------
  section(f, "Banque de guilde", RIGHT_X, 0, rw)
  local l1 = T.Text(f, "body", 12, C.brume)
  l1:SetPoint("TOPLEFT", RIGHT_X + 2, -42)
  l1:SetText("Lire le journal à l'ouverture")
  self.readBtn = W.Button(f, "Oui", "toggle", 60, 24)
  self.readBtn:SetPoint("TOPRIGHT", 0, -38)
  self.readBtn:SetScript("OnClick", function()
    DR.db.settings.readBank = not DR.db.settings.readBank
    self:Refresh()
  end)
  W.Tip(self.readBtn, "Lecture de la banque",
    "Quand tu ouvres la banque de guilde, l'add-on lit son journal et note les dépôts d'or et d'objets. Rien n'est lu si tu coupes cette option.",
    "Le journal ne garde que les derniers mouvements : plus il y a de membres qui ouvrent la banque, moins il en manque.")

  local l2 = T.Text(f, "body", 12, C.brume)
  l2:SetPoint("TOPLEFT", RIGHT_X + 2, -76)
  l2:SetText("Qui voit les montants")
  self.visChips = W.Chips(f, {
    { key = "all", label = "Tous" },
    { key = "officers", label = "Officiers" },
  }, function(key, user)
    if user then
      if not Effort:SetVisibility(key) then UI:Toast("Réservé aux officiers.", "warn") end
      self:Refresh()
    end
  end)
  self.visChips:SetPoint("TOPRIGHT", 0, -72)
  W.Tip(self.visChips.buttons.all, "Qui voit les noms et les montants",
    "C'est un réglage d'affichage : tout le monde reçoit les mêmes données de la guilde, mais l'écran ne montre le détail qu'à ceux que tu choisis.")

  self.diagBtn = W.Button(f, "Ce que le jeu rend du journal", "sec", rw, 24)
  self.diagBtn:SetPoint("TOPLEFT", RIGHT_X, -106)
  self.diagBtn:SetScript("OnClick", function()
    for _, line in ipairs(DR.Bank:Diagnose()) do DR:Print(line) end
  end)
  W.Tip(self.diagBtn, "Ce que le jeu rend",
    "Écrit dans la discussion si le jeu donne le journal de la banque, et combien de lignes. Banque ouverte, c'est le plus parlant.")

  -- Réglages ----------------------------------------------------------------------
  section(f, "Réglages", RIGHT_X, -146, rw)
  self.rankText = T.Text(f, "body", 12, C.brume)
  self.rankText:SetPoint("TOPLEFT", RIGHT_X + 2, -182)
  self.rankText:SetPoint("RIGHT", f, "TOPLEFT", RIGHT_X + rw - 66, 0)
  self.rankMinus = W.Button(f, "-", "sec", 28, 24)
  self.rankMinus:SetPoint("TOPRIGHT", -34, -178)
  self.rankMinus:SetScript("OnClick", function() DR.Guild:SetOfficerRank(DR.Guild:OfficerRank() - 1) end)
  self.rankPlus = W.Button(f, "+", "sec", 28, 24)
  self.rankPlus:SetPoint("TOPRIGHT", 0, -178)
  self.rankPlus:SetScript("OnClick", function() DR.Guild:SetOfficerRank(DR.Guild:OfficerRank() + 1) end)
  self.rankNote = T.Text(f, "body", 11, C.muted)
  self.rankNote:SetPoint("TOPLEFT", RIGHT_X + 2, -204)

  self.syncBtn = W.Button(f, "Synchroniser la guilde", "red", rw, 30)
  self.syncBtn:SetPoint("TOPLEFT", RIGHT_X, -232)
  self.syncBtn:SetScript("OnClick", function()
    DR.Sync:Request("manuel")
    UI:Toast("Demande de synchro envoyée aux membres en ligne.", "ok")
  end)
  self.goalBtn = W.Button(f, "Effort de guerre : nouvel objectif", "sec", rw, 26)
  self.goalBtn:SetPoint("TOPLEFT", RIGHT_X, -270)
  self.goalBtn:SetScript("OnClick", function()
    UI:Open("effort")
    local effort = UI.tabs.effort
    if effort and effort.OpenGoalForm then effort:SetView("goals"); effort:OpenGoalForm(nil) end
  end)

  -- Le copier-coller, replié : on l'ouvre seulement si le relais ne tourne pas.
  self.pasteHeader = W.Header(f, width)
  self.pasteHeader:SetPoint("TOPLEFT", 0, -328)
  self.pasteHeader:SetLabel("Copier-coller, en secours")
  self.pasteHeader:SetExtra("à ouvrir si le relais ne tourne pas")
  self.pasteHeader.onToggle = function(open)
    self.pasteOpen = open
    self:Refresh()
  end
  self.pasteHeader:SetOpen(false)
  self.pasteOpen = false

  local paste = CreateFrame("Frame", nil, f)
  paste:SetPoint("TOPLEFT", 0, -358)
  paste:SetSize(width, height - 358)
  self.paste = paste
  local colW = math.floor((width - 12) / 2)
  local boxH = 54

  -- Du site vers le jeu.
  local l3 = T.Text(paste, "body", 13, C.goldText)
  l3:SetPoint("TOPLEFT", 2, 0)
  l3:SetText("Du site vers le jeu")
  self.inBox = W.CodeBox(paste, colW, boxH)
  self.inBox:SetPoint("TOPLEFT", 0, -20)
  self.inBox.edit:HookScript("OnTextChanged", function(_, user)
    if user then self.preview = nil; self:RefreshImport() end
  end)
  self.check = W.Button(paste, "Vérifier", "sec", 100, 26)
  self.check:SetPoint("TOPLEFT", self.inBox, "BOTTOMLEFT", 0, -8)
  self.check:SetScript("OnClick", function() self:Check() end)
  self.import = W.Button(paste, "Importer", "sec", 110, 26)
  self.import:SetPoint("LEFT", self.check, "RIGHT", 8, 0)
  self.import:SetScript("OnClick", function() self:Import() end)
  W.Tip(self.inBox, "Du site vers le jeu",
    "Sur " .. DR.SITE .. ", page Pont jeu, copie le code. Colle-le ici avec Ctrl+V, puis Vérifier : tu vois ce qui va changer avant de valider.")
  self.inResult = T.Para(paste, "body", 11, C.ivory, colW)
  self.inResult:SetPoint("TOPLEFT", self.check, "BOTTOMLEFT", 0, -6)
  self.inResult:SetMaxLines(4)

  -- Du jeu vers le site.
  local x2 = colW + 12
  local l4 = T.Text(paste, "body", 13, C.goldText)
  l4:SetPoint("TOPLEFT", x2 + 2, 0)
  l4:SetText("Du jeu vers le site")
  self.outBox = W.CodeBox(paste, colW, boxH)
  self.outBox:SetPoint("TOPLEFT", x2, -20)
  self.gen = W.Button(paste, "Générer le code", "sec", 140, 26)
  self.gen:SetPoint("TOPLEFT", self.outBox, "BOTTOMLEFT", 0, -8)
  self.gen:SetScript("OnClick", function() self:Generate() end)
  self.select = W.Button(paste, "Tout sélectionner", "sec", 140, 26)
  self.select:SetPoint("LEFT", self.gen, "RIGHT", 8, 0)
  self.select:SetScript("OnClick", function() self.outBox:SelectAll() end)
  W.Tip(self.select, "Tout sélectionner", "Le jeu ne laisse pas un add-on copier pour toi : une fois le code sélectionné, tape Ctrl+C.")
  self.all = W.Check(paste, "Tout renvoyer", function(on) self.sendAll = on; self:Refresh() end)
  self.all:SetPoint("LEFT", self.select, "RIGHT", 10, 0)
  W.Tip(self.all, "Tout renvoyer", "Met dans le code toutes les données, pas seulement ce qui a changé depuis le dernier code. Sans risque : le site ne compte rien deux fois.")
  self.pending = T.Text(paste, "body", 11, C.ivory)
  self.pending:SetPoint("TOPLEFT", self.gen, "BOTTOMLEFT", 0, -8)
  self.pending:SetPoint("RIGHT", 0, 0)
  self.outHelp = T.Para(paste, "body", 11, C.ivory, colW)
  self.outHelp:SetPoint("TOPLEFT", self.pending, "BOTTOMLEFT", 0, -4)
  self.outHelp:SetMaxLines(3)
  paste:Hide()
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
    lines[1] = T.Hex(C.green) .. "Rien de nouveau : tout est déjà à jour" .. when .. ".|r"
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
  self.inResult:SetText(T.Hex(C.green) .. "Importé : " .. (#parts > 0 and table.concat(parts, ", ") or "rien de nouveau")
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
  -- Un code généré s'affiche : on ouvre la section si elle était repliée.
  if not self.pasteOpen then
    self.pasteOpen = true
    self.pasteHeader:SetOpen(true)
    self.paste:Show()
  end
  self.outBox:SetText(code)
  self.outBox:SelectAll()
  self.outHelp:SetText(T.Hex(C.green) .. "Code prêt : " .. n .. " ligne(s).|r " .. T.Hex(C.goldText) .. "Ctrl+C|r"
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
  self.relayHeader:SetExtra(lv.text, lv.color)

  local sent, recv = self.boxes[1], self.boxes[2]
  if st.lastSent then
    sent.when:SetText("Envoyé " .. agoOr(st.lastSent.when or st.lastSent.at, "récemment"))
    local text = Bridge.CountsText(st.lastSent.counts)
    sent.counts:SetText(text ~= "" and text or "Rien de nouveau à envoyer")
  else
    sent.when:SetText(st.present and "Pas encore d'envoi confirmé" or "Rien envoyé")
    sent.counts:SetText("Noté ici dès que le site a reçu un code.")
  end
  if st.lastApply then
    recv.when:SetText("Reçu " .. agoOr(st.lastApply.at, "récemment") .. (st.lastApply.via == "manuel" and " · à la main" or ""))
    local text = Bridge.CountsText(st.lastApply.counts)
    recv.counts:SetText(text ~= "" and text or "Tout était déjà à jour")
  else
    recv.when:SetText("Rien reçu")
    recv.counts:SetText("Ce que le site envoie entre ici à la connexion.")
  end

  if st.level == "none" then
    self.relayHelp:SetText("Aucun relais détecté sur ce PC. Un petit programme chez un officier lit la sauvegarde de l'add-on, l'envoie au site et dépose ce que le site a de nouveau (voir docs/RELAIS.md). Sans lui, le copier-coller ci-dessous fait le même travail.")
  else
    self.relayHelp:SetText("Ce que le site envoie entre dans le jeu à la prochaine connexion ou au prochain /reload. Ce que le jeu écrit part au site quand tu te déconnectes ou fais /reload.")
  end

  -- Qui assure le relais.
  local list = st.relayers
  for _, b in ipairs(self.badges) do b:Hide() end
  local shown = 0
  for i, r in ipairs(list) do
    if i > MAX_BADGES - 1 then break end
    local b = self.badges[i]
    local role = i == 1 and "actif" or "secours"
    local text = r.name .. (r.me and " · toi" or "") .. " · " .. role
    if i > 1 or not r.me then text = text .. " · vu " .. Util.Ago(r.at):gsub("^il y a ", "") end
    b:Show()
    b:Set(text, (i == 1) and C.green or C.brume)
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
  self.paste:SetShown(self.pasteOpen)
  self.pasteHeader:SetOpen(self.pasteOpen)
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
  self.rankText:SetText("Seuil des officiers : rang " .. rank .. " (" .. DR.Guild:RankName(rank) .. ")")
  self.rankNote:SetText(DR.Guild:IAmLeader() and "" or "Réglé par le chef de guilde.")
  self.rankMinus:SetShown(DR.Guild:IAmLeader())
  self.rankPlus:SetShown(DR.Guild:IAmLeader())
  self.readBtn:SetLabel(DR.db.settings.readBank and "Oui" or "Non")
  self.readBtn:SetActive(DR.db.settings.readBank)
  local vis = DR.Store:IsReady() and Effort:Visibility() or "all"
  self.visChips:Select(vis, false)
  for _, b in pairs(self.visChips.buttons) do b:SetEnabled(DR.Guild:IAmOfficer()) end
  self:RefreshImport()
end
