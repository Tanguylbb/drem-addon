-- Onglet Sorties : la liste à gauche, la fiche marine à droite. La réponse vient
-- d'abord (« Présent » est le bouton rouge) ; « Qui l'a vue » et « Relancer »
-- ne s'affichent que pour les officiers. Une bande ambre n'apparaît que si la
-- synchro prend du retard.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Cal = DR.Calendar

local Tab = {}
UI:RegisterTab("sorties", "Sorties", Tab)
Tab.icon = "tab_sorties"
Tab.tip = "Les raids, donjons et soirées de la guilde, et ta réponse."

local LIST_W = 300
local ROW_H = 54
local TOP = 30 -- la pastille de compte, au-dessus des deux colonnes
local GROUP_LABEL = { yes = "Présents", maybe = "Peut-être", bench = "Remplaçants", no = "Absents" }
local NEED_LABEL = { T = "Tanks voulus", H = "Soins voulus", D = "DPS voulus" }
local BAR_LABEL = { T = "Tanks", H = "Soins", D = "DPS" }

local function statusColor(s)
  local def = Cal.STATUSES[s]
  return def and { Util.Hex(def.color) } or C.muted
end

local function dark(c, k)
  return { c[1] * k, c[2] * k, c[3] * k }
end

---------------------------------------------------------------------------
-- Ligne de sortie (liste de gauche) : icône à gauche, boîte noire à droite
---------------------------------------------------------------------------
local function framedIcon(parent, size)
  return W.IconFrame(parent, size)
end

local function createRow(row)
  row.iconBox = framedIcon(row, 42)
  row.iconBox:SetPoint("LEFT", 2, 0)
  row.box = CreateFrame("Frame", nil, row)
  row.box:SetPoint("TOPLEFT", row.iconBox, "TOPRIGHT", 5, 2)
  row.box:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 2)
  row.box.bg = row.box:CreateTexture(nil, "BACKGROUND")
  row.box.bg:SetAllPoints()
  T.Gradient(row.box.bg, { 0.055, 0.055, 0.055 }, { 0.03, 0.03, 0.03 })
  T.Border(row.box, { 0.137, 0.125, 0.098 }, 1)
  row.title = T.Text(row.box, "body", 13, C.goldText)
  row.title:SetPoint("TOPLEFT", 9, -8)
  row.title:SetPoint("RIGHT", -34, 0)
  row.sub = T.Text(row.box, "body", 11, C.muted)
  row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
  row.sub:SetPoint("RIGHT", -34, 0)
  -- L'état de ma réponse : un rond de couleur avec un signe.
  row.stat = CreateFrame("Frame", nil, row.box)
  row.stat:SetSize(22, 22)
  row.stat:SetPoint("RIGHT", -7, 0)
  row.stat.dot = row.stat:CreateTexture(nil, "ARTWORK")
  row.stat.dot:SetAllPoints()
  row.stat.dot:SetTexture(T.Icon("dot"))
  row.stat.ring = row.stat:CreateTexture(nil, "OVERLAY")
  row.stat.ring:SetAllPoints()
  row.stat.ring:SetTexture(T.Icon("ring"))
  row.stat.check = row.stat:CreateTexture(nil, "OVERLAY", nil, 2)
  row.stat.check:SetSize(18, 18)
  row.stat.check:SetPoint("CENTER", 0, 0)
  row.stat.check:SetTexture(T.Icon("coche"))
  row.stat.glyph = T.Text(row.stat, "bold", 12, C.amber, "OVERLAY")
  row.stat.glyph:SetPoint("CENTER", 0, 0)
  row.stat.glyph:SetJustifyH("CENTER")
  row.stat.glyph:SetShadowColor(0, 0, 0, 0)
end

local function setStat(stat, glyph, c)
  local d = dark(c, 0.3)
  stat.dot:SetVertexColor(d[1], d[2], d[3])
  stat.ring:SetVertexColor(c[1], c[2], c[3])
  if glyph == "check" then
    stat.check:SetVertexColor(c[1], c[2], c[3])
    stat.check:Show(); stat.glyph:SetText("")
  else
    stat.check:Hide(); stat.glyph:SetText(glyph)
    T.Color(stat.glyph, c)
  end
end

