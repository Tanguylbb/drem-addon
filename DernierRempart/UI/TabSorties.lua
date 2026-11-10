-- Onglet Sorties : la liste des sorties à gauche, le détail à droite avec
-- l'inscription en un clic, comme la page « Les sorties » du site.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Cal = DR.Calendar

local Tab = {}
UI:RegisterTab("sorties", "Sorties", Tab)

local LIST_W = 316
local GROUP_LABEL = { yes = "Présents", maybe = "Peut-être", bench = "Remplaçants", no = "Absents" }
local NEED_LABEL = { T = "Tanks voulus", H = "Soins voulus", D = "DPS voulus" }
local ROW_H = 62

local function kindColor(k)
  local def = Cal.KINDS[k or "raid"] or Cal.KINDS.autre
  return { Util.Hex(def.color) }
end

local function statusColor(s)
  local def = Cal.STATUSES[s]
  return def and { Util.Hex(def.color) } or C.muted
end


---------------------------------------------------------------------------
-- Ligne de sortie (liste de gauche)
---------------------------------------------------------------------------
local function createRow(row)
  row.bg = T.Fill(row, C.panel)
  row.border = T.Border(row, C.line)
  row.accent = row:CreateTexture(nil, "ARTWORK")
  row.accent:SetPoint("TOPLEFT"); row.accent:SetPoint("BOTTOMLEFT")
  row.accent:SetWidth(3)

  local date = CreateFrame("Frame", nil, row)
  date:SetSize(50, ROW_H - 12)
  date:SetPoint("LEFT", 10, 0)
  T.Fill(date, C.sunk)
  T.Border(date, C.line)
  row.day = T.Text(date, "caps", 10, C.muted)
  row.day:SetPoint("TOP", 0, -5)
  row.num = T.Text(date, "title", 21, C.goldText)
  row.num:SetPoint("CENTER", 0, -1)
  row.month = T.Text(date, "body", 9, C.muted)
  row.month:SetPoint("BOTTOM", 0, 4)

  row.kind = T.Text(row, "caps", 11)
  row.kind:SetPoint("TOPLEFT", date, "TOPRIGHT", 10, -1)
  row.mine = T.Text(row, "semi", 11)
  row.mine:SetPoint("TOPRIGHT", -10, -7)
  row.mine:SetJustifyH("RIGHT")
  row.title = T.Text(row, "title", 15, C.ivory)
  row.title:SetPoint("LEFT", date, "RIGHT", 10, 1)
  row.title:SetPoint("RIGHT", -10, 0)
  row.counts = T.Text(row, "body", 11, C.brume)
  row.counts:SetPoint("BOTTOMLEFT", date, "BOTTOMRIGHT", 10, 1)
  row.counts:SetPoint("RIGHT", -10, 0)
end

local function roleCount(role, have, need)
  local c = (need > 0 and have >= need) and C.teal or (need > 0 and C.amber or C.brume)
  local txt = T.RoleIcon(role, 11, c) .. " " .. T.Hex(c) .. have .. "|r"
  if need > 0 then txt = txt .. T.Hex(C.muted) .. "/" .. need .. "|r" end
  return txt
end

