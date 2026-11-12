-- Onglet Artisans : qui sait fabriquer quoi, recettes que la guilde cherche,
-- commandes de fabrication.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Crafts = DR.Crafts

local Tab = {}
UI:RegisterTab("artisans", "Artisans", Tab)

local LIST_W = 500

local function hexColor(h) return { Util.Hex(h) } end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function Tab:Create(f, width, height)
  self.f, self.width, self.height = f, width, height
  self.view, self.mode, self.prof = "qui", "known", nil
  self.orderFilter = "forme"

  self.chips = W.Chips(f, {
    { key = "qui", label = "Qui sait faire quoi" },
    { key = "recherches", label = "Recettes recherchées" },
    { key = "commandes", label = "Commandes" },
  }, function(key, user)
    self.view = key
    if user then self:Refresh() end
  end)
  self.chips:SetPoint("TOPLEFT", 0, -2)
  self.chips:Select("qui")
  -- Combien de recettes dans le catalogue du métier, lu par combien de membres.
  self.catalogBadge = W.Badge(f)
  self.catalogBadge:SetPoint("TOPRIGHT", 0, -4)

  self.pages = {}
  local top = -42
  for _, key in ipairs({ "qui", "recherches", "commandes" }) do
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 0, top)
    p:SetSize(width, height + top)
    self.pages[key] = p
  end
  self:BuildQui(self.pages.qui, width, height + top)
  self:BuildWishes(self.pages.recherches, width, height + top)
  self:BuildOrders(self.pages.commandes, width, height + top)
end

---------------------------------------------------------------------------
-- Qui sait faire quoi : toute la liste du métier, rangée par type de craft
---------------------------------------------------------------------------
local FILTERS = {
  { key = "all", label = "Tout" },
  { key = "lacking", label = "Il me manque" },
  { key = "nobody", label = "Personne ne l'a" },
}