local function updateRow(row, ev)
  local p = Util.DateParts(ev.d)
  local kind = Cal.KINDS[ev.k or "raid"] or Cal.KINDS.autre
  row.iconBox.icon:SetTexture(T.KIND_ICON[ev.k or "raid"] or T.KIND_ICON.autre)
  local cancelled = ev.st == "cancelled"
  row.title:SetText(ev.t)
  T.Color(row.title, cancelled and C.muted or C.goldText)
  row.sub:SetText(kind.label .. " · " .. p.jour .. " " .. p.num .. " " .. p.mois .. " · " .. p.heure)
  local mine = Cal:MySignup(ev.id)
  if cancelled then
    setStat(row.stat, "x", C.red)
  elseif mine then
    local sc = statusColor(mine.s)
    if mine.s == "yes" then setStat(row.stat, "check", C.green)
    elseif mine.s == "maybe" then setStat(row.stat, "?", sc)
    elseif mine.s == "bench" then setStat(row.stat, "R", sc)
    else setStat(row.stat, "-", C.red) end
  elseif not Cal:IsOpen(ev) then
    setStat(row.stat, "-", C.muted)
  else
    setStat(row.stat, "!", C.amber)
  end
  local selected = Tab.selected == ev.id
  if selected then
    T.Border(row.box, C.gold, 1, 2)
    row.iconBox:SetSelected(true)
  else
    T.Border(row.box, { 0.137, 0.125, 0.098 }, 1, 1)
    row.iconBox:SetSelected(false)
  end
  row:SetAlpha(cancelled and 0.6 or 1)
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function Tab:Create(f, width, height)
  self.f, self.width, self.height = f, width, height
  self.view = "upcoming"
  self.search = ""

  self.pill = W.Pill(f)
  self.pill:SetPoint("TOP", 0, 0)

  -- Colonne de gauche : recherche, À venir / Passées, liste, nouvelle sortie.
  local searchBox = W.Search(f, LIST_W, "Recherche", 40)
  searchBox:SetPoint("TOPLEFT", 0, -TOP)
  searchBox:HookScript("OnTextChanged", function(e)
    self.search = Util.Fold(e:GetText() or "")
    self:Refresh()
  end)
  self.searchBox = searchBox

  self.chips = W.Chips(f, {
    { key = "upcoming", label = "À venir" },
    { key = "past", label = "Passées" },
  }, function(key, user)
    self.view = key
    if user then self.selected = nil; self:Refresh() end
  end)
  self.chips:SetPoint("TOPLEFT", 0, -TOP - 30)
  self.chips:Select("upcoming")

  local listH = height - TOP - 60 - 34
  self.listBox, self.list = W.BlackList(f, {
    width = LIST_W, height = listH, rowHeight = ROW_H,
    create = createRow,
    update = updateRow,
    click = function(ev) self.selected = ev.id; self:Refresh() end,
  })
  self.listBox:SetPoint("TOPLEFT", 0, -TOP - 60)

  -- La bande ambre : seulement si la synchro prend du retard.
  local strip = CreateFrame("Frame", nil, self.listBox)
  strip:SetPoint("BOTTOMLEFT", 6, 6)
  strip:SetPoint("BOTTOMRIGHT", -6, 6)
  strip:SetHeight(44)
  strip:SetFrameLevel(self.listBox:GetFrameLevel() + 10)
  T.Fill(strip, { 0.29, 0.12, 0.05 })
  T.Border(strip, { 0.48, 0.17, 0.1 })
  self.syncText = T.Para(strip, "body", 11, { 0.96, 0.79, 0.54 }, LIST_W - 130)
  self.syncText:SetPoint("LEFT", 8, 0)
  self.syncBtn = W.Button(strip, "Redemander", "sec", 90, 24)
  self.syncBtn:SetPoint("RIGHT", -6, 0)
  self.syncBtn:SetScript("OnClick", function()
    DR.Sync:Request("manuel")
    UI:Toast("Demande envoyée à la guilde. Les réponses arrivent en quelques secondes.", "ok")
    self:Refresh()
  end)
  W.Tip(self.syncBtn, "Redemander à la guilde",
    "Demande aux membres en ligne qui ont l'add-on de t'envoyer ce que tu n'as pas (sorties, inscriptions, recettes). Aucune commande à taper.")
  strip:Hide()
  self.strip = strip

  self.newBtn = W.Button(f, "+ Nouvelle sortie  |cff9A9180(officiers)|r", "sec", LIST_W, 26)
  self.newBtn:SetPoint("BOTTOMLEFT", 0, 0)
  self.newBtn:SetScript("OnClick", function() self:OpenForm(nil) end)

  -- La fiche, à droite.
  local dw, dh = width - LIST_W - 10, height - TOP
  self.detail = W.Navy(f)
  self.detail:SetPoint("TOPLEFT", LIST_W + 10, -TOP)
  self.detail:SetSize(dw, dh)
  self:BuildDetail(self.detail, dw, dh)
  self:BuildForm(f, dw, dh)
end