local function updateRow(row, ev)
  local p = Util.DateParts(ev.d)
  local kc = kindColor(ev.k)
  row.accent:SetColorTexture(kc[1], kc[2], kc[3], 1)
  row.day:SetText((p.jour:upper():gsub("%.", "")))
  row.num:SetText(p.num)
  row.month:SetText(p.mois)
  row.kind:SetText(T.Hex(kc) .. (Cal.KINDS[ev.k] or Cal.KINDS.autre).label:upper() .. "|r  "
    .. T.Hex(C.brume) .. p.heure .. "|r")
  local cancelled = ev.st == "cancelled"
  row.title:SetText(cancelled and (T.Hex(C.muted) .. ev.t .. "|r") or ev.t)
  local counts = Cal:Counts(ev.id)
  local cap = ev.cap and ("/" .. ev.cap) or ""
  row.counts:SetText(T.Hex(C.ivory) .. counts.yes .. "|r" .. T.Hex(C.muted) .. cap .. "|r   "
    .. roleCount("T", counts.T, ev.nt or 0) .. "  " .. roleCount("H", counts.H, ev.nh or 0) .. "  "
    .. roleCount("D", counts.D, ev.nd or 0))
  local mine = Cal:MySignup(ev.id)
  if cancelled then
    row.mine:SetText(T.Hex(C.red) .. "Annulée|r")
  elseif mine then
    local sc = statusColor(mine.s)
    row.mine:SetText(T.Hex(sc) .. Cal.STATUSES[mine.s].label .. "|r")
  elseif not Cal:IsOpen(ev) then
    row.mine:SetText(T.Hex(C.amber) .. "Fermé|r")
  else
    row.mine:SetText(T.Hex(C.amber) .. "Tu viens ?|r")
  end
  local selected = Tab.selected == ev.id
  if selected then
    row.bg:SetColorTexture(0.09, 0.125, 0.25, 1)
    T.Border(row, C.gold, 0.8)
  else
    row.bg:SetColorTexture(C.panel[1], C.panel[2], C.panel[3], 1)
    T.Border(row, C.line)
  end
  row:SetAlpha(cancelled and 0.6 or 1)
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function Tab:Create(f, width, height)
  self.f, self.width, self.height = f, width, height
  self.view = "upcoming"

  self.chips = W.Chips(f, {
    { key = "upcoming", label = "À venir" },
    { key = "past", label = "Passées" },
  }, function(key, user)
    self.view = key
    if user then self.selected = nil; self:Refresh() end
  end)
  self.chips:SetPoint("TOPLEFT", 0, -2)
  self.chips:Select("upcoming")

  self.alert = T.Text(f, "semi", 12, C.amber)
  self.alert:SetPoint("LEFT", self.chips, "LEFT", 210, 0)

  self.newBtn = W.Button(f, "Nouvelle sortie", "gold", 150, 30)
  self.newBtn:SetPoint("TOPRIGHT", 0, 0)
  self.newBtn:SetScript("OnClick", function() self:OpenForm(nil) end)

  local listH = height - 42
  self.list = W.List(f, {
    width = LIST_W, height = listH, rowHeight = ROW_H + 6,
    create = function(row)
      local inner = CreateFrame("Frame", nil, row)
      inner:SetPoint("TOPLEFT", 0, 0)
      inner:SetPoint("BOTTOMRIGHT", 0, 6)
      createRow(inner)
      row.inner = inner
    end,
    update = function(row, ev) updateRow(row.inner, ev) end,
    click = function(ev) self.selected = ev.id; self:Refresh() end,
  })
  self.list:SetPoint("TOPLEFT", 0, -42)

  local dw = width - LIST_W - 14
  self.detail = T.Card(f)
  self.detail:SetPoint("TOPLEFT", LIST_W + 14, -42)
  self.detail:SetSize(dw, listH)
  self:BuildDetail(self.detail, dw, listH)
  self:BuildForm(f, dw, listH)
end

