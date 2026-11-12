-- Onglet Effort de guerre : les objectifs des officiers, ce que la guilde a
-- déjà donné (lu dans le journal de la banque), et la déclaration à la main
-- quand un don n'apparaît pas dans la banque.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Effort = DR.Effort

local Tab = {}
UI:RegisterTab("effort", "Effort de guerre", Tab)

local LEFT_W = 396
local GOAL_H = 98

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

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function Tab:Create(f, width, height)
  self.f, self.width, self.height = f, width, height
  self.view = "open"

  -- Ligne d'état : quand la banque a été lue, et par qui.
  local strip = CreateFrame("Frame", nil, f)
  strip:SetPoint("TOPLEFT", 0, 0)
  strip:SetSize(width, 32)
  T.Fill(strip, C.sunk)
  T.Border(strip, C.line)
  self.dot = W.Dot(strip, 8)
  self.dot:SetPoint("LEFT", 12, 0)
  self.bankText = T.Text(strip, "body", 12, C.brume)
  self.bankText:SetPoint("LEFT", self.dot, "RIGHT", 8, 0)
  self.bankText:SetPoint("RIGHT", -310, 0)
  self.readBtn = W.Button(strip, "", "toggle", 292, 22)
  self.readBtn:SetPoint("RIGHT", -6, 0)
  self.readBtn:SetScript("OnClick", function()
    DR.db.settings.readBank = not DR.db.settings.readBank
    self:Refresh()
  end)
  W.Tip(self.readBtn, "Lecture de la banque",
    "Quand tu ouvres la banque de guilde, l'add-on lit son journal et note les dépôts d'or et d'objets. Rien n'est lu si tu coupes cette option.",
    "Le journal ne garde que les derniers mouvements : plus il y a de membres qui ouvrent la banque, moins il en manque.")

  self.chips = W.Chips(f, {
    { key = "open", label = "En cours" },
    { key = "closed", label = "Terminés" },
  }, function(key, user)
    self.view = key
    if user then self:Refresh() end
  end)
  self.chips:SetPoint("TOPLEFT", 0, -42)
  self.chips:Select("open")

  self.newBtn = W.Button(f, "Nouvel objectif", "slate", 160, 28)
  self.newBtn:SetPoint("TOPLEFT", LEFT_W - 160, -41)
  self.newBtn:SetScript("OnClick", function() self:OpenGoalForm(nil) end)

  local top = -78
  local colH = height + top

  -- Les objectifs (à gauche).
  local listH = math.floor((colH - 54) / GOAL_H) * GOAL_H
  self.goals = W.List(f, {
    width = LEFT_W, height = listH, rowHeight = GOAL_H,
    create = function(row)
      local card = T.Card(row)
      card:SetPoint("TOPLEFT", 0, 0)
      card:SetPoint("BOTTOMRIGHT", -8, 8)
      row.card = card
      row.title = T.Text(card, "title", 16, C.ivory)
      row.title:SetPoint("TOPLEFT", 14, -10)
      row.title:SetPoint("RIGHT", -130, 0)
      row.badge = W.Badge(card)
      row.badge:SetPoint("TOPRIGHT", -36, -9)
      row.more = W.Button(card, "…", "ghost", 24, 20)
      row.more:SetPoint("TOPRIGHT", -8, -8)
      row.bar = W.Bar(card, LEFT_W - 8 - 28, 8)
      row.bar:SetPoint("TOPLEFT", 14, -36)
      row.amount = T.Text(card, "body", 12, C.brume)
      row.amount:SetPoint("TOPLEFT", 14, -50)
      row.donors = T.Text(card, "body", 12, C.brume)
      row.donors:SetPoint("TOPRIGHT", -14, -50)
      row.donors:SetJustifyH("RIGHT")
      row.note = T.Text(card, "body", 11, C.muted)
      row.note:SetPoint("TOPLEFT", 14, -68)
      row.note:SetPoint("RIGHT", -14, 0)
    end,
    update = function(row, g) self:UpdateGoal(row, g) end,
    click = function(g, _, button)
      if button == "RightButton" then return end
      self.filterGoal = (self.filterGoal == g.id) and nil or g.id
      self:Refresh()
    end,
  })
  self.goals:SetPoint("TOPLEFT", 0, top)

  -- Mes dépôts, et la déclaration à la main.
  local mine = CreateFrame("Frame", nil, f)
  mine:SetPoint("TOPLEFT", 0, top - listH - 6)
  mine:SetSize(LEFT_W - 8, 46)
  T.Fill(mine, C.sunk)
  T.Border(mine, C.line)
  self.mineText = T.Para(mine, "body", 12, C.brume, LEFT_W - 8 - 170)
  self.mineText:SetPoint("LEFT", 12, 0)
  self.declareBtn = W.Button(mine, "Déclarer à la main", "ghost", 140, 24)
  self.declareBtn:SetPoint("RIGHT", -10, 0)
  self.declareBtn:SetScript("OnClick", function() self:OpenDeclareForm() end)
  W.Tip(self.declareBtn, "Déclarer un don",
    "Seulement si ton dépôt n'apparaît pas dans la banque (par exemple un objet donné de la main à la main). Sinon il serait compté deux fois.")

  -- Les derniers mouvements (à droite).
  local rx = LEFT_W + 8
  local rw = width - rx
  local right = T.Card(f)
  right:SetPoint("TOPLEFT", rx, top)
  right:SetSize(rw, colH)
  self.right = right
  self.rightTitle = T.Text(right, "caps", 11, C.muted)
  self.rightTitle:SetPoint("TOPLEFT", 14, -14)
  self.rightTitle:SetPoint("RIGHT", -110, 0)
  -- Un clic sur un objectif ne montre plus que ses dons : un bouton pour tout revoir.
  self.allBtn = W.Button(right, "Tout voir", "ghost", 90, 22)
  self.allBtn:SetPoint("TOPRIGHT", -10, -9)
  self.allBtn:SetScript("OnClick", function() self.filterGoal = nil; self:Refresh() end)
  self.allBtn:Hide()
  self.moves = W.List(right, {
    width = rw - 2, height = colH - 40 - 46, rowHeight = 36,
    create = function(row)
      row.when = T.Text(row, "body", 12, C.muted)
      row.when:SetPoint("LEFT", 12, 0)
      row.when:SetWidth(112)
      row.who = T.Text(row, "semi", 12, C.ivory)
      row.who:SetPoint("LEFT", 128, 0)
      row.who:SetWidth(116)
      row.amount = T.Text(row, "body", 12, C.ivory)
      row.amount:SetPoint("LEFT", 248, 0)
      row.amount:SetPoint("RIGHT", -130, 0)
      row.badge = W.Badge(row)
      row.badge:SetPoint("RIGHT", -8, 0)
      row.sort = W.Button(row, "Classer", "gold", 66, 22)
      row.sort:SetPoint("RIGHT", -8, 0)
      row.sep = row:CreateTexture(nil, "BACKGROUND")
      row.sep:SetPoint("BOTTOMLEFT", 0, 0)
      row.sep:SetPoint("BOTTOMRIGHT", 0, 0)
      row.sep:SetHeight(1)
      row.sep:SetColorTexture(C.rule[1], C.rule[2], C.rule[3], 1)
    end,
    update = function(row, gift) self:UpdateMove(row, gift) end,
    click = function(gift, row) self:MoveMenu(row, gift) end,
  })
  self.moves:SetPoint("TOPLEFT", 1, -34)

  local foot = CreateFrame("Frame", nil, right)
  foot:SetPoint("BOTTOMLEFT", 1, 1)
  foot:SetPoint("BOTTOMRIGHT", -1, 1)
  foot:SetHeight(44)
  local frule = T.Line(foot, C.line, 1)
  frule:SetPoint("TOPLEFT"); frule:SetPoint("TOPRIGHT")
  local flabel = T.Text(foot, "body", 12, C.brume)
  flabel:SetPoint("LEFT", 14, 0)
  flabel:SetText("Qui voit les noms et les montants")
  self.visChips = W.Chips(foot, {
    { key = "all", label = "Tous" },
    { key = "officers", label = "Officiers" },
  }, function(key, user)
    if user then
      if not Effort:SetVisibility(key) then UI:Toast("Réservé aux officiers.", "warn") end
      self:Refresh()
    end
  end)
  self.visChips:SetPoint("RIGHT", -12, 0)
  foot:EnableMouse(true)
  W.Tip(foot, "Qui voit les noms et les montants",
    "C'est un réglage d'affichage : tout le monde reçoit les mêmes données de la guilde, mais l'onglet ne montre le détail qu'à ceux que tu choisis.")

  self:BuildGoalForm(f, width, colH, top)
  self:BuildDeclareForm(f, width, colH, top)