function Tab:BuildQui(p, width, height)
  self.filter = "all"
  self.collapsed = {}
  local search = W.Edit(p, 210, 28, "Chercher une recette…", 60)
  search:SetPoint("TOPLEFT", 0, 0)
  search:SetTextInsets(26, 8, 0, 0)
  search.placeholder:SetPoint("LEFT", 26, 0)
  local icon = search:CreateTexture(nil, "OVERLAY")
  icon:SetSize(14, 14)
  icon:SetPoint("LEFT", 7, 0)
  icon:SetTexture(T.Icon("search"))
  icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
  search:HookScript("OnTextChanged", function() self:RefreshQui() end)
  self.search = search

  self.profBtn = W.Button(p, "Métier", "ghost", 190, 28)
  self.profBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
  self.profBtn:SetScript("OnClick", function(btn)
    local items = { { text = "Tous les métiers", checked = self.allProfs, func = function()
      self.allProfs, self.prof, self.selectedRecipe = true, nil, nil
      self:RefreshQui()
    end } }
    for _, pr in ipairs(Crafts:Professions()) do
      items[#items + 1] = { text = pr.name, checked = not self.allProfs and self.prof == pr.id, func = function()
        self.allProfs, self.prof, self.selectedRecipe = false, pr.id, nil
        self:RefreshQui()
      end }
    end
    W.OpenMenu(btn, items, 220)
  end)
  W.Tip(self.profBtn, "Métier", "Tous les métiers de la guilde, même ceux que tu n'as pas : tu vois leurs recettes et qui sait les faire.")

  self.modeChips = W.Chips(p, FILTERS, function(key, user)
    self.filter = key
    if user then self.selectedRecipe = nil; self:RefreshQui() end
  end)
  self.modeChips:SetPoint("LEFT", self.profBtn, "RIGHT", 10, 0)
  self.modeChips:Select("all")
  W.Tip(self.modeChips.buttons.lacking, "Il me manque",
    "Les recettes du métier qu'aucun de tes persos n'a apprises.")
  W.Tip(self.modeChips.buttons.nobody, "Personne ne l'a",
    "Recettes vues dans la fenêtre de métier d'un artisan de la guilde, que personne ne connaît encore. Fais +1 pour dire que tu voudrais que la guilde l'achète.")

  local listH = height - 40
  self.recipes = W.List(p, {
    width = LIST_W, height = listH, rowHeight = 30,
    create = function(row)
      -- Un type de craft (dossier qu'on ouvre et ferme).
      local cat = CreateFrame("Frame", nil, row)
      cat:SetAllPoints()
      T.Fill(cat, { 0.06, 0.105, 0.19 })
      row.catSign = T.Text(cat, "bold", 14, C.goldText)
      row.catSign:SetPoint("LEFT", 12, 0)
      row.catName = T.Text(cat, "semi", 13, C.goldText)
      row.catName:SetPoint("LEFT", 30, 0)
      row.catName:SetPoint("RIGHT", -120, 0)
      row.catBadge = W.Badge(cat)
      row.catBadge:SetPoint("RIGHT", -10, 0)
      row.cat = cat
      -- Une recette.
      local rec = CreateFrame("Frame", nil, row)
      rec:SetAllPoints()
      row.sel = rec:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 1, 1, 0.07)
      row.icon = rec:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(22, 22)
      row.icon:SetPoint("LEFT", 26, 0)
      row.name = T.Text(rec, "semi", 12, C.ivory)
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
      row.name:SetPoint("RIGHT", -150, 0)
      row.badge = W.Badge(rec)
      row.badge:SetPoint("RIGHT", -74, 0)
      row.plus = W.Button(rec, "", "toggle", 62, 22)
      row.plus:SetPoint("RIGHT", -8, 0)
      row.rec = rec
      row:SetScript("OnEnter", function(r)
        if r.item and r.item.kind == "rec" then Crafts:ShowTooltip(r, r.item.e.id) end
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    update = function(row, item) self:UpdateRecipeRow(row, item) end,
    click = function(item)
      if item.kind == "cat" then
        self.collapsed[item.g.name] = item.open or nil
      else
        self.selectedRecipe, self.selectedCrafter = item.e.id, nil
      end
      self:RefreshQui()
    end,
  })
  self.recipes:SetPoint("TOPLEFT", 0, -40)

  local dw = width - LIST_W - 14
  local d = T.Card(p)
  d:SetPoint("TOPLEFT", LIST_W + 14, -40)
  d:SetSize(dw, listH)
  self.quiDetail = d
  local pad = 16
  d.empty = T.Para(d, "body", 13, C.brume, dw - 2 * pad)
  d.empty:SetPoint("TOPLEFT", pad, -pad)
  local body = CreateFrame("Frame", nil, d)
  body:SetAllPoints()
  d.body = body
  d.icon = body:CreateTexture(nil, "ARTWORK")
  d.icon:SetSize(36, 36)
  d.icon:SetPoint("TOPLEFT", pad, -pad)
  d.name = T.Para(body, "title", 19, C.goldText, dw - 2 * pad - 46)
  d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, 0)
  d.name:SetMaxLines(2)
  d.prof = T.Text(body, "caps", 11, C.brume)
  d.prof:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -8)
  d.prof:SetPoint("RIGHT", -pad, 0)
  d.badges = W.Badge(body)
  d.badges:SetPoint("TOPLEFT", d.prof, "BOTTOMLEFT", 0, -8)
  d.status = W.Badge(body)
  d.status:SetPoint("LEFT", d.badges, "RIGHT", 6, 0)

  -- Quelqu'un sait la faire : les artisans, et la demande.
  local known = CreateFrame("Frame", nil, body)
  known:SetPoint("TOPLEFT", d.badges, "BOTTOMLEFT", 0, -10)
  known:SetPoint("BOTTOMRIGHT", 0, 0)
  d.known = known
  d.sub = T.Text(known, "semi", 12, C.goldPale)
  d.sub:SetPoint("TOPLEFT", 0, 0)
  d.crafters = W.List(known, {
    width = dw - 2 * pad, height = listH - 244, rowHeight = 22,
    create = function(row)
      row.dot = W.Dot(row, 7)
      row.dot:SetPoint("LEFT", 4, 0)
      row.text = T.Text(row, "body", 12)
      row.text:SetPoint("LEFT", row.dot, "RIGHT", 8, 0)
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(C.tealDark[1], C.tealDark[2], C.tealDark[3], 0.35)
    end,
    update = function(row, c)
      local col = c.online and C.teal or C.muted
      row.dot:SetColorTexture(col[1], col[2], col[3], 1)
      local mine = DR.Profile:IsMine(c.name) and (T.Hex(C.goldText) .. "  (toi)|r") or ""
      row.text:SetText(Util.ClassName(c.name, c.class) .. T.Hex(C.muted) .. (c.online and "  en ligne" or "  hors ligne") .. "|r" .. mine)
      row.sel:SetShown(self.selectedCrafter == c.name)
    end,
    click = function(c) self.selectedCrafter = c.name; self:RefreshQui() end,
  })
  d.crafters:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -6)
  d.unshared = T.Text(known, "body", 11, C.amber)
  d.unshared:SetPoint("BOTTOMLEFT", 0, 78)
  d.unshared:SetPoint("RIGHT", -110, 0)
  d.remind = W.Button(known, "Lui rappeler", "ghost", 100, 22)
  d.remind:SetPoint("BOTTOMRIGHT", -pad, 74)
  d.remind:SetScript("OnClick", function()
    if self.remindName then Util.Whisper(self.remindName) end
  end)
  W.Tip(d.remind, "Lui rappeler", "Cette personne a le métier mais n'a pas encore ouvert sa fenêtre de métier avec l'add-on : ses recettes ne sont pas partagées.")
  d.note = W.Edit(known, dw - 2 * pad, 26, "Petit mot pour l'artisan (composants fournis…)", 200)
  d.note:SetPoint("BOTTOMLEFT", 0, 40)
  d.ask = W.Button(known, "Demander", "gold", 190, 32)
  d.ask:SetPoint("BOTTOMLEFT", 0, 0)
  d.ask:SetScript("OnClick", function() self:AskCraft() end)
  d.whisper = W.Button(known, "Chuchoter", "slate", 120, 32)
  d.whisper:SetPoint("LEFT", d.ask, "RIGHT", 8, 0)
  d.whisper:SetScript("OnClick", function()
    if self.selectedCrafter then Util.Whisper(self.selectedCrafter) end
  end)

  -- Personne ne sait la faire : qui la veut, où la trouver, qui pourrait l'apprendre.
  local lost = CreateFrame("Frame", nil, body)
  lost:SetPoint("TOPLEFT", d.badges, "BOTTOMLEFT", 0, -10)
  lost:SetPoint("BOTTOMRIGHT", 0, 0)
  d.lost = lost
  d.wantLabel = T.Text(lost, "caps", 11, C.muted)
  d.wantLabel:SetPoint("TOPLEFT", 0, 0)
  d.wantText = T.Para(lost, "body", 12, C.ivory, dw - 2 * pad - 20)
  d.wantText:SetPoint("TOPLEFT", d.wantLabel, "BOTTOMLEFT", 0, -6)
  d.wantText:SetMaxLines(3)
  d.whereLabel = T.Text(lost, "caps", 11, C.muted)
  d.whereLabel:SetPoint("TOPLEFT", 0, -78)
  d.whereLabel:SetText("OÙ LA TROUVER")
  d.where = W.Edit(lost, dw - 2 * pad, 26, "Vendeur, HV, butin… (après ton +1)", 120)
  d.where:SetPoint("TOPLEFT", d.whereLabel, "BOTTOMLEFT", 0, -6)
  d.where:SetScript("OnEnterPressed", function(e)
    e:ClearFocus()
    local w = self:SelectedWant()
    if w then
      Crafts:SetWhere(w.order.id, e:GetText())
      UI:Toast("Indication enregistrée.", "ok")
    end
  end)
  d.whereBy = T.Text(lost, "body", 11, C.muted)
  d.whereBy:SetPoint("TOPLEFT", d.where, "BOTTOMLEFT", 2, -4)
  d.learnLabel = T.Text(lost, "caps", 11, C.muted)
  d.learnLabel:SetPoint("TOPLEFT", 0, -150)
  d.learnText = T.Para(lost, "body", 12, C.ivory, dw - 2 * pad - 20)
  d.learnText:SetPoint("TOPLEFT", d.learnLabel, "BOTTOMLEFT", 0, -6)
  d.learnText:SetMaxLines(3)
  d.shopping = W.Button(lost, "Liste d'achat", "slate", 130, 32)
  d.shopping:SetPoint("BOTTOMLEFT", 0, 0)
  d.shopping:SetScript("OnClick", function() self.chips:Select("recherches", true) end)
  W.Tip(d.shopping, "Liste d'achat", "L'onglet « Recettes recherchées » : les recettes que la guilde voudrait acheter, les plus demandées en tête.")
  d.want = W.Button(lost, "+1 Je la veux", "gold", 170, 32)
  d.want:SetPoint("BOTTOMRIGHT", -pad, 0)
  d.want:SetScript("OnClick", function()
    local e = self:SelectedEntry()
    if e then self:ToggleWant(e) end
  end)