function Tab:BuildDetail(d, w, h)
  local pad = 16
  d.empty = T.Para(d, "body", 13, C.brume, w - 2 * pad)
  d.empty:SetPoint("TOPLEFT", pad, -pad)

  local body = CreateFrame("Frame", nil, d)
  body:SetAllPoints(d)
  d.body = body

  d.kind = T.Text(body, "caps", 12)
  d.kind:SetPoint("TOPLEFT", pad, -pad)
  d.badge = W.Badge(body)
  d.badge:SetPoint("LEFT", d.kind, "RIGHT", 10, 0)
  d.when = T.Text(body, "body", 12, C.brume)
  d.when:SetPoint("LEFT", d.badge, "RIGHT", 10, 0)

  d.title = T.Text(body, "title", 26, C.ivory)
  d.title:SetPoint("TOPLEFT", d.kind, "BOTTOMLEFT", 0, -8)
  d.title:SetPoint("RIGHT", -pad, 0)
  d.date = T.Text(body, "body", 13, C.brume)
  d.date:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -6)
  d.info = T.Para(body, "body", 12, C.ivory, w - 2 * pad)
  d.info:SetPoint("TOPLEFT", d.date, "BOTTOMLEFT", 0, -6)
  d.info:SetMaxLines(3)

  -- Actions des officiers.
  d.editBtn = W.Button(body, "Modifier", "ghost", 84, 24)
  d.editBtn:SetPoint("TOPRIGHT", -pad, -pad + 4)
  d.editBtn:SetScript("OnClick", function() self:OpenForm(Cal:Get(self.selected)) end)
  d.lockBtn = W.Button(body, "Fermer", "ghost", 84, 24)
  d.lockBtn:SetPoint("RIGHT", d.editBtn, "LEFT", -6, 0)
  d.lockBtn:SetScript("OnClick", function()
    local ev = Cal:Get(self.selected)
    if not ev then return end
    Cal:SetStatus(ev.id, ev.st == "closed" and "open" or "closed")
    UI:Toast(ev.st == "closed" and "Inscriptions rouvertes." or "Inscriptions fermées.", "ok")
  end)
  W.Tip(d.lockBtn, "Fermer ou rouvrir les inscriptions")

  -- Besoins par rôle.
  d.needs = {}
  local prev
  for i, role in ipairs(Util.ROLES) do
    local n = W.RoleNeed(body)
    if i == 1 then n:SetPoint("TOPLEFT", d.info, "BOTTOMLEFT", 0, -12)
    else n:SetPoint("LEFT", prev, "RIGHT", 8, 0) end
    d.needs[role] = n
    prev = n
  end
  d.missing = T.Text(body, "semi", 12, C.amber)
  d.missing:SetPoint("LEFT", prev, "RIGHT", 12, 0)

  -- Ma réponse.
  local box = CreateFrame("Frame", nil, body)
  box:SetPoint("TOPLEFT", d.needs.T, "BOTTOMLEFT", 0, -12)
  box:SetPoint("RIGHT", -pad, 0)
  box:SetHeight(82)
  T.Fill(box, C.sunk)
  T.Border(box, C.gold, 0.35)
  d.box = box

  d.charBtn = W.Button(box, "Perso", "ghost", 190, 26)
  d.charBtn:SetPoint("TOPLEFT", 10, -10)
  d.charBtn:SetScript("OnClick", function(btn) self:OpenCharMenu(btn) end)

  d.roleBtns = {}
  local last = d.charBtn
  for _, role in ipairs(Util.ROLES) do
    local b = W.Button(box, "", "toggle", 34, 26)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(T.Icon(T.ROLE_ICON[role]))
    b:SetPoint("LEFT", last, "RIGHT", 6, 0)
    b:SetScript("OnClick", function()
      self.role = role
      self:RefreshAnswer()
    end)
    W.Tip(b, Util.ROLE_LABEL[role])
    d.roleBtns[role] = b
    last = b
  end

  d.note = W.Edit(box, 100, 26, "Petit mot facultatif (60 caractères)", 60)
  d.note:SetPoint("LEFT", last, "RIGHT", 8, 0)
  d.note:SetPoint("RIGHT", box, "RIGHT", -10, 0)
  d.note:SetScript("OnEnterPressed", function(e)
    e:ClearFocus()
    local mine = Cal:MySignup(self.selected)
    if mine then self:Answer(mine.s) end
  end)

  d.answers = {}
  local x = 10
  local bw = math.floor((w - 2 * pad - 20 - 18) / 4)
  for _, s in ipairs(Cal.STATUS_ORDER) do
    local b = W.Button(box, Cal.STATUSES[s].label, "toggle", bw, 30)
    b:SetPoint("BOTTOMLEFT", x, 10)
    b:SetScript("OnClick", function() self:Answer(s) end)
    d.answers[s] = b
    x = x + bw + 6
  end

  d.state = T.Text(body, "body", 11, C.muted)
  d.state:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -6)
  d.state:SetPoint("RIGHT", -pad, 0)

  -- Inscrits.
  local listTop = 16 + 20 + 34 + 22 + 40 + 36 + 12 + 82 + 26
  d.signups = W.List(body, {
    width = w - 2 * pad, height = math.max(60, h - listTop - pad), rowHeight = 19,
    create = function(row)
      row.text = T.Text(row, "body", 12)
      row.text:SetPoint("LEFT", 2, 0)
      row.text:SetPoint("RIGHT", -2, 0)
    end,
    update = function(row, item) row.text:SetText(item.text) end,
  })
  d.signups:SetPoint("TOPLEFT", d.state, "BOTTOMLEFT", -2, -6)
  d.signups:SetEmptyText("Personne n'est encore inscrit. Sois le premier !")
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
  form:SetPoint("TOPLEFT", LIST_W + 14, -42)
  form:SetSize(w, h)
  form:SetFrameLevel(self.detail:GetFrameLevel() + 10)
  form:EnableMouse(true)
  form:Hide()
  self.form = form
  local pad = 16

  form.heading = T.Text(form, "title", 22, C.goldText)
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

  form.save = W.Button(form, "Enregistrer", "gold", 150, 32)
  form.save:SetPoint("BOTTOMLEFT", pad, pad)
  form.save:SetScript("OnClick", function() self:SaveForm() end)
  form.cancel = W.Button(form, "Annuler", "slate", 110, 32)
  form.cancel:SetPoint("LEFT", form.save, "RIGHT", 10, 0)
  form.cancel:SetScript("OnClick", function() form:Hide() end)
  form.cancelEvent = W.Button(form, "Annuler la sortie", "danger", 150, 28)
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