function Tab:BuildDetail(d, w, h)
  local pad = 16
  local inner = w - 2 * pad
  d.empty = T.Para(d, "body", 13, C.brume, inner)
  d.empty:SetPoint("TOPLEFT", pad, -pad)

  local body = CreateFrame("Frame", nil, d)
  body:SetAllPoints(d)
  d.body = body

  d.iconBox = framedIcon(body, 42)
  d.iconBox:SetPoint("TOPLEFT", pad, -14)
  d.title = T.Text(body, "title", 19, { 1, 1, 1 })
  d.title:SetPoint("TOPLEFT", d.iconBox, "TOPRIGHT", 11, -1)
  d.title:SetPoint("RIGHT", -pad - 170, 0)
  d.sub = T.Text(body, "body", 11, C.muted)
  d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -5)
  d.sub:SetPoint("RIGHT", -pad - 8, 0)
  d.badge = W.Badge(body)
  d.badge:SetPoint("TOPLEFT", d.iconBox, "BOTTOMLEFT", 0, -6)

  -- Actions des officiers.
  d.editBtn = W.Button(body, "Modifier", "sec", 76, 22)
  d.editBtn:SetPoint("TOPRIGHT", -pad, -14)
  d.editBtn:SetScript("OnClick", function() self:OpenForm(Cal:Get(self.selected)) end)
  d.lockBtn = W.Button(body, "Fermer", "sec", 76, 22)
  d.lockBtn:SetPoint("RIGHT", d.editBtn, "LEFT", -6, 0)
  d.lockBtn:SetScript("OnClick", function()
    local ev = Cal:Get(self.selected)
    if not ev then return end
    Cal:SetStatus(ev.id, ev.st == "closed" and "open" or "closed")
    UI:Toast(ev.st == "closed" and "Inscriptions rouvertes." or "Inscriptions fermées.", "ok")
  end)
  W.Tip(d.lockBtn, "Fermer ou rouvrir les inscriptions")

  -- Besoins par rôle : trois barres, comme celles des métiers.
  local bw = math.floor((inner - 16) / 3)
  d.needs = {}
  for i, role in ipairs(Util.ROLES) do
    local bar = W.Bar(body, bw, 18)
    bar:SetPoint("TOPLEFT", pad + (i - 1) * (bw + 8), -86)
    d.needs[role] = bar
  end
  d.missing = T.Text(body, "semi", 12, C.amber)
  d.missing:SetPoint("TOPLEFT", pad, -110)

  d.info = T.Para(body, "body", 12, C.ivory, inner)
  d.info:SetPoint("TOPLEFT", pad, -132)
  d.info:SetMaxLines(3)

  -- Ma réponse : d'abord le rôle (quand la sortie en demande), puis la réponse.
  local y = -178
  d.y = y
  d.ansHeader = W.Header(body, inner)
  d.ansHeader:SetPoint("TOPLEFT", pad, y)
  d.ansHeader:SetLabel("Ma réponse")
  d.ansHeader.onToggle = nil

  d.roleRow = CreateFrame("Frame", nil, body)
  d.roleRow:SetSize(inner, 26)
  d.roleLabel = T.Text(d.roleRow, "body", 12, C.brume)
  d.roleLabel:SetPoint("LEFT", 2, 0)
  d.roleLabel:SetText("Mon rôle")
  d.roleBtns = {}
  local rbw = 96
  for i, role in ipairs(Util.ROLES) do
    local b = W.Button(d.roleRow, Util.ROLE_LABEL[role], "toggle", rbw, 26)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 10, 0)
    b.icon:SetTexture(T.Icon(T.ROLE_ICON[role]))
    b:SetPoint("LEFT", 78 + (i - 1) * (rbw + 6), 0)
    b:SetScript("OnClick", function() self:PickRole(role) end)
    W.Tip(b, Util.ROLE_LABEL[role], "Le rôle que tu tiendras dans cette sortie. Il est proposé d'office la prochaine fois.")
    d.roleBtns[role] = b
  end

  d.answers = {}
  local aw = math.floor((inner - 18) / 4)
  local x = pad
  for _, s in ipairs(Cal.STATUS_ORDER) do
    local b = W.Button(body, Cal.STATUSES[s].label, "toggle", aw, 26)
    b.x = x
    b:SetScript("OnClick", function() self:Answer(s) end)
    d.answers[s] = b
    x = x + aw + 6
  end

  -- « Tu viens avec Perso · Modifier » : ou, une fois « Modifier » cliqué, le perso
  -- et le petit mot.
  d.line = T.Text(body, "body", 12, C.brume)
  d.change = W.Button(body, "Modifier", "ghost", 70, 20)
  d.change:SetScript("OnClick", function()
    self.editing = not self.editing
    self:RefreshAnswer()
  end)
  d.state = T.Text(body, "body", 11, C.muted)

  d.edit = CreateFrame("Frame", nil, body)
  d.edit:SetSize(inner - 84, 26)
  d.charBtn = W.Button(d.edit, "Perso", "sec", 230, 24)
  d.charBtn:SetPoint("LEFT", 0, 0)
  d.charBtn:SetScript("OnClick", function(btn) self:OpenCharMenu(btn) end)
  d.note = W.Edit(d.edit, 100, 24, "Petit mot (60 caractères)", 60)
  d.note:SetPoint("LEFT", d.charBtn, "RIGHT", 8, 0)
  d.note:SetPoint("RIGHT", d.edit, "RIGHT", 0, 0)
  d.note:SetScript("OnEnterPressed", function(e)
    e:ClearFocus()
    local mine = Cal:MySignup(self.selected)
    if mine then self:Answer(mine.s) end
  end)
  d.edit:Hide()

  -- Inscrits (la position dépend de la ligne « Mon rôle » : voir Tab:LayoutAnswer).
  local sy = y - 108
  d.signHeader = W.Header(body, inner)
  d.signHeader:SetLabel("Inscrits", 0)
  d.listH = math.max(60, h + sy - 28 - 12 - 46 - 8)
  d.signBox, d.signups = W.BlackList(body, {
    width = inner, height = d.listH, rowHeight = 19,
    create = function(row)
      row.text = T.Text(row, "body", 12)
      row.text:SetPoint("LEFT", 8, 0)
      row.text:SetPoint("RIGHT", -2, 0)
    end,
    update = function(row, item) row.text:SetText(item.text) end,
  })
  d.signups:SetEmptyText("Personne n'est encore inscrit. Sois le premier !")
  d.pad = pad

  -- Pour les officiers : qui a répondu, qui ne l'a pas fait, qui n'a pas l'add-on.
  local seen = CreateFrame("Frame", nil, body)
  seen:SetPoint("BOTTOMLEFT", pad, 12)
  seen:SetSize(inner, 28)
  local rule = T.Line(seen, C.navyLine, 1)
  rule:SetPoint("TOPLEFT"); rule:SetPoint("TOPRIGHT")
  d.seenLabel = T.Text(seen, "body", 10, C.brume)
  d.seenLabel:SetPoint("LEFT", 0, -2)
  d.seenLabel:SetText("OFFICIERS")
  d.seenText = T.Text(seen, "body", 12, C.brume)
  d.seenText:SetPoint("LEFT", 66, -2)
  d.seenText:SetPoint("RIGHT", -84, 0)
  d.remind = W.Button(seen, "Relancer", "sec", 76, 22)
  d.remind:SetPoint("RIGHT", 0, -2)
  d.remind:SetScript("OnClick", function(btn) self:RemindMenu(btn) end)
  W.Tip(d.remind, "Relancer", "Ceux qui ont l'add-on et n'ont pas répondu : un clic prépare le chuchotement. Ceux qui n'ont pas l'add-on, c'est à toi de les prévenir sur Discord.")
  W.Tip(seen, "Qui a vu la sortie",
    "Les membres qui ont l'add-on et ont répondu, ceux qui ne l'ont pas fait, et ceux qui n'ont pas l'add-on.",
    "Chiffres approximatifs : un joueur qui a plusieurs persos sans add-on peut compter plusieurs fois.")
  seen:EnableMouse(true)
  d.seen = seen