end

---------------------------------------------------------------------------
-- Les lignes
---------------------------------------------------------------------------
function Tab:UpdateGoal(row, g)
  local p = Effort:Progress(g)
  local st = p.status
  local selected = self.filterGoal == g.id
  local border = (st == "done") and C.tealBorder or (selected and C.gold or C.line)
  T.Border(row.card, border, selected and 0.9 or 1)
  row.card.bg:SetColorTexture(selected and 0.085 or C.panel[1], selected and 0.14 or C.panel[2], selected and 0.23 or C.panel[3], 1)
  row.title:SetText(g.t)
  if st == "done" then
    row.badge:Set("Atteint", C.teal)
  elseif st == "late" then
    row.badge:Set("En retard", C.amber)
  elseif st == "closed" then
    row.badge:Set("Fermé", C.muted)
  elseif g.tag then
    row.badge:Set(g.tag, C.brume)
  else
    row.badge:Set(g.k == "or" and "Or" or "Objets", C.brume)
  end
  row.bar:Set(p.pct, st == "late" and C.amber or C.teal)
  local unit = g.k == "or" and "" or (" " .. (g.nm and plain(g.nm) or "objets"))
  row.amount:SetText(T.Hex(C.ivory) .. amountText(g, p.total) .. "|r sur " .. amountText(g, g.amt or 0) .. unit)
  local donors = p.donors .. " donateur" .. (p.donors > 1 and "s" or "")
  if g.to and st ~= "done" and st ~= "closed" then donors = donors .. " · fin le " .. Util.DayMonth(g.to) end
  row.donors:SetText(donors)
  if g.k == "or" then
    row.note:SetText("Or déposé " .. periodText(g))
  else
    row.note:SetText("Objets déposés dans la banque " .. periodText(g))
  end
  local officer = DR.Guild:IAmOfficer()
  row.more:SetShown(officer)
  row.more:SetScript("OnClick", function(btn) self:GoalMenu(btn, g) end)
