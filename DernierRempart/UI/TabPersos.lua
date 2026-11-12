-- Onglet Mes persos : les persos du compte, lus tout seuls dans le jeu, et les
-- métiers qu'il reste à ouvrir pour partager leurs recettes.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C

local Tab = {}
UI:RegisterTab("persos", "Mes persos", Tab)

local MAX_PROFS = 5
local PROF_H = 32

function Tab:Create(f, width, height)
  self.f, self.width = f, width
  local intro = T.Para(f, "body", 12, C.brume, width - 200)
  intro:SetPoint("TOPLEFT", 0, -2)
  intro:SetText("Ta fiche est lue toute seule et partagée avec la guilde. Les recettes demandent un geste de ta part : le jeu ne laisse pas l'add-on ouvrir tes métiers à ta place.")
  local rescan = W.Button(f, "Relire ma fiche", "slate", 170, 28)
  rescan:SetPoint("TOPRIGHT", 0, 0)
  rescan:SetScript("OnClick", function()
    DR.Profile:Scan("manuel")
    UI:Toast("Fiche relue. Les recettes, elles, se lisent quand tu ouvres un métier.", "ok")
  end)
  W.Tip(rescan, "Relire ma fiche",
    "Relit la classe, le niveau, la spé, le rôle et la liste des métiers. Les recettes d'un métier ne se lisent que quand tu ouvres sa fenêtre.")

  -- Le perso connecté.
  local card = T.Card(f)
  card:SetPoint("TOPLEFT", 0, -48)
  card:SetSize(width, 66 + 36 + MAX_PROFS * PROF_H)
  self.card = card
  self.name = T.Text(card, "title", 20, C.ivory)
  self.name:SetPoint("TOPLEFT", 16, -12)
  self.info = T.Text(card, "body", 12, C.muted)
  self.info:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -5)
  self.shared = W.Badge(card)
  self.shared:SetPoint("TOPRIGHT", -16, -22)

  local head = CreateFrame("Frame", nil, card)
  head:SetPoint("TOPLEFT", 1, -66)
  head:SetPoint("TOPRIGHT", -1, -66)
  head:SetHeight(36)
  T.Fill(head, { 0.06, 0.105, 0.19 })
  local hrule = T.Line(head, C.line, 1)
  hrule:SetPoint("TOPLEFT"); hrule:SetPoint("TOPRIGHT")
  local hl = T.Text(head, "caps", 11, C.muted)
  hl:SetPoint("LEFT", 15, 0)
  hl:SetText("MES MÉTIERS À LIRE")
  self.progress = T.Text(head, "body", 12, C.brume)
  self.progress:SetPoint("RIGHT", -170, 0)
  self.bar = W.Bar(head, 140, 6)
  self.bar:SetPoint("RIGHT", -16, 0)

  self.rows = {}
  for i = 1, MAX_PROFS do
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", 1, -(102 + (i - 1) * PROF_H))
    row:SetPoint("TOPRIGHT", -1, -(102 + (i - 1) * PROF_H))
    row:SetHeight(PROF_H)
    local rule = T.Line(row, C.line, 1)
    rule:SetPoint("TOPLEFT"); rule:SetPoint("TOPRIGHT")
    row.dot = W.Dot(row, 8)
    row.dot:SetPoint("LEFT", 16, 0)
    row.name = T.Text(row, "semi", 13, C.ivory)
    row.name:SetPoint("LEFT", 34, 0)
    row.name:SetWidth(116)
    row.level = T.Text(row, "body", 12, C.muted)
    row.level:SetPoint("LEFT", 156, 0)
    row.level:SetWidth(76)
    row.badge = W.Badge(row)
    row.badge:SetPoint("LEFT", 238, 0)
    row.detail = T.Text(row, "body", 12, C.muted)
    row.detail:SetPoint("LEFT", 312, 0)
    row.detail:SetPoint("RIGHT", -16, 0)
    self.rows[i] = row
  end
  self.empty = T.Para(card, "body", 12, C.muted, width - 40)
  self.empty:SetPoint("TOPLEFT", 16, -118)

  -- Rôle préféré.
  local rolePanel = T.Card(f)
  rolePanel:SetPoint("TOPLEFT", 0, -48 - (66 + 36 + MAX_PROFS * PROF_H) - 10)
  rolePanel:SetSize(width, 44)
  local rl = T.Text(rolePanel, "caps", 11, C.muted)
  rl:SetPoint("LEFT", 16, 0)
  rl:SetText("RÔLE PRÉFÉRÉ POUR LES SORTIES")
  local roles = {}
  for _, role in ipairs(Util.ROLES) do roles[#roles + 1] = { key = role, label = Util.ROLE_LABEL[role] } end
  self.roleChips = W.Chips(rolePanel, roles, function(key, user)
    if user then
      DR.Profile:SetPreferredRole(key)
      self:Refresh()
    end
  end)
  self.roleChips:SetPoint("RIGHT", -14, 0)

  -- Les autres persos du compte.
  local top = 48 + (66 + 36 + MAX_PROFS * PROF_H) + 10 + 44 + 10
  self.others = W.List(f, {
    width = width, height = math.max(44, height - top), rowHeight = 44,
    create = function(row)
      local c = T.Card(row)
      c:SetPoint("TOPLEFT", 0, 0)
      c:SetPoint("BOTTOMRIGHT", -8, 4)
      row.name = T.Text(c, "semi", 13, C.ivory)
      row.name:SetPoint("LEFT", 14, 0)
      row.name:SetWidth(190)
      row.info = T.Text(c, "body", 11, C.muted)
      row.info:SetPoint("LEFT", 210, 0)
      row.info:SetPoint("RIGHT", -12, 0)
    end,
    update = function(row, c) self:UpdateOther(row, c) end,
  })
  self.others:SetPoint("TOPLEFT", 0, -top)
end

local function sharedState(c)
  if not c.g then return "Hors guilde", C.muted end
  if c.g ~= DR.Guild.name then return "Autre guilde", C.muted end
  if DR.Store:Get("chars", c.n) then return "Fiche partagée", C.teal end
  return "Pas encore partagée", C.amber
end

local function professionSummary(name)
  local parts = {}
  for _, s in ipairs(DR.Profile:ProfessionStates(name)) do
    if s.needs then
      parts[#parts + 1] = s.name .. " " .. (s.read and (T.Hex(C.teal) .. "lu|r") or (T.Hex(C.amber) .. "à ouvrir|r"))
    end
  end
  return #parts > 0 and table.concat(parts, "  ·  ") or "Pas de métier lu pour l'instant."
end

function Tab:UpdateOther(row, c)
  row.name:SetText(Util.ClassName(c.n, c.cl) .. T.Hex(C.muted) .. "  " .. (c.lv or "?") .. "|r")
  row.info:SetText(professionSummary(c.n))
end

function Tab:Refresh()
  if not self.f then return end
  local me = DR.db.myChars[DR.playerName]
  local role = DR.Profile:PreferredRole(DR.playerName)
  self.roleChips:Select(role or "", false)
  for _, row in ipairs(self.rows) do row:Hide() end
  if not me then
    self.name:SetText("Perso pas encore lu")
    self.info:SetText("")
    self.shared:Hide()
    self.progress:SetText("")
    self.bar:Set(0)
    self.empty:SetText("La fiche de ce perso se lit quelques secondes après la connexion.")
    self.empty:Show()
  else
    self.empty:Hide()
    self.name:SetText(Util.ClassName(me.n, me.cl))
    local parts = { "niveau " .. (me.lv or "?") }
    if me.sp or me.r then
      parts[#parts + 1] = (me.r and T.RoleIcon(me.r, 11, C.teal) .. " " or "") .. (me.sp or Util.ROLE_LABEL[me.r] or "")
    end
    parts[#parts + 1] = me.g or "sans guilde"
    self.info:SetText(table.concat(parts, " · "))
    local text, color = sharedState(me)
    self.shared:Show()
    self.shared:Set(text, color)

    local states = DR.Profile:ProfessionStates(DR.playerName)
    local need, read = 0, 0
    for i, s in ipairs(states) do
      if s.needs then
        need = need + 1
        if s.read then read = read + 1 end
      end
      local row = self.rows[i]
      if row then
        row:Show()
        local dot = (not s.needs) and C.muted or (s.read and C.green or C.amber)
        row.dot:SetColorTexture(dot[1], dot[2], dot[3], 1)
        row.name:SetText(s.name)
        row.level:SetText((s.lv or "?") .. " / " .. (s.mx or "?"))
        if not s.needs then
          row.badge:Set("Rien à lire", C.muted)
          row.detail:SetText("Ce métier n'a pas de recettes à partager.")
          T.Color(row.detail, C.muted)
        elseif s.read then
          row.badge:Set("Lu", C.teal)
          local what = (s.n or 0) .. " recette" .. ((s.n or 0) > 1 and "s" or "")
          row.detail:SetText(what .. (s.at and (" · " .. Util.Ago(s.at)) or ""))
          T.Color(row.detail, C.muted)
        else
          row.badge:Set("À ouvrir", C.amber)
          row.detail:SetText("Ouvre ta fenêtre " .. s.name .. " une fois : ses recettes sont lues et partagées.")
          T.Color(row.detail, C.amber)
        end
      end
    end
    if #states == 0 then
      self.empty:SetText("Aucun métier lu pour l'instant.")
      self.empty:Show()
    end
    self.progress:SetText(need > 0 and (read .. " sur " .. need) or "rien à lire")
    self.bar:Set(need > 0 and read / need or 1, read == need and C.teal or C.teal)
  end

  local others = {}
  for _, c in ipairs(DR.Profile:MyChars()) do
    if c.n ~= DR.playerName then others[#others + 1] = c end
  end
  self.others:SetEmptyText(nil)
  self.others:SetItems(others, true)
end