end

---------------------------------------------------------------------------
-- Formulaire des officiers
---------------------------------------------------------------------------
local function labeled(parent, text, x, y)
  local l = T.Text(parent, "semi", 11, C.goldPale)
  l:SetPoint("TOPLEFT", x, y)
  l:SetText(text)
  return l
end

function Tab:BuildForm(f, w, h)
  local form = T.Card(f)
  form:SetPoint("TOPLEFT", LIST_W + 10, -TOP)
  form:SetSize(w, h)
  form:SetFrameLevel(self.detail:GetFrameLevel() + 10)
  form:EnableMouse(true)
  form:Hide()
  self.form = form
  local pad = 16

  form.heading = T.Text(form, "title", 20, C.goldText)
  form.heading:SetPoint("TOPLEFT", pad, -pad)

  local y = -54
  labeled(form, "Titre", pad, y)
  form.t = W.Edit(form, w - 2 * pad, 26, "Barrow Deeps, Onyxia, soirée pêche…", 80)
  form.t:SetPoint("TOPLEFT", pad, y - 16)

  y = y - 54
  labeled(form, "Type", pad, y)
  form.kinds = {}
  local x = pad
  for _, k in ipairs(Cal.KIND_ORDER) do
    local b = W.Button(form, Cal.KINDS[k].label, "toggle", 92, 26)
    b:SetPoint("TOPLEFT", x, y - 16)
    b:SetScript("OnClick", function()
      form.kind = k
      for kk, bb in pairs(form.kinds) do bb:SetActive(kk == k) end
    end)
    form.kinds[k] = b
    x = x + 98
  end

  y = y - 54
  labeled(form, "Date (JJ/MM/AAAA)", pad, y)
  form.date = W.Edit(form, 130, 26, "10/12/2026", 10)
  form.date:SetPoint("TOPLEFT", pad, y - 16)
  labeled(form, "Heure", pad + 142, y)
  form.time = W.Edit(form, 80, 26, "21:00", 5)
  form.time:SetPoint("TOPLEFT", pad + 142, y - 16)
  labeled(form, "Durée (min)", pad + 234, y)
  form.dur = W.Edit(form, 80, 26, "150", 4)
  form.dur:SetPoint("TOPLEFT", pad + 234, y - 16)
  labeled(form, "Places", pad + 326, y)
  form.cap = W.Edit(form, 70, 26, "10", 3)
  form.cap:SetPoint("TOPLEFT", pad + 326, y - 16)

  y = y - 54
  form.needs = {}
  x = pad
  for _, role in ipairs(Util.ROLES) do
    labeled(form, NEED_LABEL[role], x, y)
    local e = W.Edit(form, 90, 26, "0", 2)
    e:SetPoint("TOPLEFT", x, y - 16)
    form.needs[role] = e
    x = x + 112
  end

  y = y - 54
  labeled(form, "Chef de raid", pad, y)
  form.lead = W.Edit(form, 170, 26, "facultatif", 40)
  form.lead:SetPoint("TOPLEFT", pad, y - 16)
  labeled(form, "Rendez-vous", pad + 182, y)
  form.rdv = W.Edit(form, w - 2 * pad - 182, 26, "Entrée du repaire, Marécage d'Âprefange", 120)
  form.rdv:SetPoint("TOPLEFT", pad + 182, y - 16)

  y = y - 54
  labeled(form, "Note", pad, y)
  form.note = W.Edit(form, w - 2 * pad, 26, "Consignes, consommables, heure de fin…", 500)
  form.note:SetPoint("TOPLEFT", pad, y - 16)

  form.save = W.Button(form, "Enregistrer", "red", 150, 30)
  form.save:SetPoint("BOTTOMLEFT", pad, pad)
  form.save:SetScript("OnClick", function() self:SaveForm() end)
  form.cancel = W.Button(form, "Annuler", "sec", 110, 30)
  form.cancel:SetPoint("LEFT", form.save, "RIGHT", 10, 0)
  form.cancel:SetScript("OnClick", function() form:Hide() end)
  form.cancelEvent = W.Button(form, "Annuler la sortie", "danger", 150, 26)
  form.cancelEvent:SetPoint("BOTTOMRIGHT", -pad, pad + 2)
  form.cancelEvent:SetScript("OnClick", function()
    local ev = form.editing and Cal:Get(form.editing)
    if not ev then return end
    Cal:SetStatus(ev.id, ev.st == "cancelled" and "open" or "cancelled")
    form:Hide()
    UI:Toast(ev.st == "cancelled" and "Sortie rétablie." or "Sortie annulée : la guilde est prévenue.", "ok")
  end)
  form.error = T.Text(form, "semi", 12, C.amber)
  form.error:SetPoint("BOTTOMLEFT", form.save, "TOPLEFT", 0, 10)
