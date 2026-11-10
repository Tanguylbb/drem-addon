-- Onglet Pont (officiers) : un code du site vers le jeu, un code du jeu vers
-- le site. Moins d'une minute.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Bridge = DR.Bridge

local Tab = {}
UI:RegisterTab("pont", "Pont", Tab)

function Tab:Create(f, width, height)
  self.f = f
  local colW = math.floor((width - 14) / 2)
  local colH = height - 40

  -- 1 · Du site vers le jeu ---------------------------------------------------
  local left = T.Card(f, { 0.04, 0.063, 0.14 })
  left:SetPoint("TOPLEFT", 0, 0)
  left:SetSize(colW, colH)
  local h1 = T.Text(left, "title", 18, C.goldText)
  h1:SetPoint("TOPLEFT", 14, -12)
  h1:SetText("1 · Du site vers le jeu")
  local t1 = T.Para(left, "body", 11, C.ivory, colW - 28)
  t1:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -8)
  t1:SetText("Sur " .. DR.SITE .. ", page Pont jeu, copie le code. Colle-le ici avec Ctrl+V, puis Vérifier : tu vois ce qui va changer avant de valider.")
  self.inBox = W.CodeBox(left, colW - 28, 150)
  self.inBox:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, -10)
  self.inBox.edit:HookScript("OnTextChanged", function(_, user)
    if user then self.preview = nil; self:RefreshImport() end
  end)
  self.check = W.Button(left, "Vérifier", "slate", 120, 30)
  self.check:SetPoint("TOPLEFT", self.inBox, "BOTTOMLEFT", 0, -10)
  self.check:SetScript("OnClick", function() self:Check() end)
  self.import = W.Button(left, "Importer", "gold", 140, 30)
  self.import:SetPoint("LEFT", self.check, "RIGHT", 8, 0)
  self.import:SetScript("OnClick", function() self:Import() end)
  self.inResult = T.Para(left, "body", 11, C.ivory, colW - 28)
  self.inResult:SetPoint("TOPLEFT", self.check, "BOTTOMLEFT", 0, -10)

  -- 2 · Du jeu vers le site ---------------------------------------------------
  local right = T.Card(f, { 0.04, 0.063, 0.14 })
  right:SetPoint("TOPLEFT", colW + 14, 0)
  right:SetSize(colW, colH)
  local h2 = T.Text(right, "title", 18, C.goldText)
  h2:SetPoint("TOPLEFT", 14, -12)
  h2:SetText("2 · Du jeu vers le site")
  self.pending = T.Para(right, "body", 12, C.ivory, colW - 28)
  self.pending:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -8)
  self.gen = W.Button(right, "Générer le code", "gold", 170, 30)
  self.gen:SetPoint("TOPLEFT", self.pending, "BOTTOMLEFT", 0, -10)
  self.gen:SetScript("OnClick", function() self:Generate() end)
  self.all = W.Check(right, "Tout renvoyer", function(on) self.sendAll = on; self:Refresh() end)
  self.all:SetPoint("LEFT", self.gen, "RIGHT", 14, 0)
  W.Tip(self.all, "Tout renvoyer", "Met dans le code toutes les données, pas seulement ce qui a changé depuis le dernier code. Sans risque : le site ne compte rien deux fois.")
  self.outBox = W.CodeBox(right, colW - 28, 150)
  self.outBox:SetPoint("TOPLEFT", self.gen, "BOTTOMLEFT", 0, -10)
  self.outHelp = T.Para(right, "body", 11, C.ivory, colW - 28)
  self.outHelp:SetPoint("TOPLEFT", self.outBox, "BOTTOMLEFT", 0, -10)
  self.lastCode = T.Text(right, "body", 10, C.muted)
  self.lastCode:SetPoint("BOTTOMLEFT", 14, 12)

  -- Réglage des rangs officiers (chef de guilde) ----------------------------
  self.rankText = T.Text(f, "body", 11, C.muted)
  self.rankText:SetPoint("BOTTOMLEFT", 2, 8)
  self.rankMinus = W.Button(f, "–", "ghost", 26, 22)
  self.rankMinus:SetPoint("LEFT", self.rankText, "RIGHT", 10, 0)
  self.rankMinus:SetScript("OnClick", function() DR.Guild:SetOfficerRank(DR.Guild:OfficerRank() - 1) end)
  self.rankPlus = W.Button(f, "+", "ghost", 26, 22)
  self.rankPlus:SetPoint("LEFT", self.rankMinus, "RIGHT", 4, 0)
  self.rankPlus:SetScript("OnClick", function() DR.Guild:SetOfficerRank(DR.Guild:OfficerRank() + 1) end)
  self.syncBtn = W.Button(f, "Synchroniser la guilde", "ghost", 190, 24)
  self.syncBtn:SetPoint("BOTTOMRIGHT", 0, 6)
  self.syncBtn:SetScript("OnClick", function()
    DR.Sync:Request("manuel")
    UI:Toast("Demande de synchro envoyée aux membres en ligne.", "ok")
  end)
end

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
  local counts, err = Bridge:Import(self.payload)
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

function Tab:Refresh()
  if not self.f then return end
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
  self.lastCode:SetText(last > 0 and ("Dernier code généré " .. Util.Ago(last) .. ".") or "Aucun code généré pour l'instant.")
  local rank = DR.Guild:OfficerRank()
  self.rankText:SetText("Officiers : rangs 0 à " .. rank .. " (" .. DR.Guild:RankName(rank) .. ")"
    .. (DR.Guild:IAmLeader() and "" or " · réglé par le chef de guilde"))
  self.rankMinus:SetShown(DR.Guild:IAmLeader())
  self.rankPlus:SetShown(DR.Guild:IAmLeader())
  self:RefreshImport()
end
