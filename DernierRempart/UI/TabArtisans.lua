-- Onglet Artisans : qui sait fabriquer quoi, recettes que la guilde cherche,
-- commandes de fabrication.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C
local Crafts = DR.Crafts

local Tab = {}
UI:RegisterTab("artisans", "Artisans", Tab)

local LIST_W = 470

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
-- Qui sait faire quoi
---------------------------------------------------------------------------
function Tab:BuildQui(p, width, height)
  local search = W.Edit(p, 230, 28, "Chercher une recette…", 60)
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

  self.profBtn = W.Button(p, "Métier : tous", "ghost", 170, 28)
  self.profBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
  self.profBtn:SetScript("OnClick", function(btn)
    local items = { { text = "Tous les métiers", checked = self.prof == nil, func = function() self.prof = nil; self:RefreshQui() end } }
    for _, pr in ipairs(Crafts:Professions()) do
      items[#items + 1] = { text = pr.name, checked = self.prof == pr.id, func = function() self.prof = pr.id; self:RefreshQui() end }
    end
    W.OpenMenu(btn, items, 200)
  end)

  self.modeChips = W.Chips(p, {
    { key = "known", label = "Quelqu'un sait" },
    { key = "missing", label = "Personne ne l'a" },
  }, function(key, user)
    self.mode = key
    if user then self.selectedRecipe = nil; self:RefreshQui() end
  end)
  self.modeChips:SetPoint("LEFT", self.profBtn, "RIGHT", 12, 0)
  self.modeChips:Select("known")
  W.Tip(self.modeChips.buttons.missing, "Personne ne l'a",
    "Recettes vues dans la fenêtre de métier d'un artisan de la guilde, que personne ne connaît encore.")

  local listH = height - 40
  self.recipes = W.List(p, {
    width = LIST_W, height = listH, rowHeight = 30,
    create = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(22, 22)
      row.icon:SetPoint("LEFT", 4, 0)
      row.name = T.Text(row, "semi", 12, C.ivory)
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
      row.name:SetPoint("RIGHT", -150, 0)
      row.who = T.Text(row, "body", 11, C.brume)
      row.who:SetPoint("RIGHT", -6, 0)
      row.who:SetJustifyH("RIGHT")
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(1, 1, 1, 0.06)
      row:SetScript("OnEnter", function(r)
        if r.item then Crafts:ShowTooltip(r, r.item.id) end
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    update = function(row, e)
      row.icon:SetTexture(Crafts:RecipeIcon(e.id) or 134400)
      row.name:SetText(e.name)
      if e.missing then
        row.who:SetText(T.Hex(C.amber) .. (e.pn or "") .. "|r")
      else
        local online = 0
        for _, n in ipairs(e.crafters) do if DR.Guild:IsOnline(n) then online = online + 1 end end
        local txt = T.Hex(C.muted) .. (e.pn or "") .. "|r  " .. #e.crafters .. " artisan" .. (#e.crafters > 1 and "s" or "")
        if online > 0 then txt = txt .. T.Hex(C.teal) .. " · " .. online .. " en ligne|r" end
        row.who:SetText(txt)
      end
      row.sel:SetShown(self.selectedRecipe == e.id)
    end,
    click = function(e) self.selectedRecipe = e.id; self.selectedCrafter = nil; self:RefreshQui() end,
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
  d.prof = T.Text(body, "caps", 11, C.brume)
  d.prof:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10)
  d.sub = T.Text(body, "semi", 12, C.goldPale)
  d.sub:SetPoint("TOPLEFT", d.prof, "BOTTOMLEFT", 0, -14)
  d.crafters = W.List(body, {
    width = dw - 2 * pad, height = listH - 230, rowHeight = 22,
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
  d.crafters:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -8)

  d.note = W.Edit(body, dw - 2 * pad, 26, "Petit mot pour l'artisan (composants fournis…)", 200)
  d.note:SetPoint("BOTTOMLEFT", pad, pad + 40)
  d.ask = W.Button(body, "Demander", "gold", 170, 32)
  d.ask:SetPoint("BOTTOMLEFT", pad, pad)
  d.ask:SetScript("OnClick", function() self:AskCraft() end)
  d.whisper = W.Button(body, "Chuchoter", "slate", 120, 32)
  d.whisper:SetPoint("LEFT", d.ask, "RIGHT", 8, 0)
  d.whisper:SetScript("OnClick", function()
    if self.selectedCrafter then Util.Whisper(self.selectedCrafter) end
  end)
  d.wish = W.Button(body, "La guilde la cherche", "gold", 200, 32)
  d.wish:SetPoint("BOTTOMLEFT", pad, pad)
  d.wish:SetScript("OnClick", function()
    local e = self:SelectedEntry()
    if not e then return end
    local rec, msg = Crafts:Wish({ sp = e.id > 0 and e.id or nil, it = e.id < 0 and -e.id or nil, nm = e.name },
      { id = e.p, name = e.pn })
    UI:Toast(msg or (rec and "Ajoutée aux recettes recherchées." or "Impossible d'ajouter."), rec and "ok" or "warn")
  end)
end

function Tab:SelectedEntry()
  if not self.selectedRecipe then return nil end
  for _, e in ipairs(self.quiItems or {}) do
    if e.id == self.selectedRecipe then return e end
  end
  return nil
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

function Tab:RefreshQui()
  if not self.recipes then return end
  local profName = "tous"
  for _, pr in ipairs(Crafts:Professions()) do if pr.id == self.prof then profName = pr.name end end
  self.profBtn:SetLabel("Métier : " .. profName)
  local missingCount = #Crafts:Index().missing
  self.modeChips:SetLabel("missing", "Personne ne l'a  " .. missingCount)
  local items = Crafts:Search(self.search:GetText(), self.prof, self.mode)
  self.quiItems = items
  if self.mode == "missing" then
    self.recipes:SetEmptyText(missingCount == 0
      and "Rien à montrer : la liste se remplit quand un artisan ouvre sa fenêtre de métier avec l'add-on."
      or "Aucune recette ne correspond.")
  else
    self.recipes:SetEmptyText(Crafts:Index().list[1] == nil
      and "Pas encore de recettes. Chaque artisan n'a qu'à ouvrir sa fenêtre de métier une fois : ses recettes sont lues et partagées toutes seules."
      or "Aucune recette ne correspond.")
  end
  self.recipes:SetItems(items, true)

  local d = self.quiDetail
  local e = self:SelectedEntry()
  if not e then
    d.body:Hide(); d.empty:Show()
    d.empty:SetText("Cherche un objet, un enchantement ou une potion : tu vois qui sait le faire, qui est en ligne, et tu peux lui demander en un clic.")
    return
  end
  d.empty:Hide(); d.body:Show()
  d.icon:SetTexture(Crafts:RecipeIcon(e.id) or 134400)
  d.name:SetText(e.name)
  d.prof:SetText((e.pn or ""):upper())
  if e.missing then
    d.sub:SetText(T.Hex(C.amber) .. "Personne dans la guilde ne connaît cette recette.|r")
    d.crafters:SetItems({})
    d.crafters:SetEmptyText("Ajoute-la aux recettes recherchées : la guilde saura qu'il faut l'acheter, la trouver ou la faire apprendre.")
    d.note:Hide(); d.ask:Hide(); d.whisper:Hide(); d.wish:Show()
  else
    local crafters = Crafts:CraftersOf(e.id)
    d.sub:SetText("Artisans (" .. #crafters .. ")")
    if not self.selectedCrafter and crafters[1] then
      for _, c in ipairs(crafters) do
        if not DR.Profile:IsMine(c.name) then self.selectedCrafter = c.name; break end
      end
    end
    d.crafters:SetEmptyText(nil)
    d.crafters:SetItems(crafters, true)
    d.note:Show(); d.ask:Show(); d.whisper:Show(); d.wish:Hide()
    local who = self.selectedCrafter and Util.ShortName(self.selectedCrafter) or "…"
    d.ask:SetLabel("Demander à " .. who)
    d.ask:SetEnabled(self.selectedCrafter ~= nil and not DR.Profile:IsMine(self.selectedCrafter))
    d.whisper:SetEnabled(self.selectedCrafter ~= nil and not DR.Profile:IsMine(self.selectedCrafter))
  end
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
      if ChatEdit_InsertLink then ChatEdit_InsertLink(o.link) end
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
  if not DR.Store:IsReady() then
    self.recipes:SetEmptyText(IsInGuild() and "Chargement de la guilde…" or "Rejoins la guilde pour voir ses artisans.")
    self.recipes:SetItems({})
    return
  end
  self:RefreshWishes()
  self:RefreshOrders()
  if self.view == "qui" then self:RefreshQui() end
end