end

function Tab:OpenForm(ev)
  if not DR.Guild:IAmOfficer() then return end
  local form = self.form
  form.editing = ev and ev.id or nil
  form.heading:SetText(ev and "Modifier la sortie" or "Nouvelle sortie")
  form.t:SetText(ev and ev.t or "")
  form.kind = ev and ev.k or "raid"
  for k, b in pairs(form.kinds) do b:SetActive(k == form.kind) end
  local p = ev and Util.DateParts(ev.d)
  form.date:SetText(ev and string.format("%02d/%02d/%d", p.num, date("*t", ev.d).month, p.annee) or "")
  form.time:SetText(ev and p.heure or "21:00")
  form.dur:SetText(ev and tostring(ev.dur or 120) or "150")
  form.cap:SetText(ev and ev.cap and tostring(ev.cap) or "")
  form.needs.T:SetText(ev and tostring(ev.nt or 0) or "")
  form.needs.H:SetText(ev and tostring(ev.nh or 0) or "")
  form.needs.D:SetText(ev and tostring(ev.nd or 0) or "")
  form.lead:SetText(ev and ev.lead or "")
  form.rdv:SetText(ev and ev.rdv or "")
  form.note:SetText(ev and ev.note or "")
  form.cancelEvent:SetShown(ev ~= nil)
  if ev then form.cancelEvent:SetLabel(ev.st == "cancelled" and "Rétablir la sortie" or "Annuler la sortie") end
  form.error:SetText("")
  form:Show()
  form.t:SetFocus()
end

function Tab:SaveForm()
  local form = self.form
  local d = Util.ParseDateTime(form.date:GetText(), form.time:GetText())
  local rec, err = Cal:SaveEvent({
    id = form.editing, t = form.t:GetText(), k = form.kind, d = d,
    dur = form.dur:GetText(), cap = form.cap:GetText(),
    nt = form.needs.T:GetText(), nh = form.needs.H:GetText(), nd = form.needs.D:GetText(),
    lead = form.lead:GetText(), rdv = form.rdv:GetText(), note = form.note:GetText(),
  })
  if not rec then
    form.error:SetText(err or "Impossible d'enregistrer.")
    return
  end
  form:Hide()
  self.selected = rec.id
  UI:Toast(form.editing and "Sortie modifiée : partagée avec la guilde." or "Sortie créée : partagée avec la guilde.", "ok")
  self:Refresh()
end