end

function Tab:UpdateRecipeRow(row, item)
  if item.kind == "cat" then
    row.cat:Show(); row.rec:Hide()
    row.catSign:SetText(item.open and "−" or "+")
    row.catName:SetText(item.g.name .. T.Hex(C.muted) .. "  (" .. item.g.total .. ")|r")
    if item.g.nobody > 0 then
      row.catBadge:Show()
      row.catBadge:Set(item.g.nobody .. " sans artisan", C.amber)
    else
      row.catBadge:Hide()
    end
    return
  end
  local e, want = item.e, item.want
  row.cat:Hide(); row.rec:Show()
  row.icon:SetTexture(Crafts:RecipeIcon(e.id) or 134400)
  row.name:SetText(e.name)
  row.sel:SetShown(self.selectedRecipe == e.id)
  if #e.crafters == 0 then
    row.badge:Set("Personne", C.amber)
    local n = want and want.n or 0
    row.plus:Show()
    row.plus:SetLabel("+1  " .. n)
    row.plus:SetActive(want and want.mine or false)
    row.plus:SetScript("OnClick", function() self:ToggleWant(e) end)
  else
    row.badge:Set(#e.crafters .. " artisan" .. (#e.crafters > 1 and "s" or ""), C.teal)
    row.plus:Hide()
  end
end

function Tab:SelectedEntry()
  if not self.selectedRecipe then return nil end
  for _, e in ipairs(self.quiEntries or {}) do
    if e.id == self.selectedRecipe then return e end
  end
  return nil
end

function Tab:SelectedWant()
  local e = self:SelectedEntry()
  return e and Crafts:WantMap()[e.id] or nil
end

function Tab:ToggleWant(e)
  local order, on, msg = Crafts:ToggleWant(e)
  if not order then
    UI:Toast(msg or "Impossible d'ajouter.", "warn")
  else
    UI:Toast(on and "+1 : la guilde saura que tu voudrais cette recette." or "Ton +1 est retiré.", "ok")
  end
  self:RefreshQui()
end

function Tab:AskCraft()
  local e = self:SelectedEntry()
  if not e or not self.selectedCrafter then
    UI:Toast("Choisis d'abord un artisan dans la liste.", "warn")
    return
  end
  local rec, err = Crafts:RequestCraft(e.id, self.selectedCrafter, self.quiDetail.note:GetText())
  if rec then
    self.quiDetail.note:SetText("")
    UI:Toast("Demande envoyée à " .. Util.ShortName(self.selectedCrafter) .. ". Suis-la dans Commandes.", "ok")
  else
    UI:Toast(err or "Impossible d'envoyer la demande.", "warn")
  end
end

-- Le métier montré d'office : un de mes métiers connus de la guilde, sinon le premier.
function Tab:DefaultProfession()
  local list = Crafts:Professions()
  local mine = {}
  for _, c in ipairs(DR.Profile:MyChars()) do
    for _, pr in ipairs(c.p or {}) do mine[pr.id] = true end
  end
  for _, pr in ipairs(list) do if mine[pr.id] then return pr.id end end
  return list[1] and list[1].id or nil
end

function Tab:RefreshQui()
  if not self.recipes then return end
  local professions = Crafts:Professions()
  local valid = false
  for _, pr in ipairs(professions) do if pr.id == self.prof then valid = true end end
  if not self.allProfs and not valid then self.prof = self:DefaultProfession() end
  if self.prof == nil and #professions > 0 and not self.allProfs then self.allProfs = false end
  local profName = "tous les métiers"
  for _, pr in ipairs(professions) do if pr.id == self.prof and not self.allProfs then profName = pr.name end end
  if self.allProfs then profName = "tous les métiers" end
  self.profBtn:SetLabel("Métier : " .. profName)

  -- Les types de craft, avec leurs recettes.
  local text = self.search:GetText()
  local searching = Util.Trim(text) ~= ""
  local wants = Crafts:WantMap()
  local groups = {}
  if self.allProfs then
    for _, pr in ipairs(professions) do
      for _, g in ipairs(Crafts:Tree(pr.id, self.filter, text)) do
        g.name = pr.name .. " · " .. g.name
        groups[#groups + 1] = g
      end
    end
  elseif self.prof then
    groups = Crafts:Tree(self.prof, self.filter, text)
  end
  local items, entries, nobodyTotal = {}, {}, 0
  for _, g in ipairs(groups) do
    local open = searching or not self.collapsed[g.name]
    items[#items + 1] = { kind = "cat", g = g, open = open }
    for _, e in ipairs(g.entries) do
      entries[#entries + 1] = e
      if #e.crafters == 0 then nobodyTotal = nobodyTotal + 1 end
      if open then items[#items + 1] = { kind = "rec", e = e, want = wants[e.id] } end
    end
  end
  self.quiItems, self.quiEntries = items, entries

  self.modeChips:SetLabel("nobody", "Personne ne l'a" .. (self.filter == "nobody" and ("  " .. nobodyTotal) or ""))
  local anything = #Crafts:Index().list > 0 or #Crafts:Index().missing > 0
  self.recipes:SetEmptyText(not anything
    and "Pas encore de recettes. Chaque artisan n'a qu'à ouvrir sa fenêtre de métier une fois : ses recettes sont lues et partagées toutes seules."
    or (self.filter == "nobody" and "Rien à montrer : la liste se remplit quand un artisan ouvre sa fenêtre de métier avec l'add-on."
      or "Aucune recette ne correspond."))
  self.recipes:SetItems(items, true)

  -- Le catalogue : combien de recettes, lu par combien de membres.
  if self.catalogBadge then
    if self.prof and not self.allProfs then
      local info = Crafts:CatalogInfo(self.prof)
      self.catalogBadge:Set("Catalogue " .. profName .. " : " .. info.recipes .. " recettes · lu par " .. info.readers
        .. " membre" .. (info.readers > 1 and "s" or ""), (info.members > info.readers) and C.amber or C.brume)
    else
      self.catalogBadge:Set("Catalogue : " .. #Crafts:Index().list + #Crafts:Index().missing .. " recettes · " .. #professions .. " métiers", C.brume)
    end
  end

  self:RefreshQuiDetail()
end

function Tab:RefreshQuiDetail()
  local d = self.quiDetail
  local e = self:SelectedEntry()
  if not e then
    d.body:Hide(); d.empty:Show()
    d.empty:SetText("Choisis une recette : tu vois qui sait la faire, qui est en ligne, et tu peux le lui demander en un clic. Une recette que personne n'a se marque d'un +1 : la guilde saura qu'il faut l'acheter.")
    return
  end
  d.empty:Hide(); d.body:Show()
  d.icon:SetTexture(Crafts:RecipeIcon(e.id) or 134400)
  d.name:SetText(e.name)
  d.prof:SetText(((e.pn or "") .. (e.cat and (" · " .. e.cat) or "")):upper())
  local want = Crafts:WantMap()[e.id]
  if #e.crafters == 0 then
    d.known:Hide(); d.lost:Show()
    d.badges:Set("Personne ne sait la faire", C.amber)
    local st = want and Crafts.WISH_STATUS[want.order.s]
    d.status:Show()
    d.status:Set(st and st.label or "Pas encore cherchée", C.brume)
    local names = want and Crafts:Wanters(want.order.id) or {}
    d.wantLabel:SetText("QUI LA VEUT (" .. #names .. ")")
    local shown = {}
    for i, n in ipairs(names) do if i <= 8 then shown[#shown + 1] = Util.ShortName(n) end end
    d.wantText:SetText(#names == 0 and (T.Hex(C.muted) .. "Personne pour l'instant. Fais +1 si tu la voudrais.|r")
      or (table.concat(shown, " · ") .. (#names > 8 and (T.Hex(C.muted) .. "  et " .. (#names - 8) .. " autres|r") or "")))
    d.where:SetEnabled(want ~= nil)
    d.where:SetText(want and want.order.wh or "")
    d.where:SetPlaceholder(want and "Vendeur, HV, butin… (Entrée pour enregistrer)" or "Disponible après ton +1")
    d.whereBy:SetText(want and want.order.wh and ("Renseigné par " .. Util.ShortName(want.order.wb or want.order.by or "?")) or "")
    d.learnLabel:SetText("QUI POURRAIT L'APPRENDRE")
    local learn = Crafts:CouldLearn(e)
    local lt = {}
    for i, c in ipairs(learn) do if i <= 4 then lt[#lt + 1] = Util.ShortName(c.name) .. " " .. T.Hex(C.muted) .. c.lv .. "|r" end end
    d.learnText:SetText(#learn == 0 and (T.Hex(C.muted) .. "Personne n'a ce métier dans la guilde.|r")
      or (table.concat(lt, " · ") .. (#learn > 4 and (T.Hex(C.muted) .. "  et " .. (#learn - 4) .. " autres|r") or "")))
    d.want:SetLabel(want and want.mine and "Retirer mon +1" or "+1 Je la veux")
    d.want:SetStyle(want and want.mine and "slate" or "gold")
    return
  end
  d.lost:Hide(); d.known:Show()
  d.badges:Set(#e.crafters .. " artisan" .. (#e.crafters > 1 and "s" or ""), C.teal)
  d.status:Hide()
  local crafters = Crafts:CraftersOf(e.id)
  d.sub:SetText("Artisans (" .. #crafters .. ")")
  if not self.selectedCrafter and crafters[1] then
    for _, c in ipairs(crafters) do
      if not DR.Profile:IsMine(c.name) then self.selectedCrafter = c.name; break end
    end
  end
  d.crafters:SetEmptyText(nil)
  d.crafters:SetItems(crafters, true)
  -- Ceux qui ont le métier mais n'ont pas encore partagé leurs recettes.
  local unshared = Crafts:Unshared(e.p)
  self.remindName = nil
  for _, u in ipairs(unshared) do
    if not DR.Profile:IsMine(u.name) then self.remindName = u.name; break end
  end
  d.unshared:SetShown(self.remindName ~= nil)
  d.remind:SetShown(self.remindName ~= nil)
  if self.remindName then
    d.unshared:SetText("Pas encore partagé : " .. Util.ShortName(self.remindName) .. (#unshared > 2 and (" et " .. (#unshared - 2) .. " autres") or ""))
  end
  local who = self.selectedCrafter and Util.ShortName(self.selectedCrafter) or "…"
  d.ask:SetLabel("Demander à " .. who)
  d.ask:SetEnabled(self.selectedCrafter ~= nil and not DR.Profile:IsMine(self.selectedCrafter))
  d.whisper:SetEnabled(self.selectedCrafter ~= nil and not DR.Profile:IsMine(self.selectedCrafter))
end

---------------------------------------------------------------------------
-- Recettes recherchées
---------------------------------------------------------------------------
function Tab:BuildWishes(p, width, height)
  local input = W.Edit(p, width - 200 - 140 - 16, 28, "Maj+clic sur une recette (HV, chat, métier) ou tape son nom", 400)
  input.acceptLinks = true
  input:SetPoint("TOPLEFT", 0, 0)
  input:SetScript("OnEnterPressed", function() self:AddWish() end)
  self.wishInput = input
  self.wishProfBtn = W.Button(p, "Métier : ?", "ghost", 200, 28)
  self.wishProfBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
  self.wishProfBtn:SetScript("OnClick", function(btn)
    local items = { { text = "Je ne sais pas", checked = self.wishProf == nil, func = function() self.wishProf = nil; self:RefreshWishes() end } }
    for id, name in pairs(DR.Profile.PROFESSIONS) do
      if id ~= 182 and id ~= 186 and id ~= 393 and id ~= 356 and id ~= 794 then
        items[#items + 1] = { text = name, checked = self.wishProf and self.wishProf.id == id,
          func = function() self.wishProf = { id = id, name = name }; self:RefreshWishes() end }
      end
    end
    table.sort(items, function(a, b)
      if a.text == "Je ne sais pas" then return true end
      if b.text == "Je ne sais pas" then return false end
      return a.text < b.text
    end)
    W.OpenMenu(btn, items, 200)
  end)
  local add = W.Button(p, "Ajouter", "gold", 132, 28)
  add:SetPoint("LEFT", self.wishProfBtn, "RIGHT", 8, 0)
  add:SetScript("OnClick", function() self:AddWish() end)

  local help = T.Para(p, "body", 11, C.muted, width)
  help:SetPoint("TOPLEFT", 0, -36)
  help:SetText("Une recette que tu aimerais voir dans la guilde : on l'achète à l'HV, on la trouve ou on l'achète entre nous, puis un artisan l'apprend. Soutiens celles qui te manquent : les plus demandées passent en tête. Elle se ferme toute seule quand un artisan l'apprend.")

  self.wishes = W.List(p, {
    width = width, height = height - 74, rowHeight = 40,
    create = function(row)
      row.bg = T.Fill(row, C.panel)
      T.Border(row, C.line)
      row.badge = W.Badge(row)
      row.badge:SetPoint("LEFT", 10, 0)
      row.name = T.Text(row, "semi", 13, C.ivory)
      row.name:SetPoint("TOPLEFT", 170, -5)
      row.name:SetPoint("RIGHT", -260, 0)
      row.meta = T.Text(row, "body", 11, C.muted)
      row.meta:SetPoint("BOTTOMLEFT", 170, 5)
      row.meta:SetPoint("RIGHT", -260, 0)
      row.vote = W.Button(row, "Moi aussi", "toggle", 120, 26)
      row.vote:SetPoint("RIGHT", -44, 0)
      row.more = W.Button(row, "…", "ghost", 30, 26)
      row.more:SetPoint("RIGHT", -8, 0)
      row.count = T.Text(row, "title", 18, C.goldText)
      row.count:SetPoint("RIGHT", row.vote, "LEFT", -12, 0)
      row:SetScript("OnEnter", function(r)
        if r.item then Crafts:ShowTooltip(r, r.item.sp or (r.item.it and -r.item.it), r.item.link) end
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    update = function(row, o)
      local st = Crafts.WISH_STATUS[o.s] or Crafts.WISH_STATUS.cherchee
      row.badge:Set(st.label, hexColor(st.color))
      row.name:SetText(o.link or o.nm or "?")
      local meta = (o.pn and (o.pn .. " · ") or "") .. "demandée par " .. Util.ShortName(o.req)
      if o.who and (o.s == "apprise" or o.s == "trouvee") then meta = meta .. " · " .. Util.ShortName(o.who) end
      if o.m then meta = meta .. " · « " .. o.m .. " »" end
      row.meta:SetText(meta)
      local n, mine = Crafts:Votes(o.id)
      row.count:SetText(n)
      row.vote:SetActive(mine)
      row.vote:SetLabel(mine and "Je soutiens" or "Moi aussi")
      row.vote:SetShown(o.s == "cherchee" or o.s == "trouvee")
      row.vote:SetScript("OnClick", function() Crafts:Vote(o.id, not mine) end)
      row.more:SetScript("OnClick", function(btn) self:WishMenu(btn, o) end)
      row:SetAlpha((o.s == "apprise" or o.s == "abandonnee") and 0.65 or 1)
    end,
  })
  self.wishes:SetPoint("TOPLEFT", 0, -74)
  self.wishes:SetEmptyText("Aucune recette recherchée pour l'instant.")
end

function Tab:WishMenu(anchor, o)
  local items = {}
  if Crafts:CanEdit(o) then
    items[#items + 1] = { text = "La guilde la cherche", checked = o.s == "cherchee", func = function() Crafts:SetOrderStatus(o.id, "cherchee") end }
    items[#items + 1] = { text = "Trouvée : à apprendre", checked = o.s == "trouvee", func = function() Crafts:SetOrderStatus(o.id, "trouvee", DR.playerName) end }
    items[#items + 1] = { text = "Apprise", checked = o.s == "apprise", func = function() Crafts:SetOrderStatus(o.id, "apprise", DR.playerName) end }
    items[#items + 1] = { text = "Abandonner", checked = o.s == "abandonnee", func = function() Crafts:SetOrderStatus(o.id, "abandonnee") end }
  end
  if DR.Guild:IAmOfficer() or DR.Profile:IsMine(o.req) then
    items[#items + 1] = { text = "Supprimer", color = C.red, func = function() Crafts:DeleteOrder(o.id) end }
  end
  if o.link then
    items[#items + 1] = { text = "Mettre le lien dans le chat", func = function()
      if ChatEdit_InsertLink then
        ChatEdit_InsertLink(o.link)
      elseif ChatFrameUtil and ChatFrameUtil.InsertLink then
        ChatFrameUtil.InsertLink(o.link)
      end
    end }
  end
  if #items == 0 then items[1] = { text = "Rien à faire ici", disabled = true } end
  W.OpenMenu(anchor, items, 210)
end

function Tab:AddWish()
  local text = self.wishInput:GetText()
  local rec, msg = Crafts:Wish(text, self.wishProf, nil)
  if rec then
    self.wishInput:SetText("")
    self.wishInput:ClearFocus()
    UI:Toast(msg or "Ajoutée : la guilde la cherche.", "ok")
  else
    UI:Toast(msg or "Impossible d'ajouter.", "warn")
  end
end

function Tab:RefreshWishes()
  if not self.wishes then return end
  self.wishProfBtn:SetLabel("Métier : " .. (self.wishProf and self.wishProf.name or "je ne sais pas"))
  local list = Crafts:Orders("recette", "all")
  self.wishes:SetItems(list, true)
  local open = 0
  for _, o in ipairs(list) do if o.s == "cherchee" or o.s == "trouvee" then open = open + 1 end end
  self.chips:SetLabel("recherches", "Recettes recherchées  " .. open)
end

---------------------------------------------------------------------------
-- Commandes de fabrication
---------------------------------------------------------------------------
function Tab:BuildOrders(p, width, height)
  self.orderChips = W.Chips(p, {
    { key = "forme", label = "Pour moi" },
    { key = "mine", label = "Mes demandes" },
    { key = "all", label = "Toutes" },
  }, function(key, user)
    self.orderFilter = key
    if user then self:RefreshOrders() end
  end)
  self.orderChips:SetPoint("TOPLEFT", 0, -2)
  self.orderChips:Select("forme")
  local help = T.Text(p, "body", 11, C.muted)
  help:SetPoint("LEFT", self.orderChips, "LEFT", 360, 0)
  help:SetText("Pour demander : onglet « Qui sait faire quoi », choisis la recette et l'artisan.")

  self.orders = W.List(p, {
    width = width, height = height - 40, rowHeight = 44,
    create = function(row)
      row.bg = T.Fill(row, C.panel)
      T.Border(row, C.line)
      row.badge = W.Badge(row)
      row.badge:SetPoint("LEFT", 10, 0)
      row.name = T.Text(row, "semi", 13, C.ivory)
      row.name:SetPoint("TOPLEFT", 120, -6)
      row.name:SetPoint("RIGHT", -300, 0)
      row.meta = T.Text(row, "body", 11, C.muted)
      row.meta:SetPoint("BOTTOMLEFT", 120, 6)
      row.meta:SetPoint("RIGHT", -300, 0)
      row.a1 = W.Button(row, "", "gold", 120, 28)
      row.a1:SetPoint("RIGHT", -136, 0)
      row.a2 = W.Button(row, "", "slate", 120, 28)
      row.a2:SetPoint("RIGHT", -8, 0)
      row:SetScript("OnEnter", function(r)
        if r.item then Crafts:ShowTooltip(r, r.item.sp or (r.item.it and -r.item.it)) end
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    update = function(row, o) self:UpdateOrderRow(row, o) end,
  })
  self.orders:SetPoint("TOPLEFT", 0, -40)
end

local function setAction(btn, label, fn)
  if not label then btn:Hide(); return end
  btn:Show()
  btn:SetLabel(label)
  btn:SetScript("OnClick", fn)
end

function Tab:UpdateOrderRow(row, o)
  local st = Crafts.CRAFT_STATUS[o.s] or Crafts.CRAFT_STATUS.demandee
  row.badge:Set(st.label, hexColor(st.color))
  row.name:SetText(o.nm or "?")
  local meta = Util.ShortName(o.req) .. " → " .. Util.ShortName(o.to) .. " · " .. Util.Ago(o.u)
  if o.m then meta = meta .. " · « " .. o.m .. " »" end
  row.meta:SetText(meta)
  local forMe = o.to and DR.Profile:IsMine(o.to)
  local mine = DR.Profile:IsMine(o.req)
  local a1, a2
  if forMe and o.s == "demandee" then
    a1 = { "Accepter", function() Crafts:SetOrderStatus(o.id, "acceptee") end }
    a2 = { "Refuser", function() Crafts:SetOrderStatus(o.id, "annulee") end }
  elseif forMe and o.s == "acceptee" then
    a1 = { "C'est fait", function() Crafts:SetOrderStatus(o.id, "faite") end }
    a2 = { "Chuchoter", function() Util.Whisper(o.req) end }
  elseif mine and (o.s == "demandee" or o.s == "acceptee") then
    a2 = { "Annuler", function() Crafts:SetOrderStatus(o.id, "annulee") end }
  elseif mine and (o.s == "faite" or o.s == "annulee") then
    a2 = { "Effacer", function() Crafts:DeleteOrder(o.id) end }
  end
  setAction(row.a1, a1 and a1[1], a1 and a1[2])
  setAction(row.a2, a2 and a2[1], a2 and a2[2])
  row:SetAlpha((o.s == "faite" or o.s == "annulee") and 0.65 or 1)
end

function Tab:RefreshOrders()
  if not self.orders then return end
  local forMe = Crafts:Orders("craft", "forme")
  local waiting = 0
  for _, o in ipairs(forMe) do if o.s == "demandee" then waiting = waiting + 1 end end
  self.orderChips:SetLabel("forme", "Pour moi  " .. #forMe)
  self.chips:SetLabel("commandes", waiting > 0 and ("Commandes  " .. waiting .. " à voir") or "Commandes")
  local list = Crafts:Orders("craft", self.orderFilter)
  local empty = {
    forme = "Personne ne t'a rien demandé pour l'instant.",
    mine = "Tu n'as rien demandé. Va dans « Qui sait faire quoi ».",
    all = "Aucune commande dans la guilde.",
  }
  self.orders:SetEmptyText(empty[self.orderFilter])
  self.orders:SetItems(list, true)
end

---------------------------------------------------------------------------
function Tab:Refresh()
  if not self.f then return end
  for key, p in pairs(self.pages) do p:SetShown(key == self.view) end
  self.catalogBadge:SetShown(self.view == "qui")
  if not DR.Store:IsReady() then
    self.recipes:SetEmptyText(IsInGuild() and "Chargement de la guilde…" or "Rejoins la guilde pour voir ses artisans.")
    self.recipes:SetItems({})
    return
  end
  self:RefreshWishes()
  self:RefreshOrders()
  if self.view == "qui" then self:RefreshQui() end
end
