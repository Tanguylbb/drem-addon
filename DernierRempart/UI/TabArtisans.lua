-- Onglet Artisans : une seule vue. Les métiers en icônes, la recherche, les
-- recettes rangées par type de craft (avec « Personne » et un +1 quand personne
-- ne sait la faire), la fiche à droite. « À acheter » (les recettes que la
-- guilde voudrait acheter) et « Mes demandes » (commandes de fabrication) sont
-- à côté, sans prendre de place au-dessus.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Crafts = DR.Crafts

local Tab = {}
UI:RegisterTab("artisans", "Artisans", Tab)
Tab.icon = "tab_artisans"
Tab.tip = "Qui sait fabriquer quoi, les recettes à acheter et tes commandes."

local LIST_W = 330
local INFO_ROW = 44    -- bandeau « métier à ouvrir » ou catalogue
local BODY_Y = 78
local MAX_PROFS = 12

local function hexColor(h) return { Util.Hex(h) } end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function Tab:Create(f, width, height)
  self.f, self.width, self.height = f, width, height
  self.view, self.filter = "recipes", "all"
  self.collapsed = {}
  self.orderFilter = "forme"
  local bodyH = height - BODY_Y
  local fw = width - LIST_W - 10
  self.bodyH, self.ficheW = bodyH, fw

  self:BuildTopRow(f, width)
  self:BuildInfoRow(f, width)
  self:BuildRecipes(f, bodyH)
  self:BuildBuy(f, bodyH)
  self:BuildFiche(f, fw, bodyH)
  self:BuildOrders(f, width, bodyH)
end