---------------------------------------------------------------------------
-- Ma réponse
---------------------------------------------------------------------------
function Tab:EligibleChars()
  local out = {}
  for _, c in ipairs(DR.Profile:MyChars()) do
    if not c.g or c.g == DR.Guild.name then out[#out + 1] = c end
  end
  return out
end

function Tab:OpenCharMenu(anchor)
  local items = {}
  for _, c in ipairs(self:EligibleChars()) do
    items[#items + 1] = {
      text = Util.ClassName(c.n, c.cl) .. T.Hex(C.muted) .. " (" .. (c.lv or "?") .. ")|r",
      checked = c.n == self.char,
      func = function()
        self.char = c.n
        self.role = DR.Profile:PreferredRole(c.n) or c.r or self.role
        self:RefreshAnswer()
      end,
    }
  end
  if #items == 0 then items[1] = { text = "Aucun perso de ce compte dans la guilde", disabled = true } end
  W.OpenMenu(anchor, items, 230)
end

-- Une sortie demande-t-elle des rôles ? (Sinon : soirée, entraide… on ne demande rien.)
local function wantsRoles(ev)
  return ((ev.nt or 0) + (ev.nh or 0) + (ev.nd or 0)) > 0
end
Tab.WantsRoles = wantsRoles

-- Ma réponse : la ligne « Mon rôle » n'existe que si la sortie demande des rôles ;
-- tout ce qui est dessous se décale d'autant.
function Tab:LayoutAnswer(hasRoles)
  local d = self.detail
  if d.laidRoles == hasRoles then return end
  d.laidRoles = hasRoles
  local pad, y = d.pad, d.y
  local extra = hasRoles and 30 or 0
  local ay = y - 32 - extra
  d.roleRow:ClearAllPoints()
  d.roleRow:SetPoint("TOPLEFT", pad, y - 32)
  d.roleRow:SetShown(hasRoles)
  for _, b in pairs(d.answers) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", b.x, ay)
  end
  d.line:ClearAllPoints()
  d.line:SetPoint("TOPLEFT", pad, ay - 36)
  d.line:SetPoint("RIGHT", -pad - 84, 0)
  d.change:ClearAllPoints()
  d.change:SetPoint("TOPRIGHT", -pad, ay - 33)
  d.state:ClearAllPoints()
  d.state:SetPoint("TOPLEFT", pad, ay - 54)
  d.state:SetPoint("RIGHT", -pad, 0)
  d.edit:ClearAllPoints()
  d.edit:SetPoint("TOPLEFT", pad, ay - 30)
  local sy = ay - 76
  d.signHeader:ClearAllPoints()
  d.signHeader:SetPoint("TOPLEFT", pad, sy)
  d.signBox:ClearAllPoints()
  d.signBox:SetPoint("TOPLEFT", pad, sy - 28)
  d.signBox:Resize(d.listH - extra)
end

-- Un clic sur un rôle : s'il y a déjà une réponse, elle est mise à jour tout de suite ;
-- sinon le rôle est retenu pour quand on répondra.
function Tab:PickRole(role)
  self.role = role
  local ev = Cal:Get(self.selected)
  local mine = ev and Cal:MySignup(ev.id)
  if mine and (Cal:IsOpen(ev) or DR.Guild:IAmOfficer()) then
    self:Answer(mine.s)
  else
    self:RefreshAnswer()
  end
end

function Tab:Answer(status)
  local ev = Cal:Get(self.selected)
  if not ev then return end
  local ok, err = Cal:SetSignup(ev.id, self.char or DR.playerName, status, self.role, self.detail.note:GetText())
  if ok then
    UI:Toast("Enregistré : " .. Cal.STATUSES[status].label .. ". Ça part à la guilde, puis au site.", "ok")
    -- Le rôle choisi ici devient celui proposé la prochaine fois.
    if (self.char or DR.playerName) == DR.playerName and self.role and self.role ~= DR.Profile:PreferredRole(DR.playerName) then
      DR.Profile:SetPreferredRole(self.role)
    end
    self.editing = false
  else
    UI:Toast(err, "warn")
  end
  self:Refresh()
end

function Tab:RefreshAnswer()
  local d = self.detail
  local ev = Cal:Get(self.selected)
  if not ev then return end
  local hasRoles = wantsRoles(ev)
  self:LayoutAnswer(hasRoles)
  local mine = Cal:MySignup(ev.id)
  local char = DR.db.myChars[self.char or ""] or DR.Store:Get("chars", self.char or "") or {}
  d.charBtn:SetLabel("Perso : " .. Util.ClassName(self.char or DR.playerName, char.cl)
    .. T.Hex(C.muted) .. " (" .. (char.lv or "?") .. ")|r")
  local open = Cal:IsOpen(ev) or DR.Guild:IAmOfficer()
  for role, b in pairs(d.roleBtns) do
    local on = self.role == role
    b:SetActive(on)
    b:SetEnabled(open)
    local c = on and C.redText or C.brume
    b.icon:SetVertexColor(c[1], c[2], c[3])
  end
  -- « Présent » est le bouton rouge tant qu'on n'a pas répondu ; ensuite, la réponse choisie.
  for s, b in pairs(d.answers) do
    b:SetActive(mine and mine.s == s or (not mine and s == "yes"))
    b:SetEnabled(open)
  end
  local who = Util.ShortName(self.char or DR.playerName)
  local role = (hasRoles and self.role) and (Util.ROLE_LABEL[self.role] or "") or ""
  d.edit:SetShown(self.editing and open)
  d.line:SetShown(not self.editing)
  d.change:SetShown(open)
  d.change:SetLabel(self.editing and "Fermer" or "Modifier")
  if not open then
    d.line:SetText(T.Hex(C.amber) .. "Inscriptions fermées.|r")
    d.state:SetText("")
  else
    d.line:SetText((mine and "Tu viens avec " or "Tu viendrais avec ") .. T.Hex(C.goldText) .. who .. "|r"
      .. (role ~= "" and (", en " .. role:lower()) or ""))
    if mine then
      d.state:SetText(T.Hex(C.green) .. "Ta réponse : " .. Cal.STATUSES[mine.s].label .. "|r" .. T.Hex(C.muted)
        .. " · " .. Util.Ago(mine.u) .. ". Partagée avec la guilde ; les officiers la passent au site.|r")
    else
      d.state:SetText(T.Hex(C.amber) .. "Tu viens ? Réponds en un clic." .. (hasRoles and " Ton rôle est déjà choisi." or "") .. "|r")
    end
  end
end

---------------------------------------------------------------------------
-- Relancer (officiers)
---------------------------------------------------------------------------
function Tab:RemindMenu(anchor)
  if not DR.Guild:IAmOfficer() or not self.selected then return end
  local seen = Cal:SeenBy(self.selected)
  local items = {}
  items[#items + 1] = { text = "N'ont pas répondu (" .. #seen.pendingNames .. ")", disabled = true }
  for i, name in ipairs(seen.pendingNames) do
    if i > 10 then break end
    items[#items + 1] = { text = "Écrire à " .. Util.ClassName(name, DR.Profile:ClassOf(name)), func = function() Util.Whisper(name) end }
  end
  if #seen.pendingNames > 10 then
    items[#items + 1] = { text = "et " .. (#seen.pendingNames - 10) .. " autres", disabled = true }
  end
  if seen.noAddon > 0 then
    items[#items + 1] = { text = seen.noAddon .. " sans add-on : à prévenir sur Discord", disabled = true }
  end
  W.OpenMenu(anchor, items, 280)
end

---------------------------------------------------------------------------
-- Rafraîchir
---------------------------------------------------------------------------
function Tab:Refresh()
  if not self.f then return end
  local ready = DR.Store:IsReady()
  local upcoming = ready and Cal:Upcoming(60) or {}
  local past = ready and Cal:Past(60) or {}
  self.chips:SetLabel("upcoming", "À venir  " .. #upcoming)
  self.chips:SetLabel("past", "Passées  " .. #past)
  self.pill:Set(self.view == "past" and "Sorties passées" or "Sorties à venir", self.view == "past" and #past or #upcoming)
  self.newBtn:SetShown(DR.Guild:IAmOfficer())

  local all = self.view == "past" and past or upcoming
  local items = all
  if self.search ~= "" then
    items = {}
    for _, ev in ipairs(all) do
      if Util.Fold(ev.t or ""):find(self.search, 1, true) then items[#items + 1] = ev end
    end
  end
  if not self.selected or not Cal:Get(self.selected) then
    self.selected = items[1] and items[1].id or nil
  end
  if not ready then
    self.list:SetEmptyText(IsInGuild() and "Chargement de la guilde…" or "Rejoins la guilde pour voir ses sorties.")
  elseif self.search ~= "" then
    self.list:SetEmptyText("Aucune sortie ne correspond.")
  elseif self.view == "past" then
    self.list:SetEmptyText("Aucune sortie passée ces 60 derniers jours.")
  else
    self.list:SetEmptyText("Aucune sortie prévue pour l'instant. Les officiers les créent sur le site ou ici, puis elles arrivent toutes seules.")
  end
  self.list:SetItems(items, true)
  self:RefreshSync()
  self:RefreshDetail()
end

-- La bande ambre : seulement si la guilde n'a pas répondu.
function Tab:RefreshSync()
  local s = DR.Store:IsReady() and DR.Sync:Status() or { level = "wait" }
  local late = s.level == "late"
  self.strip:SetShown(late)
  if late then
    self.syncText:SetText(Util.Truncate(s.text:gsub(" : redemande à la guilde.*$", "."), 90))
  end
  self.syncBtn:SetEnabled(DR.Store:IsReady() and IsInGuild())
end

function Tab:RefreshDetail()
  local d = self.detail
  local ev = self.selected and Cal:Get(self.selected)
  if not ev then
    d.body:Hide()
    d.empty:Show()
    d.empty:SetText("Choisis une sortie dans la liste pour voir qui vient et répondre.")
    return
  end
  d.empty:Hide()
  d.body:Show()
  local kind = Cal.KINDS[ev.k or "raid"] or Cal.KINDS.autre
  d.iconBox.icon:SetTexture(T.KIND_ICON[ev.k or "raid"] or T.KIND_ICON.autre)
  d.title:SetText(ev.t)
  local dur = ev.dur and ev.dur > 0 and (" · " .. (Util.Duration(ev.dur * 60) or "")) or ""
  local cap = ev.cap and (" · " .. ev.cap .. " joueurs") or ""
  local p = Util.DateParts(ev.d)
  d.sub:SetText(kind.label .. " · " .. p.jourLong .. " " .. p.num .. " " .. p.moisLong .. " à " .. p.heure .. dur .. cap
    .. " · " .. Util.Until(ev.d))
  if ev.st == "cancelled" then d.badge:Set("Annulée", C.red); d.badge:Show()
  elseif not Cal:IsOpen(ev) then d.badge:Set("Inscriptions fermées", C.amber); d.badge:Show()
  elseif ev.src == "site" then d.badge:Set("Du site", C.green); d.badge:Show()
  else d.badge:Hide() end

  local info = {}
  if ev.lead then info[#info + 1] = T.Hex(C.muted) .. "Chef de raid :|r " .. ev.lead end
  if ev.rdv then info[#info + 1] = T.Hex(C.muted) .. "Rendez-vous :|r " .. ev.rdv end
  local line = table.concat(info, "   ")
  if ev.note then line = line .. (line ~= "" and "\n" or "") .. T.Hex(C.muted) .. "Note :|r " .. ev.note end
  d.info:SetText(line)

  local counts = Cal:Counts(ev.id)
  local needs = { T = ev.nt or 0, H = ev.nh or 0, D = ev.nd or 0 }
  local anyNeed = false
  for role, bar in pairs(d.needs) do
    local need, have = needs[role], counts[role]
    bar:SetShown(need > 0)
    if need > 0 then
      anyNeed = true
      local ratio = have / need
      bar:Set(math.min(1, ratio), ratio >= 1 and "green" or (ratio >= 0.5 and "gold" or "red"), BAR_LABEL[role] .. " " .. have .. "/" .. need)
    end
  end
  local missing = Cal:MissingText(ev, counts)
  if missing then
    d.missing:SetText(missing)
    T.Color(d.missing, C.amber)
  elseif anyNeed then
    d.missing:SetText("Compo complète")
    T.Color(d.missing, C.green)
  else
    d.missing:SetText("")
  end

  local officer = DR.Guild:IAmOfficer()
  d.editBtn:SetShown(officer)
  d.lockBtn:SetShown(officer and ev.st ~= "cancelled")
  d.lockBtn:SetLabel(ev.st == "closed" and "Rouvrir" or "Fermer")
  d.seen:SetShown(officer)
  if officer then
    local seen = Cal:SeenBy(ev.id)
    d.seenText:SetText(T.Hex(C.green) .. seen.answered .. "|r ont répondu · " .. T.Hex(C.amber) .. seen.pending
      .. "|r pas encore · " .. T.Hex(C.amber) .. seen.noAddon .. "|r sans add-on")
  end

  -- Perso et rôle proposés : ceux de mon inscription, sinon le perso connecté.
  if self.answerFor ~= ev.id then
    self.answerFor = ev.id
    self.editing = false
    local mine = Cal:MySignup(ev.id)
    self.char = mine and mine.c or DR.playerName
    self.role = (mine and mine.r) or DR.Profile:PreferredRole(self.char) or "D"
    d.note:SetText(mine and mine.m or "")
  end
  self:RefreshAnswer()

  -- Liste des inscrits par réponse.
  local rows, groups, total = {}, {}, 0
  for _, s in ipairs(Cal:Signups(ev.id)) do
    groups[s.s] = groups[s.s] or {}
    table.insert(groups[s.s], s)
    total = total + 1
  end
  d.signHeader:SetLabel("Inscrits", total)
  for _, st in ipairs(Cal.STATUS_ORDER) do
    local g = groups[st]
    if g and #g > 0 then
      local sc = statusColor(st)
      rows[#rows + 1] = { text = T.Hex(sc) .. GROUP_LABEL[st] .. " (" .. #g .. ")|r" }
      for _, s in ipairs(g) do
        local txt = "   " .. (wantsRoles(ev) and (T.RoleIcon(s.r, 12, C.brume) .. "  ") or "") .. T.Hex(C.goldText) .. Util.ClassName(s.c, s.cl or DR.Profile:ClassOf(s.c)) .. "|r"
        if s.m then txt = txt .. T.Hex(C.muted) .. "  « " .. s.m .. " »|r" end
        if not DR.Guild:IsMember(s.c) and next(DR.Guild.members) then
          txt = txt .. T.Hex(C.muted) .. "  (hors guilde)|r"
        end
        rows[#rows + 1] = { text = txt }
      end
    end
  end
  d.signups:SetItems(rows, true)
end

function Tab:OnShow()
  if self.form then self.form:Hide() end
end

-- Pastille orange de l'onglet : les sorties qui attendent ma réponse.
function Tab:Badge()
  if not DR.Store:IsReady() then return 0 end
  local n = #Cal:AwaitingAnswer()
  return n, n == 1 and "1 sortie attend ta réponse." or (n .. " sorties attendent ta réponse.")
end
