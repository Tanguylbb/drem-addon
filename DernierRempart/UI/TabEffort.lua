-- Onglet Effort de guerre : les objectifs des officiers (une barre chacun, la
-- fiche de l'objectif choisi à droite), et le journal de la banque au même
-- endroit. Les dons sont lus tout seuls dans le journal de la banque de guilde ;
-- « Déclarer un don » ne sert que pour ce que la banque ne montre pas. Les
-- réglages de la banque vont chez les officiers.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Effort = DR.Effort

local Tab = {}
UI:RegisterTab("effort", "Effort de guerre", Tab)
Tab.icon = "tab_effort"
Tab.tip = "Les objectifs de la guilde, ce qui a été donné, et le journal de la banque."

local LEFT_W = 380
local GOAL_H = 68
local TOP = 38        -- les onglets Objectifs / Journal
local FOOT = 22       -- la ligne « banque lue il y a… »
local DAY = 86400

local function plain(link)
  return Util.LinkName(link) or link
end

local function periodText(g)
  if not g.from then return "" end
  local from, to = Util.DateParts(g.from), g.to and Util.DateParts(g.to)
  if to then
    if from.mois == to.mois then return "du " .. from.num .. " au " .. to.num .. " " .. to.mois end
    return "du " .. from.num .. " " .. from.mois .. " au " .. to.num .. " " .. to.mois
  end
  return "depuis le " .. from.num .. " " .. from.mois
end

local function amountText(g, n)
  if g.k == "or" then return Util.Money(n) end
  return tostring(n)
end

local function unitOf(g)
  if g.k == "or" then return "" end
  return " " .. (g.nm and plain(g.nm) or "objets")
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function Tab:Create(f, width, height)
  self.f, self.width, self.height = f, width, height
  self.view = "goals"
  self.period = "7"
  self.bodyH = height - TOP - FOOT

  self.strip = W.TabStrip(f, {
    { key = "goals", label = "Objectifs" },
    { key = "journal", label = "Journal de la banque" },
  }, function(key, user)
    self.view = key
    if user then self:Refresh() end
  end)
  self.strip:SetPoint("TOPLEFT", 0, -4)
  self.strip:SetWidth(width)
  self.strip:Select("goals")

  self.declareBtn = W.Button(f, "Déclarer un don", "red", 150, 28)
  self.declareBtn:SetPoint("TOPRIGHT", 0, 0)
  self.declareBtn:SetScript("OnClick", function() self:OpenDeclareForm() end)
  W.Tip(self.declareBtn, "Déclarer un don",
    "Seulement si ton dépôt n'apparaît pas dans la banque (par exemple un objet donné de la main à la main). Sinon il serait compté deux fois.")
  self.newBtn = W.Button(f, "+ Nouvel objectif  |cff9A9180(officiers)|r", "sec", 230, 24)
  self.newBtn:SetPoint("RIGHT", self.declareBtn, "LEFT", -8, 0)
  self.newBtn:SetScript("OnClick", function() self:OpenGoalForm(nil) end)

  -- Ligne d'état : quand la banque a été lue, et par qui.
  self.dot = W.Dot(f, 9)
  self.dot:SetPoint("BOTTOMLEFT", 2, 3)
  self.bankText = T.Text(f, "body", 11, C.muted)
  self.bankText:SetPoint("LEFT", self.dot, "RIGHT", 7, 0)
  self.bankText:SetWidth(width - 20)

  self.goalsPage = CreateFrame("Frame", nil, f)
  self.goalsPage:SetPoint("TOPLEFT", 0, -TOP)
  self.goalsPage:SetSize(width, self.bodyH)
  self.journalPage = CreateFrame("Frame", nil, f)
  self.journalPage:SetPoint("TOPLEFT", 0, -TOP)
  self.journalPage:SetSize(width, self.bodyH)
  self:BuildGoals(self.goalsPage, width, self.bodyH)
  self:BuildJournal(self.journalPage, width, self.bodyH)
  self:BuildGoalForm(f, width, height - TOP, TOP)
  self:BuildDeclareForm(f, width, height - TOP, TOP)
end

---------------------------------------------------------------------------
-- Les objectifs (à gauche) et la fiche (à droite)
---------------------------------------------------------------------------
local function createGoalRow(row)
  row.sel = row:CreateTexture(nil, "BACKGROUND")
  row.sel:SetAllPoints()
  row.sel:SetColorTexture(0.18, 0.165, 0.15, 1)
  row.title = T.Text(row, "body", 13, C.ivory)
  row.title:SetPoint("TOPLEFT", 12, -8)
  row.title:SetPoint("RIGHT", -100, 0)
  row.badge = W.Badge(row)
  row.badge:SetPoint("TOPRIGHT", -12, -7)
  row.bar = W.Bar(row, LEFT_W - 2 - 10 - 24, 18)
  row.bar:SetPoint("TOPLEFT", 12, -28)
  row.sub = T.Text(row, "body", 11, C.muted)
  row.sub:SetPoint("TOPLEFT", 12, -50)
  row.sub:SetPoint("RIGHT", -12, 0)
  row.sep = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.sep:SetPoint("BOTTOMLEFT", 0, 0)
  row.sep:SetPoint("BOTTOMRIGHT", 0, 0)
  row.sep:SetHeight(1)
  row.sep:SetColorTexture(C.rule[1], C.rule[2], C.rule[3], 1)
end

function Tab:BuildGoals(p, width, h)
  local fw = width - LEFT_W - 10
  self.openHeader = W.Header(p, LEFT_W)
  self.openHeader:SetPoint("TOPLEFT", 0, 0)
  self.openHeader:SetLabel("En cours", 0)
  self.openHeader.box:Hide()
  local function goalList(y, rows)
    return W.BlackList(p, {
      width = LEFT_W, height = rows * GOAL_H + 2, rowHeight = GOAL_H,
      create = createGoalRow,
      update = function(row, g) self:UpdateGoal(row, g) end,
      click = function(g) self.selected = g.id; self:Refresh() end,
    })
  end
  self.openBox, self.goals = goalList(0, 4)
  self.openBox:SetPoint("TOPLEFT", 0, -26)
  self.doneHeader = W.Header(p, LEFT_W)
  self.doneHeader:SetPoint("TOPLEFT", 0, -26 - 4 * GOAL_H - 12)
  self.doneHeader:SetLabel("Terminés", 0)
  self.doneHeader.box:Hide()
  self.doneBox, self.done = goalList(0, 2)
  self.doneBox:SetPoint("TOPLEFT", 0, -26 - 4 * GOAL_H - 12 - 26)

  -- La fiche de l'objectif choisi.
  local d = W.Navy(p)
  d:SetPoint("TOPLEFT", LEFT_W + 10, 0)
  d:SetSize(fw, h)
  self.fiche = d
  local pad = 16
  local inner = fw - 2 * pad
  d.empty = T.Para(d, "body", 13, C.brume, inner)
  d.empty:SetPoint("TOPLEFT", pad, -pad)
  local body = CreateFrame("Frame", nil, d)
  body:SetAllPoints()
  d.body = body
  d.title = T.Text(body, "title", 18, { 1, 1, 1 })
  d.title:SetPoint("TOP", 0, -16)
  d.title:SetJustifyH("CENTER")
  d.title:SetWidth(inner - 70)
  d.state = T.Text(body, "body", 13, C.amber)
  d.state:SetPoint("TOP", d.title, "BOTTOM", 0, -4)
  d.state:SetJustifyH("CENTER")
  d.more = W.Button(body, "…", "sec", 30, 22)
  d.more:SetPoint("TOPRIGHT", -pad, -14)
  d.more:SetScript("OnClick", function(btn)
    local g = self.selected and DR.Store:Get("goals", self.selected)
    if g then self:GoalMenu(btn, g) end
  end)
  d.bar = W.Bar(body, inner, 21)
  d.bar:SetPoint("TOPLEFT", pad, -66)
  d.about = T.Para(body, "body", 12, { 0.84, 0.86, 0.91 }, inner)
  d.about:SetPoint("TOPLEFT", pad, -98)
  d.about:SetMaxLines(4)
  d.mine = T.Text(body, "body", 13, C.muted)
  d.mine:SetPoint("TOPLEFT", pad, -156)
  d.movesHeader = W.Header(body, inner)
  d.movesHeader:SetPoint("TOPLEFT", pad, -184)
  d.movesHeader:SetLabel("Derniers dons")
  local mh = h - 184 - 28 - 40
  d.movesBox, d.moves = W.BlackList(body, {
    width = inner, height = mh, rowHeight = 22,
    create = function(row)
      row.text = T.Text(row, "body", 12, C.ivory)
      row.text:SetPoint("LEFT", 8, 0)
      row.text:SetPoint("RIGHT", -4, 0)
    end,
    update = function(row, gift)
      row.text:SetText(T.Hex(C.goldText) .. Util.ClassName(gift.c, DR.Profile:ClassOf(gift.c)) .. "|r a déposé "
        .. Effort:GiftText(gift) .. " " .. T.Hex(C.cyan) .. "(" .. Util.Ago(gift.at) .. ")|r")
    end,
  })
  d.movesBox:SetPoint("TOPLEFT", pad, -184 - 28)
  d.onlyMine = W.Check(body, "Seulement mes dons", function(on)
    self.onlyMine = on
    self:Refresh()
  end)
  d.onlyMine:SetPoint("BOTTOMLEFT", pad, 14)
end

function Tab:UpdateGoal(row, g)
  local p = Effort:Progress(g)
  local st = p.status
  local selected = self.selected == g.id
  row.sel:SetShown(selected)
  row.title:SetText(g.t)
  T.Color(row.title, selected and C.goldPale or C.ivory)
  if st == "done" then
    row.badge:Show(); row.badge:Set("Atteint", C.green)
  elseif st == "late" then
    row.badge:Show(); row.badge:Set("En retard", C.red)
  elseif st == "closed" then
    row.badge:Show(); row.badge:Set("Fermé", C.muted)
  elseif g.tag then
    row.badge:Show(); row.badge:Set(g.tag, C.brume)
  else
    row.badge:Hide()
  end
  local kind = st == "done" and "green" or (st == "late" and "red" or "gold")
  row.bar:Set(p.pct, kind, amountText(g, p.total) .. " sur " .. amountText(g, g.amt or 0) .. unitOf(g))
  local mineAmount = 0
  for _, gift in ipairs(Effort:Snapshot().gifts) do
    if gift.goal and gift.goal.id == g.id and DR.Profile:IsMine(gift.c) then mineAmount = mineAmount + gift.a end
  end
  local parts = {}
  if mineAmount > 0 then parts[#parts + 1] = "Tu as donné " .. amountText(g, mineAmount)
  elseif st ~= "done" and st ~= "closed" then parts[#parts + 1] = "Tu n'as rien donné" end
  parts[#parts + 1] = p.donors .. " donateur" .. (p.donors > 1 and "s" or "")
  if g.to and st ~= "done" and st ~= "closed" then parts[#parts + 1] = "fin le " .. Util.DayMonth(g.to) end
  row.sub:SetText(table.concat(parts, " · "))
end

---------------------------------------------------------------------------
-- Le journal de la banque : chiffres, membres, mouvements
---------------------------------------------------------------------------
local WHY = {
  classer = { text = "À classer", color = C.amber },
  ignore = { text = "Ne compte pas", color = C.muted },
  aucun = { text = "Hors objectif", color = C.muted },
}

function Tab:BuildJournal(p, width, h)
  self.chips = W.Chips(p, {
    { key = "7", label = "7 jours" },
    { key = "30", label = "30 jours" },
    { key = "all", label = "Tout ce qui est lu" },
  }, function(key, user)
    self.period = key
    if user then self:Refresh() end
  end)
  self.chips:SetPoint("TOPRIGHT", 0, -2)
  self.chips:Select("7")

  local sw = 150
  self.stats = {}
  for i = 1, 3 do
    local s = W.Stat(p, sw)
    s:SetPoint("TOPLEFT", (i - 1) * (sw + 8), 0)
    self.stats[i] = s
  end

  local top = 58
  local colH = h - top - 20
  local lw = 300
  self.membersHeader = W.Header(p, lw)
  self.membersHeader:SetPoint("TOPLEFT", 0, -top)
  self.membersHeader:SetLabel("Par membre")
  self.membersHeader.box:Hide()
  local mbox, members = W.BlackList(p, {
    width = lw, height = colH - 28, rowHeight = 28,
    create = function(row)
      row.name = T.Text(row, "body", 12, C.goldText)
      row.name:SetPoint("LEFT", 10, 0)
      row.name:SetWidth(150)
      row.amount = T.Text(row, "body", 12, C.ivory)
      row.amount:SetPoint("LEFT", 164, 0)
      row.amount:SetPoint("RIGHT", -8, 0)
      row.amount:SetJustifyH("RIGHT")
    end,
    update = function(row, m)
      row.name:SetText(Util.ClassName(m.name, DR.Profile:ClassOf(m.name)))
      local parts = {}
      if m.gold > 0 then parts[#parts + 1] = Util.Money(m.gold) end
      if m.items > 0 then parts[#parts + 1] = m.items .. " objet" .. (m.items > 1 and "s" or "") end
      row.amount:SetText(table.concat(parts, " · "))
    end,
  })
  mbox:SetPoint("TOPLEFT", 0, -top - 28)
  self.members = members

  local rx = lw + 10
  local rw = width - rx
  self.movesHeader = W.Header(p, rw)
  self.movesHeader:SetPoint("TOPLEFT", rx, -top)
  self.movesHeader:SetLabel("Journal lu dans la banque")
  self.movesHeader.box:Hide()
  local jbox, moves = W.BlackList(p, {
    width = rw, height = colH - 28, rowHeight = 32,
    create = function(row)
      row.when = T.Text(row, "body", 11, C.muted)
      row.when:SetPoint("LEFT", 10, 0)
      row.when:SetWidth(120)
      row.who = T.Text(row, "body", 12, C.goldText)
      row.who:SetPoint("LEFT", 134, 0)
      row.who:SetWidth(130)
      row.amount = T.Text(row, "body", 12, C.ivory)
      row.amount:SetPoint("LEFT", 268, 0)
      row.amount:SetPoint("RIGHT", -150, 0)
      row.badge = W.Badge(row)
      row.badge:SetPoint("RIGHT", -10, 0)
      row.sort = W.Button(row, "Classer", "red", 70, 22)
      row.sort:SetPoint("RIGHT", -10, 0)
      row.sep = row:CreateTexture(nil, "BACKGROUND")
      row.sep:SetPoint("BOTTOMLEFT", 0, 0)
      row.sep:SetPoint("BOTTOMRIGHT", 0, 0)
      row.sep:SetHeight(1)
      row.sep:SetColorTexture(C.rule[1], C.rule[2], C.rule[3], 1)
    end,
    update = function(row, gift) self:UpdateMove(row, gift) end,
    click = function(gift, row) self:MoveMenu(row, gift) end,
  })
  jbox:SetPoint("TOPLEFT", rx, -top - 28)
  self.moves = moves

  self.note = T.Text(p, "body", 11, C.muted)
  self.note:SetPoint("BOTTOMLEFT", 2, 0)
  self.note:SetWidth(width)
  self.note:SetText("Le jeu ne montre que les derniers mouvements, banque ouverte. Seuls les dépôts sont gardés ; l'heure est connue à l'heure près.")
end

function Tab:UpdateMove(row, gift)
  row.when:SetText(Util.WhenText(gift.at))
  row.who:SetText(Util.ClassName(gift.c, DR.Profile:ClassOf(gift.c)))
  row.amount:SetText("+ " .. Effort:GiftText(gift))
  local officer = DR.Guild:IAmOfficer()
  if gift.goal then
    row.badge:Show(); row.sort:Hide()
    local title = gift.goal.t
    if #title > 18 then title = Util.Truncate(title, 17) .. "…" end
    row.badge:Set(title, C.green)
  elseif gift.why == "classer" and officer then
    row.badge:Hide(); row.sort:Show()
    row.sort:SetScript("OnClick", function(btn) self:MoveMenu(btn, gift) end)
  else
    local w = WHY[gift.why] or WHY.aucun
    row.sort:Hide(); row.badge:Show()
    row.badge:Set(w.text, w.color)
  end
end

---------------------------------------------------------------------------
-- Menus des officiers
---------------------------------------------------------------------------
function Tab:GoalMenu(anchor, g)
  if not DR.Guild:IAmOfficer() then return end
  local items = {
    { text = "Modifier", func = function() self:OpenGoalForm(g) end },
    { text = g.st == "closed" and "Rouvrir" or "Fermer : arrêter de compter",
      func = function() Effort:SetGoalStatus(g.id, g.st == "closed" and "open" or "closed"); self:Refresh() end },
    { text = "Supprimer", color = C.red, func = function() Effort:DeleteGoal(g.id); self.selected = nil; self:Refresh() end },
  }
  W.OpenMenu(anchor, items, 230)
end

function Tab:MoveMenu(anchor, gift)
  if not DR.Guild:IAmOfficer() then return end
  local items = {}
  for _, g in ipairs(Effort:Snapshot().goals) do
    if g.k == gift.k and (g.k ~= "objet" or g.it == gift.it) and g.st ~= "closed" then
      items[#items + 1] = { text = "Compter pour : " .. g.t, checked = gift.goal and gift.goal.id == g.id,
        func = function() Effort:Classify(gift, g.id); self:Refresh() end }
    end
  end
  items[#items + 1] = { text = "Ne compte pour aucun objectif", checked = gift.why == "ignore",
    func = function() Effort:Classify(gift, "-"); self:Refresh() end }
  if gift.src == "hand" then
    items[#items + 1] = { text = "Retirer ce don déclaré", color = C.red,
      func = function() Effort:Remove(gift); self:Refresh() end }
  end
  W.OpenMenu(anchor, items, 280)
end

---------------------------------------------------------------------------
-- Formulaire : nouvel objectif
---------------------------------------------------------------------------
local function labeled(parent, text, x, y)
  local l = T.Text(parent, "semi", 11, C.goldPale)
  l:SetPoint("TOPLEFT", x, y)
  l:SetText(text)
  return l
end

function Tab:BuildGoalForm(f, width, h, top)
  local form = T.Card(f)
  form:SetPoint("TOPLEFT", 0, -top)
  form:SetSize(width, h)
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:Hide()
  self.form = form
  local pad = 18
  form.heading = T.Text(form, "title", 20, C.goldText)
  form.heading:SetPoint("TOPLEFT", pad, -pad)

  local y = -56
  labeled(form, "Titre", pad, y)
  form.t = W.Edit(form, width - 2 * pad, 26, "Tabards de guilde, onglet 2 du coffre, potions pour le raid…", 80)
  form.t:SetPoint("TOPLEFT", pad, y - 16)

  y = y - 54
  labeled(form, "Ce qu'on veut", pad, y)
  form.kinds = {}
  for i, k in ipairs({ "or", "objet" }) do
    local b = W.Button(form, k == "or" and "De l'or" or "Des objets", "toggle", 110, 26)
    b:SetPoint("TOPLEFT", pad + (i - 1) * 116, y - 16)
    b:SetScript("OnClick", function() self:SetFormKind(k) end)
    form.kinds[k] = b
  end
  labeled(form, "Quantité", pad + 250, y)
  form.amt = W.Edit(form, 130, 26, "200 po", 20)
  form.amt:SetPoint("TOPLEFT", pad + 250, y - 16)

  y = y - 54
  form.itemLabel = labeled(form, "Objet (Maj+clic sur l'objet pour coller son lien)", pad, y)
  form.item = W.Edit(form, width - 2 * pad, 26, "Potion de résistance au feu", 400)
  form.item.acceptLinks = true
  form.item:SetPoint("TOPLEFT", pad, y - 16)

  y = y - 54
  labeled(form, "Étiquette (facultatif)", pad, y)
  form.tag = W.Edit(form, 220, 26, "Cœur du Magma", 40)
  form.tag:SetPoint("TOPLEFT", pad, y - 16)
  labeled(form, "Début (JJ/MM, sinon maintenant)", pad + 240, y)
  form.from = W.Edit(form, 130, 26, "10/11", 10)
  form.from:SetPoint("TOPLEFT", pad + 240, y - 16)
  labeled(form, "Fin (JJ/MM)", pad + 394, y)
  form.to = W.Edit(form, 130, 26, "30/11", 10)
  form.to:SetPoint("TOPLEFT", pad + 394, y - 16)

  local help = T.Para(form, "body", 11, C.muted, width - 2 * pad)
  help:SetPoint("TOPLEFT", pad, y - 58)
  help:SetText("L'or déposé dans la banque compte pour l'objectif en or en cours, les objets pour l'objectif qui les attend. "
    .. "Seuls comptent les dépôts faits à partir du début : sans date, c'est maintenant. "
    .. "Pour compter ce que le journal de la banque montre déjà, mets une date de début passée "
    .. "(le journal ne garde que les derniers mouvements).")

  form.save = W.Button(form, "Enregistrer", "red", 150, 30)
  form.save:SetPoint("BOTTOMLEFT", pad, pad)
  form.save:SetScript("OnClick", function() self:SaveGoalForm() end)
  form.cancel = W.Button(form, "Annuler", "sec", 110, 30)
  form.cancel:SetPoint("LEFT", form.save, "RIGHT", 10, 0)
  form.cancel:SetScript("OnClick", function() form:Hide() end)
  form.error = T.Text(form, "semi", 12, C.amber)
  form.error:SetPoint("BOTTOMLEFT", form.save, "TOPLEFT", 0, 10)
end

function Tab:SetFormKind(k)
  local form = self.form
  form.kind = k
  for kk, b in pairs(form.kinds) do b:SetActive(kk == k) end
  form.item:SetShown(k == "objet")
  form.itemLabel:SetShown(k == "objet")
  form.amt:SetPlaceholder(k == "or" and "200 po" or "40")
end

function Tab:OpenGoalForm(g)
  if not DR.Guild:IAmOfficer() then return end
  local form = self.form
  form.editing = g and g.id or nil
  form.heading:SetText(g and "Modifier l'objectif" or "Nouvel objectif")
  form.t:SetText(g and g.t or "")
  self:SetFormKind(g and g.k or "or")
  form.amt:SetText(g and (g.k == "or" and Util.Money(g.amt) or tostring(g.amt)) or "")
  form.item:SetText(g and g.nm or "")
  form.tag:SetText(g and g.tag or "")
  local function day(t) return t and string.format("%02d/%02d/%d", Util.DateParts(t).num, date("*t", t).month, Util.DateParts(t).annee) or "" end
  form.from:SetText(g and day(g.from) or "")
  form.to:SetText(g and day(g.to) or "")
  form.error:SetText("")
  form:Show()
  form.t:SetFocus()
end

function Tab:SaveGoalForm()
  local form = self.form
  local editing = form.editing
  local item = form.item:GetText()
  -- Modifier sans recoller le lien : on garde l'objet d'origine.
  local existing = form.editing and DR.Store:Get("goals", form.editing)
  if form.kind == "objet" and existing and existing.it and not item:find("|H", 1, true) then
    item = "|Hitem:" .. existing.it .. "|h[" .. (existing.nm or "objet") .. "]|h"
  end
  local rec, err = Effort:SaveGoal({
    id = form.editing, t = form.t:GetText(), k = form.kind, amt = form.amt:GetText(), item = item,
    tag = form.tag:GetText(), from = form.from:GetText(), to = form.to:GetText(),
  })
  if not rec then
    form.error:SetText(err or "Impossible d'enregistrer.")
    return
  end
  form:Hide()
  if not editing then self.selected = rec.id end
  self.view = "goals"
  self.strip:Select("goals")
  UI:Toast(editing and "Objectif modifié." or "Objectif créé : partagé avec la guilde.", "ok")
  self:Refresh()
end

---------------------------------------------------------------------------
-- Formulaire : déclarer un don à la main
---------------------------------------------------------------------------
function Tab:BuildDeclareForm(f, width, h, top)
  local form = T.Card(f)
  form:SetPoint("TOPLEFT", 0, -top)
  form:SetSize(width, h)
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:Hide()
  self.declare = form
  local pad = 18
  form.heading = T.Text(form, "title", 20, C.goldText)
  form.heading:SetPoint("TOPLEFT", pad, -pad)
  form.heading:SetText("Déclarer un don")
  local intro = T.Para(form, "body", 12, C.brume, width - 2 * pad)
  intro:SetPoint("TOPLEFT", pad, -54)
  intro:SetText("À utiliser seulement si ton dépôt n'apparaît pas dans la banque de guilde. Un dépôt fait dans la banque est lu tout seul : le déclarer en plus le compterait deux fois. Un officier peut corriger une déclaration.")

  local y = -120
  labeled(form, "Pour quel objectif", pad, y)
  form.goalBtn = W.Button(form, "Choisir…", "sec", 360, 26)
  form.goalBtn:SetPoint("TOPLEFT", pad, y - 16)
  form.goalBtn:SetScript("OnClick", function(btn)
    local items = {}
    for _, g in ipairs(Effort:Goals("open")) do
      items[#items + 1] = { text = g.t, checked = form.goal == g.id, func = function()
        form.goal = g.id
        form.goalBtn:SetLabel(g.t)
        form.amt:SetPlaceholder(g.k == "or" and "25 po" or "5")
      end }
    end
    if #items == 0 then items[1] = { text = "Aucun objectif en cours", disabled = true } end
    W.OpenMenu(btn, items, 360)
  end)
  y = y - 54
  labeled(form, "Combien (or : « 25 po », objets : un nombre)", pad, y)
  form.amt = W.Edit(form, 200, 26, "25 po", 20)
  form.amt:SetPoint("TOPLEFT", pad, y - 16)
  y = y - 54
  labeled(form, "Un petit mot (facultatif)", pad, y)
  form.note = W.Edit(form, width - 2 * pad, 26, "Donné en main propre à…", 120)
  form.note:SetPoint("TOPLEFT", pad, y - 16)

  form.save = W.Button(form, "Déclarer mon don", "red", 180, 30)
  form.save:SetPoint("BOTTOMLEFT", pad, pad)
  form.save:SetScript("OnClick", function()
    local rec, err = Effort:Declare(form.goal, form.amt:GetText(), form.note:GetText())
    if not rec then
      form.error:SetText(err or "Impossible de déclarer.")
      return
    end
    form:Hide()
    UI:Toast("Don déclaré : partagé avec la guilde.", "ok")
    self:Refresh()
  end)
  form.cancel = W.Button(form, "Annuler", "sec", 110, 30)
  form.cancel:SetPoint("LEFT", form.save, "RIGHT", 10, 0)
  form.cancel:SetScript("OnClick", function() form:Hide() end)
  form.error = T.Text(form, "semi", 12, C.amber)
  form.error:SetPoint("BOTTOMLEFT", form.save, "TOPLEFT", 0, 10)
end

function Tab:OpenDeclareForm()
  local form = self.declare
  form.goal = nil
  local open = Effort:Goals("open")
  -- L'objectif choisi à l'écran, sinon le seul en cours.
  if self.selected then
    for _, g in ipairs(open) do if g.id == self.selected then form.goal = g.id end end
  end
  if not form.goal and #open == 1 then form.goal = open[1].id end
  local chosen = form.goal and DR.Store:Get("goals", form.goal)
  form.goalBtn:SetLabel(chosen and chosen.t or "Choisir…")
  form.amt:SetText("")
  form.note:SetText("")
  form.error:SetText("")
  form:Show()
  form.amt:SetFocus()
end

---------------------------------------------------------------------------
-- Rafraîchir
---------------------------------------------------------------------------
function Tab:SetView(view)
  self.view = view
  self.strip:Select(view)
  self:Refresh()
end

function Tab:RefreshBankLine(ready)
  if not ready then
    self.dot:SetColor(C.muted)
    self.bankText:SetText(IsInGuild() and "Chargement de la guilde…" or "Pas de guilde : rien n'est partagé.")
    return
  end
  local s = Effort:BankStatus()
  if s then
    local age = Util.Now() - (s.at or 0)
    self.dot:SetColor(age < 3 * DAY and C.green or C.amber)
    self.bankText:SetText("Banque de guilde lue " .. Util.Ago(s.at) .. " par " .. Util.ShortName(s.by or "?")
      .. (s.nw > 0 and (" · " .. s.nw .. " nouveau" .. (s.nw > 1 and "x" or "") .. " mouvement" .. (s.nw > 1 and "s" or "")) or "")
      .. " · le journal ne garde que les derniers mouvements")
  else
    self.dot:SetColor(C.amber)
    self.bankText:SetText("La banque n'a pas encore été lue : ouvre-la en jeu, le journal est lu tout seul.")
  end
end

function Tab:RefreshGoals(ready, officer)
  local open = ready and Effort:Goals("open") or {}
  local closed = ready and Effort:Goals("closed") or {}
  self.openHeader:SetLabel("En cours", #open)
  self.doneHeader:SetLabel("Terminés", #closed)
  self.goals:SetEmptyText(officer and "Aucun objectif en cours. Crée-en un avec « Nouvel objectif »." or "Aucun objectif en cours pour l'instant.")
  self.done:SetEmptyText("Aucun objectif terminé.")
  self.goals:SetItems(open, true)
  self.done:SetItems(closed, true)

  -- L'objectif choisi : le premier en cours si aucun n'est choisi.
  local found
  for _, g in ipairs(open) do if g.id == self.selected then found = g end end
  for _, g in ipairs(closed) do if g.id == self.selected then found = g end end
  if not found then
    found = open[1] or closed[1]
    self.selected = found and found.id or nil
  end

  local d = self.fiche
  if not found then
    d.body:Hide(); d.empty:Show()
    d.empty:SetText(ready and "Aucun objectif pour l'instant. Les officiers en créent ; la banque de guilde est lue toute seule." or "Chargement de la guilde…")
    return
  end
  d.empty:Hide(); d.body:Show()
  local g = found
  local p = Effort:Progress(g)
  local st = p.status
  d.title:SetText(g.t)
  local label, color = "En cours", C.amber
  if st == "done" then label, color = "Atteint", C.green
  elseif st == "late" then label, color = "En retard", C.red
  elseif st == "closed" then label, color = "Fermé", C.muted end
  d.state:SetText(label)
  T.Color(d.state, st == "going" and C.goldText or color)
  d.more:SetShown(officer)
  d.bar:Set(p.pct, st == "done" and "green" or (st == "late" and "red" or "gold"),
    amountText(g, p.total) .. " / " .. amountText(g, g.amt or 0) .. unitOf(g) .. " · " .. math.floor(p.pct * 100 + 0.5) .. " %")

  local about = {}
  local period = periodText(g)
  about[#about + 1] = (g.k == "or" and "Or déposé " or "Objets déposés dans la banque ") .. period .. (period:sub(-1) == "." and "" or ".")
  if g.to and st ~= "done" and st ~= "closed" then
    local now = Util.Now()
    local days = math.max(1, math.ceil((g.to - now) / DAY))
    local need = math.max(0, (g.amt or 0) - p.total)
    if now > g.to then
      about[#about + 1] = "La date est passée : il manque encore " .. amountText(g, need) .. unitOf(g) .. "."
    elseif need > 0 then
      about[#about + 1] = "Pour tenir la date, il faut encore environ " .. amountText(g, math.ceil(need / days)) .. " par jour."
    end
  end
  about[#about + 1] = "Les dons viennent du journal de la banque."
  d.about:SetText(table.concat(about, " "))

  -- Ma part et les derniers dons de cet objectif.
  local mine, all = 0, {}
  for _, gift in ipairs(Effort:Snapshot().gifts) do
    if gift.goal and gift.goal.id == g.id then
      all[#all + 1] = gift
      if DR.Profile:IsMine(gift.c) then mine = mine + gift.a end
    end
  end
  if mine > 0 then
    d.mine:SetText("Ma part : " .. T.Hex(C.goldText) .. amountText(g, mine) .. "|r " .. T.Hex(C.muted)
      .. "(" .. math.floor(mine / math.max(1, p.total) * 100 + 0.5) .. " %)|r")
  else
    d.mine:SetText("Tu n'as rien donné pour cet objectif.")
  end
  local see = Effort:CanSeeDetails()
  local moves = {}
  if see then
    for _, gift in ipairs(all) do
      if not self.onlyMine or DR.Profile:IsMine(gift.c) then moves[#moves + 1] = gift end
    end
  end
  d.onlyMine:SetChecked(self.onlyMine)
  d.moves:SetEmptyText(see and "Aucun don lu pour cet objectif. Ouvre la banque de guilde en jeu."
    or "Les officiers ont choisi de ne montrer que les totaux.")
  d.moves:SetItems(moves, true)
end

function Tab:RefreshJournal(ready)
  local see = ready and Effort:CanSeeDetails()
  local days = tonumber(self.period)
  local since = days and (Util.Now() - days * DAY) or 0
  local moves, byMember, order = {}, {}, {}
  local gold, items, donors = 0, 0, {}
  if ready then
    for _, gift in ipairs(Effort:Snapshot().gifts) do
      if gift.at >= since then
        moves[#moves + 1] = gift
        if gift.k == "or" then gold = gold + gift.a else items = items + gift.a end
        donors[gift.c] = true
        local m = byMember[gift.c]
        if not m then
          m = { name = gift.c, gold = 0, items = 0 }
          byMember[gift.c] = m
          order[#order + 1] = m
        end
        if gift.k == "or" then m.gold = m.gold + gift.a else m.items = m.items + gift.a end
      end
    end
  end
  table.sort(order, function(a, b)
    if a.gold ~= b.gold then return a.gold > b.gold end
    if a.items ~= b.items then return a.items > b.items end
    return a.name < b.name
  end)
  local n = 0
  for _ in pairs(donors) do n = n + 1 end
  self.stats[1]:Set(Util.Money(gold), "or déposé", C.goldText)
  self.stats[2]:Set(items, "objets déposés", C.ivory)
  self.stats[3]:Set(n, "donateur" .. (n > 1 and "s" or ""), C.green)
  self.moves:SetEmptyText(see and "Rien de lu sur cette période. Ouvre la banque de guilde en jeu."
    or "Les officiers ont choisi de ne montrer que les totaux (réglage dans l'écran Officiers).")
  self.members:SetEmptyText(see and "Personne pour l'instant." or "Détail réservé aux officiers.")
  self.moves:SetItems(see and moves or {}, true)
  self.members:SetItems(see and order or {}, true)
  local toSort = ready and DR.Guild:IAmOfficer() and Effort:ToSort() or 0
  self.movesHeader:SetExtra(toSort > 0 and (toSort .. " à classer") or "", C.amber)
end

function Tab:Refresh()
  if not self.f then return end
  local ready = DR.Store:IsReady()
  local officer = DR.Guild:IAmOfficer()
  self.newBtn:SetShown(officer)
  self.declareBtn:SetEnabled(ready and #Effort:Goals("open") > 0)
  self.goalsPage:SetShown(self.view == "goals")
  self.journalPage:SetShown(self.view == "journal")
  self:RefreshBankLine(ready)
  if self.view == "goals" then self:RefreshGoals(ready, officer) else self:RefreshJournal(ready) end
end

function Tab:OnShow()
  Effort.snap = nil
end

-- Pastille orange de l'onglet (officiers) : les dons à classer.
function Tab:Badge()
  if not DR.Store:IsReady() or not DR.Guild:IAmOfficer() then return 0 end
  local n = Effort:ToSort()
  return n, n == 1 and "1 don à classer." or (n .. " dons à classer.")
end
