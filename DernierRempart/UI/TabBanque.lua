-- Onglet Banque : ce que le journal de la banque de guilde a montré, mouvement
-- par mouvement et membre par membre, et ce que ça rapporte à chaque objectif
-- de l'effort de guerre.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Effort = DR.Effort

local Tab = {}
UI:RegisterTab("banque", "Banque", Tab)

local LEFT_W = 300
local DAY = 86400

local WHY = {
  classer = { text = "À classer", color = C.amber },
  ignore = { text = "Ne compte pas", color = C.muted },
  aucun = { text = "Hors objectif", color = C.muted },
}

function Tab:Create(f, width, height)
  self.f, self.width = f, width
  self.period = "7"

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
    "Quand tu ouvres la banque de guilde, l'add-on lit son journal d'or et d'objets et note les dépôts.")

  self.chips = W.Chips(f, {
    { key = "7", label = "7 jours" },
    { key = "30", label = "30 jours" },
    { key = "all", label = "Tout ce qui est lu" },
  }, function(key, user)
    self.period = key
    if user then self:Refresh() end
  end)
  self.chips:SetPoint("TOPLEFT", 0, -42)
  self.chips:Select("7")

  self.diagBtn = W.Button(f, "Ce que le jeu rend", "ghost", 170, 26)
  self.diagBtn:SetPoint("TOPRIGHT", 0, -42)
  self.diagBtn:SetScript("OnClick", function()
    for _, line in ipairs(DR.Bank:Diagnose()) do DR:Print(line) end
  end)
  W.Tip(self.diagBtn, "Ce que le jeu rend",
    "Écrit dans le chat si le jeu donne le journal de la banque, et combien de lignes. Banque ouverte, c'est le plus parlant.")

  -- Trois chiffres.
  local sw = math.floor((width - 16) / 3)
  self.stats = {}
  for i = 1, 3 do
    local s = W.Stat(f, sw)
    s:SetPoint("TOPLEFT", (i - 1) * (sw + 8), -76)
    self.stats[i] = s
  end

  -- Par membre (à gauche).
  local top = -132
  local colH = height + top - 34
  local left = T.Card(f)
  left:SetPoint("TOPLEFT", 0, top)
  left:SetSize(LEFT_W, colH)
  local lt = T.Text(left, "caps", 11, C.muted)
  lt:SetPoint("TOPLEFT", 14, -14)
  lt:SetText("PAR MEMBRE")
  self.members = W.List(left, {
    width = LEFT_W - 2, height = colH - 40, rowHeight = 30,
    create = function(row)
      row.name = T.Text(row, "semi", 12)
      row.name:SetPoint("LEFT", 14, 0)
      row.name:SetWidth(150)
      row.amount = T.Text(row, "body", 12, C.ivory)
      row.amount:SetPoint("LEFT", 168, 0)
      row.amount:SetPoint("RIGHT", -10, 0)
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
  self.members:SetPoint("TOPLEFT", 1, -36)

  -- Le journal lu (à droite).
  local rx = LEFT_W + 8
  local rw = width - rx
  local right = T.Card(f)
  right:SetPoint("TOPLEFT", rx, top)
  right:SetSize(rw, colH)
  local rt = T.Text(right, "caps", 11, C.muted)
  rt:SetPoint("TOPLEFT", 14, -14)
  rt:SetText("JOURNAL LU DANS LA BANQUE")
  self.moves = W.List(right, {
    width = rw - 2, height = colH - 40, rowHeight = 34,
    create = function(row)
      row.when = T.Text(row, "body", 12, C.muted)
      row.when:SetPoint("LEFT", 12, 0)
      row.when:SetWidth(108)
      row.who = T.Text(row, "semi", 12, C.ivory)
      row.who:SetPoint("LEFT", 124, 0)
      row.who:SetWidth(130)
      row.amount = T.Text(row, "body", 12, C.ivory)
      row.amount:SetPoint("LEFT", 258, 0)
      row.amount:SetPoint("RIGHT", -150, 0)
      row.badge = W.Badge(row)
      row.badge:SetPoint("RIGHT", -8, 0)
      row.sep = row:CreateTexture(nil, "BACKGROUND")
      row.sep:SetPoint("BOTTOMLEFT", 0, 0)
      row.sep:SetPoint("BOTTOMRIGHT", 0, 0)
      row.sep:SetHeight(1)
      row.sep:SetColorTexture(C.rule[1], C.rule[2], C.rule[3], 1)
    end,
    update = function(row, gift)
      row.when:SetText(Util.WhenText(gift.at))
      row.who:SetText(Util.ClassName(gift.c, DR.Profile:ClassOf(gift.c)))
      row.amount:SetText("+ " .. Effort:GiftText(gift))
      if gift.goal then
        local title = gift.goal.t
        if #title > 18 then title = Util.Truncate(title, 17) .. "…" end
        row.badge:Set(title, C.teal)
      else
        local w = WHY[gift.why] or WHY.aucun
        row.badge:Set(w.text, w.color)
      end
    end,
    click = function(gift, row)
      local effort = UI.tabs.effort
      if effort and effort.MoveMenu then effort:MoveMenu(row, gift) end
    end,
  })
  self.moves:SetPoint("TOPLEFT", 1, -36)

  self.note = T.Para(f, "body", 11, C.muted, width)
  self.note:SetPoint("TOPLEFT", 0, top - colH - 6)
  self.note:SetText("Le jeu ne montre que les derniers mouvements de la banque, et seulement banque ouverte : ouvre-la de temps en temps. Seuls les dépôts sont gardés, pas les retraits. L'heure n'est connue qu'à l'heure près.")
end

function Tab:Refresh()
  if not self.f then return end
  local ready = DR.Store:IsReady()
  self.readBtn:SetLabel("Lecture à l'ouverture de la banque : " .. (DR.db.settings.readBank and "oui" or "non"))
  self.readBtn:SetActive(DR.db.settings.readBank)

  if not ready then
    self.dot:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)
    self.bankText:SetText(IsInGuild() and "Chargement de la guilde…" or "Pas de guilde : rien n'est partagé.")
    self.moves:SetItems({})
    self.members:SetItems({})
    return
  end
  local s = Effort:BankStatus()
  if s then
    local c = (Util.Now() - (s.at or 0)) < 3 * DAY and C.green or C.amber
    self.dot:SetColorTexture(c[1], c[2], c[3], 1)
    self.bankText:SetText("Banque de guilde lue " .. Util.Ago(s.at) .. " par " .. Util.ShortName(s.by or "?")
      .. " · " .. s.n .. " ligne" .. (s.n > 1 and "s" or "") .. " de dépôt")
  else
    self.dot:SetColorTexture(C.amber[1], C.amber[2], C.amber[3], 1)
    self.bankText:SetText("La banque n'a pas encore été lue : ouvre-la en jeu, le journal est lu tout seul.")
  end

  local see = Effort:CanSeeDetails()
  local days = tonumber(self.period)
  local since = days and (Util.Now() - days * DAY) or 0
  local moves, byMember, order = {}, {}, {}
  local gold, items, donors = 0, 0, {}
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
  table.sort(order, function(a, b)
    if a.gold ~= b.gold then return a.gold > b.gold end
    if a.items ~= b.items then return a.items > b.items end
    return a.name < b.name
  end)

  local n = 0
  for _ in pairs(donors) do n = n + 1 end
  self.stats[1]:Set(Util.Money(gold), "or déposé", C.goldText)
  self.stats[2]:Set(items, "objets déposés", C.ivory)
  self.stats[3]:Set(n, "donateur" .. (n > 1 and "s" or ""), C.teal)

  local empty = see and "Rien de lu sur cette période. Ouvre la banque de guilde en jeu."
    or "Les officiers ont choisi de ne montrer que les totaux (onglet Effort de guerre)."
  self.moves:SetEmptyText(empty)
  self.members:SetEmptyText(see and "Personne pour l'instant." or "Détail réservé aux officiers.")
  self.moves:SetItems(see and moves or {}, true)
  self.members:SetItems(see and order or {}, true)
end

function Tab:OnShow()
  Effort.snap = nil
end