function Tab:Answer(status)
  local ev = Cal:Get(self.selected)
  if not ev then return end
  local ok, err = Cal:SetSignup(ev.id, self.char or DR.playerName, status, self.role, self.detail.note:GetText())
  if ok then
    UI:Toast("Enregistré : " .. Cal.STATUSES[status].label .. ". Ça part à la guilde, puis au site.", "ok")
  else
    UI:Toast(err, "warn")
  end
  self:Refresh()
end

function Tab:RefreshAnswer()
  local d = self.detail
  local ev = Cal:Get(self.selected)
  if not ev then return end
  local mine = Cal:MySignup(ev.id)
  local char = DR.db.myChars[self.char or ""] or DR.Store:Get("chars", self.char or "") or {}
  d.charBtn:SetLabel("Perso : " .. Util.ClassName(self.char or DR.playerName, char.cl)
    .. T.Hex(C.muted) .. " (" .. (char.lv or "?") .. ")|r")
  for role, b in pairs(d.roleBtns) do
    local on = self.role == role
    b:SetActive(on)
    local c = on and { 1, 1, 1 } or C.brume
    b.icon:SetVertexColor(c[1], c[2], c[3])
  end
  for s, b in pairs(d.answers) do b:SetActive(mine and mine.s == s) end
  local open = Cal:IsOpen(ev) or DR.Guild:IAmOfficer()
  for _, b in pairs(d.answers) do b:SetEnabled(open) end
  if not open then
    d.state:SetText(T.Hex(C.amber) .. "Inscriptions fermées.|r")
  elseif mine then
    d.state:SetText(T.Hex(C.teal) .. "Ta réponse : " .. Cal.STATUSES[mine.s].label .. "|r" .. T.Hex(C.muted)
      .. " · avec " .. Util.ShortName(mine.c) .. " · " .. Util.Ago(mine.u)
      .. ". Partagée avec la guilde ; les officiers la passent au site.|r")
  else
    d.state:SetText(T.Hex(C.amber) .. "Tu viens ? Réponds en un clic.|r")
  end
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
  local awaiting = ready and #Cal:AwaitingAnswer() or 0
  if awaiting > 0 then
    self.alert:SetText(awaiting == 1 and "1 sortie attend ta réponse." or (awaiting .. " sorties attendent ta réponse."))
  else
    self.alert:SetText("")
  end
  self.newBtn:SetShown(DR.Guild:IAmOfficer())

  local items = self.view == "past" and past or upcoming
  if not self.selected or not Cal:Get(self.selected) then
    self.selected = items[1] and items[1].id or nil
  end
  if not ready then
    self.list:SetEmptyText(IsInGuild() and "Chargement de la guilde…" or "Rejoins la guilde pour voir ses sorties.")
  elseif self.view == "past" then
    self.list:SetEmptyText("Aucune sortie passée ces 60 derniers jours.")
  else
    self.list:SetEmptyText("Aucune sortie prévue pour l'instant. Les officiers les créent sur le site ou ici, puis elles arrivent toutes seules.")
  end
  self.list:SetItems(items, true)
  self:RefreshDetail()