end

local WHY = {
  classer = { text = "À classer", color = C.amber },
  ignore = { text = "Ne compte pas", color = C.muted },
  aucun = { text = "Hors objectif", color = C.muted },
}

function Tab:UpdateMove(row, gift)
  row.when:SetText(Util.WhenText(gift.at))
  row.who:SetText(Util.ClassName(gift.c, DR.Profile:ClassOf(gift.c)))
  row.amount:SetText((gift.k == "or" and "+ " or "+ ") .. Effort:GiftText(gift))
  local officer = DR.Guild:IAmOfficer()
  if gift.goal then
    row.badge:Show(); row.sort:Hide()
    local title = gift.goal.t
    if #title > 18 then title = Util.Truncate(title, 17) .. "…" end
    row.badge:Set(title, C.teal)
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
  local items = {
    { text = "Modifier", func = function() self:OpenGoalForm(g) end },
    { text = g.st == "closed" and "Rouvrir" or "Fermer : arrêter de compter",
      func = function() Effort:SetGoalStatus(g.id, g.st == "closed" and "open" or "closed"); self:Refresh() end },
    { text = "Supprimer", color = C.red, func = function() Effort:DeleteGoal(g.id); self:Refresh() end },
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
  form:SetPoint("TOPLEFT", 0, top)
  form:SetSize(width, h)
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:Hide()
  self.form = form
  local pad = 18
  form.heading = T.Text(form, "title", 22, C.goldText)
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

  form.save = W.Button(form, "Enregistrer", "gold", 150, 32)
  form.save:SetPoint("BOTTOMLEFT", pad, pad)
  form.save:SetScript("OnClick", function() self:SaveGoalForm() end)
  form.cancel = W.Button(form, "Annuler", "slate", 110, 32)
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
  UI:Toast(editing and "Objectif modifié." or "Objectif créé : partagé avec la guilde.", "ok")
  self:Refresh()
end

---------------------------------------------------------------------------
-- Formulaire : déclarer un don à la main
---------------------------------------------------------------------------
function Tab:BuildDeclareForm(f, width, h, top)
  local form = T.Card(f)
  form:SetPoint("TOPLEFT", 0, top)
  form:SetSize(width, h)
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:Hide()
  self.declare = form
  local pad = 18
  form.heading = T.Text(form, "title", 22, C.goldText)
  form.heading:SetPoint("TOPLEFT", pad, -pad)
  form.heading:SetText("Déclarer un don")
  local intro = T.Para(form, "body", 12, C.brume, width - 2 * pad)
  intro:SetPoint("TOPLEFT", pad, -54)
  intro:SetText("À utiliser seulement si ton dépôt n'apparaît pas dans la banque de guilde. Un dépôt fait dans la banque est lu tout seul : le déclarer en plus le compterait deux fois. Un officier peut corriger une déclaration.")

  local y = -120
  labeled(form, "Pour quel objectif", pad, y)
  form.goalBtn = W.Button(form, "Choisir…", "ghost", 360, 26)
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

  form.save = W.Button(form, "Déclarer mon don", "gold", 180, 32)
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
  form.cancel = W.Button(form, "Annuler", "slate", 110, 32)
  form.cancel:SetPoint("LEFT", form.save, "RIGHT", 10, 0)
  form.cancel:SetScript("OnClick", function() form:Hide() end)
  form.error = T.Text(form, "semi", 12, C.amber)
  form.error:SetPoint("BOTTOMLEFT", form.save, "TOPLEFT", 0, 10)
end

function Tab:OpenDeclareForm()
  local form = self.declare
  form.goal = nil
  local open = Effort:Goals("open")
  if #open == 1 then form.goal = open[1].id end
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
function Tab:Refresh()
  if not self.f then return end
  local ready = DR.Store:IsReady()
  local officer = DR.Guild:IAmOfficer()
  self.newBtn:SetShown(officer)
  self.readBtn:SetLabel("Lecture à l'ouverture de la banque : " .. (DR.db.settings.readBank and "oui" or "non"))
  self.readBtn:SetActive(DR.db.settings.readBank)

  -- Ligne d'état.
  if not ready then
    self.dot:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)
    self.bankText:SetText(IsInGuild() and "Chargement de la guilde…" or "Pas de guilde : rien n'est partagé.")
  else
    local s = Effort:BankStatus()
    if s then
      local age = Util.Now() - (s.at or 0)
      local c = age < 3 * 86400 and C.green or C.amber
      self.dot:SetColorTexture(c[1], c[2], c[3], 1)
      self.bankText:SetText("Banque de guilde lue " .. Util.Ago(s.at) .. " par " .. Util.ShortName(s.by or "?")
        .. (s.nw > 0 and (" · " .. s.nw .. " nouveau" .. (s.nw > 1 and "x" or "") .. " mouvement" .. (s.nw > 1 and "s" or "")) or ""))
    else
      self.dot:SetColorTexture(C.amber[1], C.amber[2], C.amber[3], 1)
      self.bankText:SetText("La banque n'a pas encore été lue : ouvre-la en jeu, le journal est lu tout seul.")
    end
  end

  -- Les objectifs.
  local list = ready and Effort:Goals(self.view) or {}
  local open, closed = #Effort:Goals("open"), #Effort:Goals("closed")
  if ready then
    self.chips:SetLabel("open", "En cours  " .. open)
    self.chips:SetLabel("closed", "Terminés  " .. closed)
  end
  self.goals:SetEmptyText(self.view == "open"
    and (officer and "Aucun objectif en cours. Crée-en un avec « Nouvel objectif »." or "Aucun objectif en cours pour l'instant.")
    or "Aucun objectif terminé.")
  self.goals:SetItems(list, true)

  -- Mes dépôts.
  if ready then
    local gold, items = Effort:Mine()
    if gold > 0 or items > 0 then
      local parts = {}
      if gold > 0 then parts[#parts + 1] = T.Hex(C.ivory) .. Util.Money(gold) .. "|r" end
      if items > 0 then parts[#parts + 1] = T.Hex(C.ivory) .. items .. "|r objet" .. (items > 1 and "s" or "") end
      self.mineText:SetText("Mes dépôts lus : " .. table.concat(parts, " et ") .. ". Rien à déclarer.")
    else
      self.mineText:SetText("Aucun dépôt lu à ton nom pour l'instant.")
    end
  end
  self.declareBtn:SetEnabled(ready and #Effort:Goals("open") > 0)

  -- Les derniers mouvements.
  local see = ready and Effort:CanSeeDetails()
  local moves = {}
  if see then
    for _, gift in ipairs(Effort:Recent(60)) do
      if not self.filterGoal or (gift.goal and gift.goal.id == self.filterGoal) then moves[#moves + 1] = gift end
    end
  end
  local title = "Derniers mouvements lus dans la banque"
  if self.filterGoal then
    local g = ready and DR.Store:Get("goals", self.filterGoal)
    if g then title = title .. " · " .. g.t else self.filterGoal = nil end
  end
  self.rightTitle:SetText(title:upper())
  self.allBtn:SetShown(self.filterGoal ~= nil)
  self.moves:SetEmptyText(see and "Aucun mouvement lu pour l'instant. Ouvre la banque de guilde en jeu."
    or "Les officiers ont choisi de ne montrer que les totaux.")
  self.moves:SetItems(moves, true)
  local vis = ready and Effort:Visibility() or "all"
  self.visChips:Select(vis, false)
  for _, b in pairs(self.visChips.buttons) do b:SetEnabled(officer) end
end

function Tab:OnShow()
  Effort.snap = nil
end