-- Les métiers en icônes (cerclés d'or quand choisis) et les deux boutons de droite.
function Tab:BuildTopRow(f, width)
  self.profBtns = {}
  local all = W.IconFrame(f, 36)
  all:SetPoint("TOPLEFT", 0, 0)
  all.label = T.Text(all, "body", 10, C.goldText, "OVERLAY")
  all.label:SetPoint("CENTER", 0, 0)
  all.label:SetJustifyH("CENTER")
  all.label:SetText("Tous")
  all.icon:Hide()
  all.click = CreateFrame("Button", nil, all)
  all.click:SetAllPoints()
  all.click:SetScript("OnClick", function()
    self.allProfs, self.prof, self.selectedRecipe = true, nil, nil
    self.view = "recipes"
    self:Refresh()
  end)
  W.Tip(all.click, "Tous les métiers", "Les recettes de tous les métiers de la guilde, même ceux que tu n'as pas.")
  self.allBtn = all
  for i = 1, MAX_PROFS do
    local b = W.IconFrame(f, 36)
    b.click = CreateFrame("Button", nil, b)
    b.click:SetAllPoints()
    b.click:SetScript("OnClick", function()
      if not b.pid then return end
      self.allProfs, self.prof, self.selectedRecipe = false, b.pid, nil
      self.view = "recipes"
      self:Refresh()
    end)
    b.click:SetScript("OnEnter", function(c)
      GameTooltip:SetOwner(c, "ANCHOR_BOTTOM")
      GameTooltip:SetText(b.pname or "", C.goldText[1], C.goldText[2], C.goldText[3])
      GameTooltip:Show()
    end)
    b.click:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    self.profBtns[i] = b
  end
  self.profName = T.Text(f, "body", 13, C.goldText)

  self.ordersBtn = W.Button(f, "Mes demandes", "chip", 140, 26)
  self.ordersBtn:SetPoint("TOPRIGHT", 0, -5)
  self.ordersBtn:SetScript("OnClick", function() self:SetView(self.view == "orders" and "recipes" or "orders") end)
  W.Tip(self.ordersBtn, "Mes demandes", "Les commandes de fabrication : celles qu'on t'a faites et celles que tu as faites.")
  self.buyBtn = W.Button(f, "À acheter", "chip", 120, 26)
  self.buyBtn:SetPoint("RIGHT", self.ordersBtn, "LEFT", -8, 0)
  self.buyBtn:SetScript("OnClick", function() self:SetView(self.view == "buy" and "recipes" or "buy") end)
  W.Tip(self.buyBtn, "À acheter", "Les recettes que personne ne sait faire et que la guilde voudrait acheter : les plus demandées d'abord.")
end

-- Sous les métiers : le bandeau « métier à ouvrir », ou le catalogue.
function Tab:BuildInfoRow(f, width)
  local row = CreateFrame("Frame", nil, f)
  row:SetPoint("TOPLEFT", 0, -INFO_ROW)
  row:SetSize(width, 28)
  self.infoRow = row
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.text = T.Text(row, "body", 12, C.muted)
  row.text:SetPoint("LEFT", 12, 0)
  row.text:SetPoint("RIGHT", -150, 0)
  row.btn = W.Button(row, "Compris", "sec", 100, 22)
  row.btn:SetPoint("RIGHT", -6, 0)
  row.btn:SetScript("OnClick", function()
    if self.view == "recipes" then
      self.dismissed = true
    else
      self.view = "recipes"
    end
    self:Refresh()
  end)
end

---------------------------------------------------------------------------
-- Recettes : recherche, dossiers par type de craft
---------------------------------------------------------------------------
function Tab:BuildRecipes(f, bodyH)
  local p = CreateFrame("Frame", nil, f)
  p:SetPoint("TOPLEFT", 0, -BODY_Y)
  p:SetSize(LIST_W, bodyH)
  self.recipesPage = p

  local search = W.Search(p, LIST_W - 76, "Chercher une recette…", 60)
  search:SetPoint("TOPLEFT", 0, 0)
  search:HookScript("OnTextChanged", function() if self.f then self:RefreshRecipes() end end)
  self.search = search
  local filter = W.Button(p, "Filtrer >", "sec", 70, 24)
  filter:SetPoint("LEFT", search, "RIGHT", 6, 0)
  filter:SetScript("OnClick", function(btn)
    local function set(key) return function() self.filter = key; self.selectedRecipe = nil; self:RefreshRecipes() end end
    W.OpenMenu(btn, {
      { text = "Toutes les recettes", checked = self.filter == "all", func = set("all") },
      { text = "Il me manque", checked = self.filter == "lacking", func = set("lacking") },
      { text = "Personne ne la sait", checked = self.filter == "nobody", func = set("nobody") },
    }, 200)
  end)
  self.filterBtn = filter
  W.Tip(filter, "Filtrer", "Il me manque : les recettes qu'aucun de tes persos n'a apprises. Personne ne la sait : les recettes vues dans la fenêtre d'un artisan que personne ne connaît encore.")

  self.lackCheck = W.Check(p, "Il me manque", function(on)
    self.filter = on and "lacking" or "all"
    self.selectedRecipe = nil
    self:RefreshRecipes()
  end)
  self.lackCheck:SetPoint("TOPLEFT", 2, -30)

  local listBox, list = W.BlackList(p, {
    width = LIST_W, height = bodyH - 54, rowHeight = 28,
    create = function(row)
      -- Un type de craft (dossier qu'on ouvre et ferme).
      local cat = W.Header(row, LIST_W - 14)
      cat:SetPoint("TOPLEFT", 2, -2)
      cat:SetPoint("BOTTOMRIGHT", -2, 2)
      row.cat = cat
      -- Une recette.
      local rec = CreateFrame("Frame", nil, row)
      rec:SetAllPoints()
      row.sel = rec:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 1, 1, 0.1)
      row.selBox = CreateFrame("Frame", nil, rec)
      row.selBox:SetAllPoints()
      T.Border(row.selBox, C.gold, 1, 2)
      row.icon = rec:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(20, 20)
      row.icon:SetPoint("LEFT", 12, 0)
      row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      row.name = T.Text(rec, "body", 13, C.ivory)
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
      row.name:SetPoint("RIGHT", -130, 0)
      row.dot = W.Dot(rec, 8)
      row.dot:SetPoint("RIGHT", -78, 0)
      row.state = T.Text(rec, "body", 11, C.green)
      row.state:SetPoint("RIGHT", -8, 0)
      row.state:SetWidth(66)
      row.state:SetJustifyH("RIGHT")
      row.plus = W.Button(rec, "", "toggle", 52, 20)
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
      self:RefreshRecipes()
    end,
  })
  listBox:SetPoint("TOPLEFT", 0, -54)
  self.recipes = list
end

function Tab:UpdateRecipeRow(row, item)
  if item.kind == "cat" then
    row.cat:Show(); row.rec:Hide()
    row.cat:SetLabel(item.g.name, item.g.total)
    row.cat:SetOpen(item.open)
    row.cat:SetExtra(item.g.nobody > 0 and (item.g.nobody .. " sans artisan") or "", C.amber)
    row.cat.onToggle = function(open)
      self.collapsed[item.g.name] = (not open) or nil
      self:RefreshRecipes()
    end
    return
  end
  local e, want = item.e, item.want
  row.cat:Hide(); row.rec:Show()
  row.icon:SetTexture(Crafts:RecipeIcon(e.id) or 134400)
  row.name:SetText(e.name)
  local selected = self.selectedRecipe == e.id
  row.sel:SetShown(selected)
  row.selBox:SetShown(selected)
  T.Color(row.name, selected and C.goldPale or C.ivory)
  if #e.crafters == 0 then
    row.dot:Hide()
    row.state:Hide()
    local n = want and want.n or 0
    row.plus:Show()
    row.plus:SetLabel("+1 · " .. n)
    row.plus:SetActive(want and want.mine or false)
    row.plus:SetScript("OnClick", function() self:ToggleWant(e) end)
    row.noone = row.noone or T.Text(row.rec, "body", 11, C.red)
    row.noone:SetPoint("RIGHT", row.plus, "LEFT", -8, 0)
    row.noone:SetText("Personne")
    row.noone:Show()
    row.name:SetPoint("RIGHT", -130, 0)
  else
    if row.noone then row.noone:Hide() end
    row.plus:Hide()
    row.dot:Show(); row.dot:SetColor(C.green)
    row.state:Show()
    row.state:SetText(#e.crafters .. " artisan" .. (#e.crafters > 1 and "s" or ""))
    T.Color(row.state, C.green)
  end
end

function Tab:SelectedEntry()
  if not self.selectedRecipe then return nil end
  for _, e in ipairs(self.entries or {}) do
    if e.id == self.selectedRecipe then return e end
  end
  return nil
end

function Tab:ToggleWant(e)
  local order, on, msg = Crafts:ToggleWant(e)
  if not order then
    UI:Toast(msg or "Impossible d'ajouter.", "warn")
  else
    UI:Toast(on and "+1 : la guilde saura que tu voudrais cette recette." or "Ton +1 est retiré.", "ok")
  end
  self:Refresh()
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

-- Le métier montré (un métier de la guilde, sinon le mien par défaut) et son nom.
function Tab:ResolveProfession()
  local professions = Crafts:Professions()
  local valid = false
  for _, pr in ipairs(professions) do if pr.id == self.prof then valid = true end end
  if not self.allProfs and not valid then self.prof = self:DefaultProfession() end
  local profName = "Tous les métiers"
  for _, pr in ipairs(professions) do if pr.id == self.prof and not self.allProfs then profName = pr.name end end
  self.profName:SetText(profName)
  return professions
end

function Tab:RefreshRecipes()
  if not self.recipes then return end
  local professions = self:ResolveProfession()
  self.lackCheck:SetChecked(self.filter == "lacking")

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
  local items, entries = {}, {}
  for _, g in ipairs(groups) do
    local open = searching or not self.collapsed[g.name]
    items[#items + 1] = { kind = "cat", g = g, open = open }
    for _, e in ipairs(g.entries) do
      entries[#entries + 1] = e
      if open then items[#items + 1] = { kind = "rec", e = e, want = wants[e.id] } end
    end
  end
  self.items, self.entries = items, entries

  local anything = #Crafts:Index().list > 0 or #Crafts:Index().missing > 0
  self.recipes:SetEmptyText(not anything
    and "Pas encore de recettes. Chaque artisan n'a qu'à ouvrir sa fenêtre de métier une fois : ses recettes sont lues et partagées toutes seules."
    or (self.filter == "nobody" and "Rien à montrer : la liste se remplit quand un artisan ouvre sa fenêtre de métier avec l'add-on."
      or "Aucune recette ne correspond."))
  self.recipes:SetItems(items, true)
  self:RefreshFiche()
end

---------------------------------------------------------------------------
-- La fiche (à droite) : une recette, ou une recette à acheter
---------------------------------------------------------------------------
function Tab:BuildFiche(f, fw, bodyH)
  local d = W.Navy(f)
  d:SetPoint("TOPLEFT", LIST_W + 10, -BODY_Y)
  d:SetSize(fw, bodyH)
  self.fiche, self.quiDetail = d, d
  local pad = 16
  local inner = fw - 2 * pad
  d.empty = T.Para(d, "body", 13, C.brume, inner)
  d.empty:SetPoint("TOPLEFT", pad, -pad)
  local body = CreateFrame("Frame", nil, d)
  body:SetAllPoints()
  d.body = body

  d.iconBox = W.IconFrame(body, 42)
  d.iconBox:SetPoint("TOPLEFT", pad, -14)
  d.name = T.Text(body, "title", 19, { 1, 1, 1 })
  d.name:SetPoint("TOPLEFT", d.iconBox, "TOPRIGHT", 11, -1)
  d.name:SetPoint("RIGHT", -pad - 40, 0)
  d.prof = T.Text(body, "body", 11, C.muted)
  d.prof:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -5)
  d.prof:SetPoint("RIGHT", -pad, 0)
  d.more = W.Button(body, "…", "sec", 30, 22)
  d.more:SetPoint("TOPRIGHT", -pad, -14)
  d.more:SetScript("OnClick", function(btn) if self.fiche.order then self:WishMenu(btn, self.fiche.order) end end)
  d.status = T.Text(body, "body", 13, C.green)
  d.status:SetPoint("TOPLEFT", pad, -66)
  d.status:SetPoint("RIGHT", -pad, 0)

  -- Quelqu'un sait la faire : les artisans, et la demande.
  local known = CreateFrame("Frame", nil, body)
  known:SetPoint("TOPLEFT", 0, -90)
  known:SetPoint("BOTTOMRIGHT", 0, 0)
  d.known = known
  d.crafterHeader = W.Header(known, inner)
  d.crafterHeader:SetPoint("TOPLEFT", pad, 0)
  d.crafterHeader:SetLabel("Artisans", 0)
  local box, list = W.BlackList(known, {
    width = inner, height = 132, rowHeight = 22,
    create = function(row)
      row.dot = W.Dot(row, 8)
      row.dot:SetPoint("LEFT", 8, 0)
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 1, 1, 0.1)
      row.text = T.Text(row, "body", 12)
      row.text:SetPoint("LEFT", row.dot, "RIGHT", 9, 0)
    end,
    update = function(row, c)
      row.dot:SetColor(c.online and C.green or C.muted)
      local mine = DR.Profile:IsMine(c.name) and (T.Hex(C.goldText) .. "  (toi)|r") or ""
      row.text:SetText(T.Hex(C.goldText) .. Util.ClassName(c.name, c.class) .. "|r" .. T.Hex(c.online and C.cyan or C.muted)
        .. (c.online and "   en ligne" or "   hors ligne") .. "|r" .. mine)
      row.sel:SetShown(self.selectedCrafter == c.name)
    end,
    click = function(c) self.selectedCrafter = c.name; self:RefreshFiche() end,
  })
  box:SetPoint("TOPLEFT", pad, -28)
  d.crafters, d.crafterBox = list, box
  d.unshared = T.Text(known, "body", 12, C.amber)
  d.unshared:SetPoint("TOPLEFT", pad, -172)
  d.unshared:SetPoint("RIGHT", -pad - 108, 0)
  d.remind = W.Button(known, "Lui rappeler", "sec", 100, 22)
  d.remind:SetPoint("TOPRIGHT", -pad, -168)
  d.remind:SetScript("OnClick", function()
    if self.remindName then Util.Whisper(self.remindName) end
  end)
  W.Tip(d.remind, "Lui rappeler", "Cette personne a le métier mais n'a pas encore ouvert sa fenêtre de métier avec l'add-on : ses recettes ne sont pas partagées.")
  d.note = W.Edit(known, inner, 24, "Petit mot pour l'artisan (composants fournis…)", 200)
  d.note:SetPoint("BOTTOMLEFT", pad, 48)
  d.whisper = W.Button(known, "Chuchoter", "sec", 120, 30)
  d.whisper:SetPoint("BOTTOMLEFT", pad, 12)
  d.whisper:SetScript("OnClick", function()
    if self.selectedCrafter then Util.Whisper(self.selectedCrafter) end
  end)
  d.ask = W.Button(known, "Demander", "red", 240, 30)
  d.ask:SetPoint("BOTTOMRIGHT", -pad, 12)
  d.ask:SetScript("OnClick", function() self:AskCraft() end)

  -- Personne ne sait la faire : qui la veut, où la trouver, qui pourrait l'apprendre.
  local lost = CreateFrame("Frame", nil, body)
  lost:SetPoint("TOPLEFT", 0, -90)
  lost:SetPoint("BOTTOMRIGHT", 0, 0)
  d.lost = lost
  d.wantHeader = W.Header(lost, inner)
  d.wantHeader:SetPoint("TOPLEFT", pad, 0)
  d.wantText = T.Para(lost, "body", 12, C.goldText, inner - 12)
  d.wantText:SetPoint("TOPLEFT", pad + 6, -32)
  d.wantText:SetMaxLines(3)
  d.whereHeader = W.Header(lost, inner)
  d.whereHeader:SetPoint("TOPLEFT", pad, -92)
  d.whereHeader:SetLabel("Où la trouver")
  d.where = W.Edit(lost, inner, 24, "Vendeur, HV, butin… (après ton +1)", 120)
  d.where:SetPoint("TOPLEFT", pad, -122)
  d.where:SetScript("OnEnterPressed", function(e)
    e:ClearFocus()
    local w = self:SelectedWant()
    if w then
      Crafts:SetWhere(w.id, e:GetText())
      UI:Toast("Indication enregistrée.", "ok")
    end
  end)
  d.whereBy = T.Text(lost, "body", 11, C.muted)
  d.whereBy:SetPoint("TOPLEFT", d.where, "BOTTOMLEFT", 2, -4)
  d.learnHeader = W.Header(lost, inner)
  d.learnHeader:SetPoint("TOPLEFT", pad, -184)
  d.learnHeader:SetLabel("Qui pourrait l'apprendre")
  d.learnText = T.Para(lost, "body", 12, C.goldText, inner - 12)
  d.learnText:SetPoint("TOPLEFT", pad + 6, -216)
  d.learnText:SetMaxLines(3)
  d.want = W.Button(lost, "+1 Je la veux", "red", 200, 30)
  d.want:SetPoint("BOTTOMRIGHT", -pad, 12)
  d.want:SetScript("OnClick", function() self:WantClicked() end)
end

-- La demande derrière la fiche : une commande « recette » (À acheter) ou, depuis
-- les recettes, celle que mon +1 a créée.
function Tab:SelectedWant()
  local d = self.fiche
  if d.order then return d.order end
  local e = self:SelectedEntry()
  local w = e and Crafts:WantMap()[e.id]
  return w and w.order or nil
end

function Tab:WantClicked()
  local d = self.fiche
  if d.order then
    local _, mine = Crafts:Votes(d.order.id)
    Crafts:Vote(d.order.id, not mine)
    UI:Toast(mine and "Ton +1 est retiré." or "+1 : la guilde saura que tu voudrais cette recette.", "ok")
    self:Refresh()
    return
  end
  local e = self:SelectedEntry()
  if e then self:ToggleWant(e) end
end

function Tab:AskCraft()
  local e = self:SelectedEntry()
  if not e or not self.selectedCrafter then
    UI:Toast("Choisis d'abord un artisan dans la liste.", "warn")
    return
  end
  local rec, err = Crafts:RequestCraft(e.id, self.selectedCrafter, self.fiche.note:GetText())
  if rec then
    self.fiche.note:SetText("")
    UI:Toast("Demande envoyée à " .. Util.ShortName(self.selectedCrafter) .. ". Suis-la dans « Mes demandes ».", "ok")
  else
    UI:Toast(err or "Impossible d'envoyer la demande.", "warn")
  end
end

function Tab:RefreshFiche()
  if self.view == "buy" then return self:RefreshBuyFiche() end
  local d = self.fiche
  local e = self:SelectedEntry()
  d.order = nil
  d.more:Hide()
  if not e then
    d.body:Hide(); d.empty:Show()
    d.empty:SetText("Choisis une recette : tu vois qui sait la faire, qui est en ligne, et tu peux le lui demander en un clic. Une recette que personne n'a se marque d'un +1 : la guilde saura qu'il faut l'acheter.")
    return
  end
  d.empty:Hide(); d.body:Show()
  d.iconBox.icon:SetTexture(Crafts:RecipeIcon(e.id) or 134400)
  d.name:SetText(e.name)
  d.prof:SetText((e.pn or "") .. (e.cat and (" · " .. e.cat) or ""))
  local want = Crafts:WantMap()[e.id]
  if #e.crafters == 0 then
    self:ShowLost(want and want.order or nil, e, want)
    return
  end
  d.lost:Hide(); d.known:Show()
  d.status:SetText(#e.crafters .. " artisan" .. (#e.crafters > 1 and "s la connaissent." or " la connaît."))
  T.Color(d.status, C.green)
  local crafters = Crafts:CraftersOf(e.id)
  d.crafterHeader:SetLabel("Artisans", #crafters)
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

-- Personne ne la sait : qui la veut, où la trouver, qui pourrait l'apprendre.
-- order : la demande (ou nil si personne n'a encore fait +1) ; e : la recette
-- (ou une fausse recette pour une demande libre).
function Tab:ShowLost(order, e, want)
  local d = self.fiche
  d.known:Hide(); d.lost:Show()
  local st = order and Crafts.WISH_STATUS[order.s]
  d.status:SetText("Personne ne sait la faire" .. (st and (" · " .. st.label) or " · pas encore cherchée"))
  T.Color(d.status, C.amber)
  local names = order and Crafts:Wanters(order.id) or {}
  d.wantHeader:SetLabel("Qui la veut", #names)
  local shown = {}
  for i, n in ipairs(names) do if i <= 8 then shown[#shown + 1] = Util.ShortName(n) end end
  d.wantText:SetText(#names == 0 and (T.Hex(C.muted) .. "Personne pour l'instant. Fais +1 si tu la voudrais.|r")
    or (table.concat(shown, " · ") .. (#names > 8 and (T.Hex(C.muted) .. "  et " .. (#names - 8) .. " autres|r") or "")))
  d.where:SetEnabled(order ~= nil)
  d.where:SetText(order and order.wh or "")
  d.where:SetPlaceholder(order and "Vendeur, HV, butin… (Entrée pour enregistrer)" or "Disponible après ton +1")
  d.whereBy:SetText(order and order.wh and ("Renseigné par " .. Util.ShortName(order.wb or order.by or "?")) or "")
  local learn = Crafts:CouldLearn(e)
  local lt = {}
  for i, c in ipairs(learn) do if i <= 4 then lt[#lt + 1] = Util.ShortName(c.name) .. " " .. T.Hex(C.muted) .. c.lv .. "|r" end end
  d.learnText:SetText(#learn == 0 and (T.Hex(C.muted) .. "Personne n'a ce métier dans la guilde.|r")
    or (table.concat(lt, " · ") .. (#learn > 4 and (T.Hex(C.muted) .. "  et " .. (#learn - 4) .. " autres|r") or "")))
  local mine = (want and want.mine) or (order and select(2, Crafts:Votes(order.id))) or false
  d.want:SetLabel(mine and "Retirer mon +1" or "+1 Je la veux")
  d.want:SetStyle(mine and "sec" or "red")
end

---------------------------------------------------------------------------
-- À acheter : les recettes que la guilde voudrait acheter
---------------------------------------------------------------------------
function Tab:BuildBuy(f, bodyH)
  local p = CreateFrame("Frame", nil, f)
  p:SetPoint("TOPLEFT", 0, -BODY_Y)
  p:SetSize(LIST_W, bodyH)
  self.buyPage = p
  local title = T.Text(p, "body", 13, C.goldText)
  title:SetPoint("TOPLEFT", 2, -2)
  title:SetText("À acheter : les plus demandées d'abord")

  local input = W.Edit(p, LIST_W, 24, "Maj+clic sur une recette ou tape son nom", 400)
  input.acceptLinks = true
  input:SetPoint("TOPLEFT", 0, -24)
  input:SetScript("OnEnterPressed", function() self:AddWish() end)
  self.wishInput = input
  self.wishProfBtn = W.Button(p, "Métier : ?", "sec", LIST_W - 86, 24)
  self.wishProfBtn:SetPoint("TOPLEFT", 0, -52)
  self.wishProfBtn:SetScript("OnClick", function(btn)
    local items = { { text = "Je ne sais pas", checked = self.wishProf == nil, func = function() self.wishProf = nil; self:RefreshBuy() end } }
    for id, name in pairs(DR.Profile.PROFESSIONS) do
      if id ~= 182 and id ~= 186 and id ~= 393 and id ~= 356 and id ~= 794 then
        items[#items + 1] = { text = name, checked = self.wishProf and self.wishProf.id == id,
          func = function() self.wishProf = { id = id, name = name }; self:RefreshBuy() end }
      end
    end
    table.sort(items, function(a, b)
      if a.text == "Je ne sais pas" then return true end
      if b.text == "Je ne sais pas" then return false end
      return a.text < b.text
    end)
    W.OpenMenu(btn, items, 200)
  end)
  W.Tip(self.wishProfBtn, "Métier de la recette", "Facultatif : aide les artisans à la retrouver.")
  local add = W.Button(p, "Ajouter", "sec", 80, 24)
  add:SetPoint("LEFT", self.wishProfBtn, "RIGHT", 6, 0)
  add:SetScript("OnClick", function() self:AddWish() end)

  local listBox, list = W.BlackList(p, {
    width = LIST_W, height = bodyH - 86, rowHeight = 50,
    create = function(row)
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 1, 1, 0.1)
      row.selBox = CreateFrame("Frame", nil, row)
      row.selBox:SetAllPoints()
      T.Border(row.selBox, C.gold, 1, 2)
      row.rank = T.Text(row, "title", 17, C.goldText)
      row.rank:SetPoint("LEFT", 10, 0)
      row.rank:SetWidth(22)
      row.name = T.Text(row, "body", 13, C.ivory)
      row.name:SetPoint("TOPLEFT", 38, -9)
      row.name:SetPoint("RIGHT", -70, 0)
      row.meta = T.Text(row, "body", 11, C.muted)
      row.meta:SetPoint("BOTTOMLEFT", 38, 9)
      row.meta:SetPoint("RIGHT", -70, 0)
      row.count = T.Text(row, "body", 12, C.goldText)
      row.count:SetPoint("RIGHT", -10, 0)
      row:SetScript("OnEnter", function(r)
        if r.item then Crafts:ShowTooltip(r, r.item.sp or (r.item.it and -r.item.it), r.item.link) end
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    update = function(row, o, index)
      local st = Crafts.WISH_STATUS[o.s] or Crafts.WISH_STATUS.cherchee
      row.rank:SetText(index)
      row.name:SetText(o.link or o.nm or "?")
      T.Color(row.name, (o.s == "apprise" or o.s == "abandonnee") and C.muted or C.ivory)
      row.meta:SetText("|cff" .. st.color .. st.label .. "|r" .. T.Hex(C.muted) .. (o.pn and (" · " .. o.pn) or "") .. "|r")
      local n = Crafts:Votes(o.id)
      row.count:SetText("+1 · " .. n)
      local selected = self.selectedOrder == o.id
      row.sel:SetShown(selected)
      row.selBox:SetShown(selected)
      row:SetAlpha((o.s == "apprise" or o.s == "abandonnee") and 0.65 or 1)
    end,
    click = function(o) self.selectedOrder = o.id; self:RefreshBuy() end,
  })
  listBox:SetPoint("TOPLEFT", 0, -82)
  self.wishes = list
  p:Hide()
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
    items[#items + 1] = { text = "Supprimer", color = C.red, func = function() Crafts:DeleteOrder(o.id); self.selectedOrder = nil end }
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
    self.selectedOrder = rec.id
    UI:Toast(msg or "Ajoutée : la guilde la cherche.", "ok")
  else
    UI:Toast(msg or "Impossible d'ajouter.", "warn")
  end
end

function Tab:RefreshBuy()
  if not self.wishes then return end
  self.wishProfBtn:SetLabel("Métier : " .. (self.wishProf and self.wishProf.name or "je ne sais pas"))
  local list = Crafts:Orders("recette", "all")
  self.wishes:SetEmptyText("Aucune recette à acheter pour l'instant. Fais +1 sur une recette que personne ne sait faire, ou ajoute-la ici.")
  self.wishes:SetItems(list, true)
  local found = false
  for _, o in ipairs(list) do if o.id == self.selectedOrder then found = true end end
  if not found then self.selectedOrder = list[1] and list[1].id or nil end
  if self.view == "buy" then self:RefreshBuyFiche() end
end

function Tab:RefreshBuyFiche()
  local d = self.fiche
  local o
  for _, x in ipairs(Crafts:Orders("recette", "all")) do if x.id == self.selectedOrder then o = x end end
  d.order = o
  if not o then
    d.body:Hide(); d.empty:Show()
    d.empty:SetText("Choisis une recette à gauche : tu vois qui la veut, où la trouver et qui pourrait l'apprendre.")
    d.more:Hide()
    return
  end
  d.empty:Hide(); d.body:Show()
  local id = o.sp or (o.it and -o.it)
  d.iconBox.icon:SetTexture((id and Crafts:RecipeIcon(id)) or 134400)
  d.name:SetText(o.link or o.nm or "?")
  d.prof:SetText((o.pn or "Métier inconnu") .. " · demandée par " .. Util.ShortName(o.req))
  d.more:Show()
  local fake = { p = o.p, crafters = {} }
  local _, mine = Crafts:Votes(o.id)
  self:ShowLost(o, fake, { mine = mine })
end

---------------------------------------------------------------------------
-- Mes demandes : les commandes de fabrication
---------------------------------------------------------------------------
function Tab:BuildOrders(f, width, bodyH)
  local p = CreateFrame("Frame", nil, f)
  p:SetPoint("TOPLEFT", 0, -BODY_Y)
  p:SetSize(width, bodyH)
  self.ordersPage = p
  self.orderTabs = W.TabStrip(p, {
    { key = "forme", label = "Pour moi" },
    { key = "mine", label = "Mes demandes" },
    { key = "all", label = "Toutes" },
  }, function(key, user)
    self.orderFilter = key
    if user then self:RefreshOrders() end
  end)
  self.orderTabs:SetPoint("TOPLEFT", 0, 0)
  self.orderTabs:SetWidth(width)
  self.orderTabs:Select("forme")
  local help = T.Text(p, "body", 11, C.muted)
  help:SetPoint("BOTTOMLEFT", 0, 0)
  help:SetText("Pour demander une fabrication : choisis la recette, puis l'artisan, dans la vue des recettes.")

  local listBox, list = W.BlackList(p, {
    width = width, height = bodyH - 42 - 22, rowHeight = 46,
    create = function(row)
      row.badge = W.Badge(row)
      row.badge:SetPoint("LEFT", 10, 0)
      row.name = T.Text(row, "body", 13, C.goldText)
      row.name:SetPoint("TOPLEFT", 150, -8)
      row.name:SetPoint("RIGHT", -300, 0)
      row.meta = T.Text(row, "body", 11, C.muted)
      row.meta:SetPoint("BOTTOMLEFT", 150, 8)
      row.meta:SetPoint("RIGHT", -300, 0)
      row.a1 = W.Button(row, "", "red", 120, 26)
      row.a1:SetPoint("RIGHT", -140, 0)
      row.a2 = W.Button(row, "", "sec", 120, 26)
      row.a2:SetPoint("RIGHT", -10, 0)
      row.sep = row:CreateTexture(nil, "BACKGROUND")
      row.sep:SetPoint("BOTTOMLEFT", 0, 0)
      row.sep:SetPoint("BOTTOMRIGHT", 0, 0)
      row.sep:SetHeight(1)
      row.sep:SetColorTexture(C.rule[1], C.rule[2], C.rule[3], 1)
      row:SetScript("OnEnter", function(r)
        if r.item then Crafts:ShowTooltip(r, r.item.sp or (r.item.it and -r.item.it)) end
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    update = function(row, o) self:UpdateOrderRow(row, o) end,
  })
  listBox:SetPoint("TOPLEFT", 0, -38)
  self.orders = list
  p:Hide()
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
  local meta = Util.ShortName(o.req) .. " pour " .. Util.ShortName(o.to) .. " · " .. Util.Ago(o.u)
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
  self.orderTabs:SetLabel("forme", "Pour moi  " .. #forMe)
  local list = Crafts:Orders("craft", self.orderFilter)
  local empty = {
    forme = "Personne ne t'a rien demandé pour l'instant.",
    mine = "Tu n'as rien demandé. Choisis une recette et un artisan dans la vue des recettes.",
    all = "Aucune commande dans la guilde.",
  }
  self.orders:SetEmptyText(empty[self.orderFilter])
  self.orders:SetItems(list, true)
end

---------------------------------------------------------------------------
-- Vues et rafraîchissement
---------------------------------------------------------------------------
function Tab:SetView(view)
  self.view = view
  self:Refresh()
end

-- Les icônes des métiers, la ligne d'info (bandeau ou catalogue), les deux boutons.
function Tab:RefreshTop()
  local professions = self:ResolveProfession()
  local x = 44
  for i, b in ipairs(self.profBtns) do
    local pr = professions[i]
    if pr then
      b.pid, b.pname = pr.id, pr.name
      b.icon:SetTexture(T.ProfIcon(pr.id))
      b:SetSelected(not self.allProfs and self.prof == pr.id and self.view == "recipes")
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", x, 0)
      b:Show()
      x = x + 42
    else
      b:Hide()
    end
  end
  self.allBtn:SetSelected(self.allProfs and self.view == "recipes")
  self.profName:ClearAllPoints()
  self.profName:SetPoint("LEFT", self.f, "TOPLEFT", x + 8, -18)

  local open = DR.Store:IsReady() and DR.Profile:ToOpen() or {}
  local row = self.infoRow
  if self.view ~= "recipes" then
    T.Gradient(row.bg, { 0.16, 0.13, 0.1 }, { 0.1, 0.08, 0.06 })
    row.text:SetText(self.view == "buy" and "Les recettes que la guilde voudrait acheter. Le +1 dit « moi aussi »."
      or "Les commandes de fabrication, pour toi et de ta part.")
    T.Color(row.text, C.brume)
    row.btn:SetLabel("Retour aux recettes")
    row.btn:SetWidth(150)
    row.btn:Show()
  elseif #open > 0 and not self.dismissed then
    T.Gradient(row.bg, { 0.29, 0.094, 0.063 }, { 0.17, 0.055, 0.031 })
    local names = table.concat(open, " et ")
    row.text:SetText("Tu n'as pas encore partagé tes recettes de " .. names .. " : ouvre "
      .. (#open > 1 and "leurs fenêtres" or "ta fenêtre " .. open[1]) .. " une fois.")
    T.Color(row.text, { 0.96, 0.79, 0.54 })
    row.btn:SetLabel("Compris")
    row.btn:SetWidth(100)
    row.btn:Show()
  else
    T.Gradient(row.bg, { 0.12, 0.1, 0.075 }, { 0.08, 0.065, 0.05 })
    row.btn:Hide()
    local info = (self.prof and not self.allProfs) and Crafts:CatalogInfo(self.prof) or nil
    if info then
      row.text:SetText("Catalogue " .. (self.profName:GetText() or "") .. " : " .. info.recipes .. " recettes · lu par " .. info.readers
        .. " membre" .. (info.readers > 1 and "s" or ""))
      T.Color(row.text, (info.members > info.readers) and C.amber or C.muted)
    else
      row.text:SetText("Catalogue : " .. (#Crafts:Index().list + #Crafts:Index().missing) .. " recettes · " .. #professions .. " métiers")
      T.Color(row.text, C.muted)
    end
  end

  local wishes = Crafts:Orders("recette", "all")
  local openWishes = 0
  for _, o in ipairs(wishes) do if o.s == "cherchee" or o.s == "trouvee" then openWishes = openWishes + 1 end end
  self.buyBtn:SetLabel("À acheter  " .. T.Hex(C.goldText) .. openWishes .. "|r")
  self.buyBtn:SetActive(self.view == "buy")
  local forMe, waiting = Crafts:Orders("craft", "forme"), 0
  for _, o in ipairs(forMe) do if o.s == "demandee" then waiting = waiting + 1 end end
  self.ordersBtn:SetLabel("Mes demandes  " .. T.Hex(waiting > 0 and C.amber or C.muted) .. #forMe .. "|r")
  self.ordersBtn:SetActive(self.view == "orders")
end

function Tab:Refresh()
  if not self.f then return end
  local ready = DR.Store:IsReady()
  self.recipesPage:SetShown(self.view == "recipes")
  self.buyPage:SetShown(self.view == "buy")
  self.ordersPage:SetShown(self.view == "orders")
  self.fiche:SetShown(self.view ~= "orders")
  if not ready then
    self.recipes:SetEmptyText(IsInGuild() and "Chargement de la guilde…" or "Rejoins la guilde pour voir ses artisans.")
    self.recipes:SetItems({})
    return
  end
  self:RefreshTop()
  self:RefreshBuy()
  self:RefreshOrders()
  if self.view == "recipes" then self:RefreshRecipes() end
end

-- Pastille orange de l'onglet : les commandes qui attendent mon accord.
function Tab:Badge()
  if not DR.Store:IsReady() then return 0 end
  local n = 0
  for _, o in ipairs(Crafts:Orders("craft", "forme")) do if o.s == "demandee" then n = n + 1 end end
  return n, n == 1 and "1 commande attend ton accord." or (n .. " commandes attendent ton accord.")
end