end

function Tab:RefreshDetail()
  local d = self.detail
  local ev = self.selected and Cal:Get(self.selected)
  if not ev then
    d.body:Hide()
    d.empty:Show()
    d.empty:SetText("Choisis une sortie dans la liste pour voir qui vient et t'inscrire.")
    return
  end
  d.empty:Hide()
  d.body:Show()
  local kc = kindColor(ev.k)
  d.kind:SetText(T.Hex(kc) .. (Cal.KINDS[ev.k] or Cal.KINDS.autre).label:upper() .. "|r")
  if ev.st == "cancelled" then d.badge:Set("Annulée", C.red); d.badge:Show()
  elseif not Cal:IsOpen(ev) then d.badge:Set("Inscriptions fermées", C.amber); d.badge:Show()
  elseif ev.src == "site" then d.badge:Set("Du site", C.teal); d.badge:Show()
  else d.badge:Hide() end
  d.when:SetText(Util.Until(ev.d))
  d.title:SetText(ev.t)
  local dur = ev.dur and ev.dur > 0 and (" · " .. (Util.Duration(ev.dur * 60) or "")) or ""
  local cap = ev.cap and (" · " .. ev.cap .. " joueurs") or ""
  local p = Util.DateParts(ev.d)
  d.date:SetText(p.jourLong .. " " .. p.num .. " " .. p.moisLong .. " à " .. p.heure .. dur .. cap)
  local info = {}
  if ev.lead then info[#info + 1] = T.Hex(C.muted) .. "Chef de raid :|r " .. ev.lead end
  if ev.rdv then info[#info + 1] = T.Hex(C.muted) .. "Rendez-vous :|r " .. ev.rdv end
  local line = table.concat(info, "   ")
  if ev.note then line = line .. (line ~= "" and "\n" or "") .. T.Hex(C.muted) .. "Note :|r " .. ev.note end
  d.info:SetText(line)

  local counts = Cal:Counts(ev.id)
  local needs = { T = ev.nt or 0, H = ev.nh or 0, D = ev.nd or 0 }
  for role, n in pairs(d.needs) do
    n:SetShown(needs[role] > 0)
    n:Set(role, counts[role], needs[role])
  end
  d.missing:SetText(Cal:MissingText(ev, counts) or (needs.T + needs.H + needs.D > 0 and (T.Hex(C.teal) .. "Compo complète|r") or ""))

  local officer = DR.Guild:IAmOfficer()
  d.editBtn:SetShown(officer)
  d.lockBtn:SetShown(officer and ev.st ~= "cancelled")
  d.lockBtn:SetLabel(ev.st == "closed" and "Rouvrir" or "Fermer")

  -- Perso et rôle proposés : ceux de mon inscription, sinon le perso connecté.
  if self.answerFor ~= ev.id then
    self.answerFor = ev.id
    local mine = Cal:MySignup(ev.id)
    self.char = mine and mine.c or DR.playerName
    self.role = (mine and mine.r) or DR.Profile:PreferredRole(self.char) or "D"
    d.note:SetText(mine and mine.m or "")
  end
  self:RefreshAnswer()

  -- Liste des inscrits par réponse.
  local rows, groups = {}, {}
  for _, s in ipairs(Cal:Signups(ev.id)) do
    groups[s.s] = groups[s.s] or {}
    table.insert(groups[s.s], s)
  end
  for _, st in ipairs(Cal.STATUS_ORDER) do
    local g = groups[st]
    if g and #g > 0 then
      local sc = statusColor(st)
      rows[#rows + 1] = { text = T.Hex(sc) .. GROUP_LABEL[st] .. " (" .. #g .. ")|r" }
      for _, s in ipairs(g) do
        local txt = "   " .. T.RoleIcon(s.r, 12, C.brume) .. "  " .. Util.ClassName(s.c, s.cl or DR.Profile:ClassOf(s.c))
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
