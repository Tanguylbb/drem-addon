-- Artisans de la guilde : qui sait fabriquer quoi, recettes que la guilde
-- cherche, commandes de fabrication.
--
-- Recettes d'un perso ("recipes") : c (perso), p (métier), pn (nom du métier),
--   lv/mx (niveau du métier), l (liste des recettes apprises : identifiants
--   de sort ; un nombre négatif désigne un objet quand le sort est inconnu)
-- Catalogue d'un métier ("catalog") : p, pn, l (toutes les recettes vues,
--   apprises ou non, quand le jeu les montre), g (les mêmes rangées par type
--   de craft : liste de { n = nom du type, l = identifiants })
-- Commande ("orders") :
--   k = "recette" : la guilde cherche une recette (cherchee, trouvee, apprise, abandonnee)
--   k = "craft"   : demande de fabrication à un artisan (demandee, acceptee, faite, annulee)
--   id, sp (sort), it (objet), link, nm (nom), p/pn (métier), req (demandeur),
--   to (artisan visé), s (statut), m (mot), who (qui l'a apprise ou faite)
-- Soutien ("votes") : o (commande), c (perso) — « moi aussi ».

local _, DR = ...
local Crafts = DR:NewModule("Crafts")
local Util, Store = DR.Util, DR.Store

Crafts.WISH_STATUS = {
  cherchee = { label = "La guilde cherche", color = "F4A95C", order = 1 },
  trouvee = { label = "Trouvée, à apprendre", color = "F1D796", order = 2 },
  apprise = { label = "Apprise", color = "72D3C6", order = 3 },
  abandonnee = { label = "Abandonnée", color = "9AA6BA", order = 4 },
}
Crafts.CRAFT_STATUS = {
  demandee = { label = "Demandée", color = "F4A95C", order = 1 },
  acceptee = { label = "Acceptée", color = "F1D796", order = 2 },
  faite = { label = "Faite", color = "72D3C6", order = 3 },
  annulee = { label = "Annulée", color = "9AA6BA", order = 4 },
}

---------------------------------------------------------------------------
-- Noms et icônes des recettes
---------------------------------------------------------------------------
local nameCache = {}

function Crafts:RecipeName(id)
  if not id then return "?" end
  local cached = nameCache[id]
  if cached then return cached end
  local name
  if id < 0 then
    local item = -id
    if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(item) end
    if not name and GetItemInfo then name = GetItemInfo(item) end
  else
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id) end
    if not name and GetSpellInfo then name = GetSpellInfo(id) end
  end
  if name then nameCache[id] = name end
  return name or ("Recette " .. tostring(id))
end

function Crafts:RecipeIcon(id)
  if not id then return nil end
  if id < 0 then
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(-id) end
    return GetItemIcon and GetItemIcon(-id)
  end
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  return GetSpellTexture and GetSpellTexture(id)
end

-- Affiche l'infobulle d'une recette sur `owner`.
function Crafts:ShowTooltip(owner, id, link)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if link and link:find("|H", 1, true) then
    pcall(GameTooltip.SetHyperlink, GameTooltip, link:match("|H(.-)|h") or link)
  elseif id and id < 0 then
    pcall(GameTooltip.SetItemByID, GameTooltip, -id)
  elseif id then
    pcall(GameTooltip.SetSpellByID, GameTooltip, id)
  end
  GameTooltip:Show()
end

function Crafts:ProfessionName(pid, fallback)
  return fallback or DR.Profile.PROFESSIONS[pid] or ("Métier " .. tostring(pid))
end

---------------------------------------------------------------------------
-- Lecture des recettes dans la fenêtre de métier
---------------------------------------------------------------------------
local function sortedUnique(list)
  local seen, out = {}, {}
  for _, v in ipairs(list) do
    if not seen[v] then seen[v] = true; out[#out + 1] = v end
  end
  table.sort(out)
  return out
end

-- Type de craft d'une recette (« Sacs », « Robes »…), tel que la fenêtre de
-- métier du jeu le range.
local categoryNames = {}
local function categoryName(T, categoryID)
  if not categoryID or not T.GetCategoryInfo then return nil end
  local hit = categoryNames[categoryID]
  if hit ~= nil then return hit or nil end
  local ok, info = pcall(T.GetCategoryInfo, categoryID)
  local name = ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" and info.name or nil
  categoryNames[categoryID] = name or false
  return name
end

local function scanModern()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo) then return nil end
  if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return false end
  if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return false end
  if T.IsNPCCrafting and T.IsNPCCrafting() then return false end
  if T.IsTradeSkillReady and not T.IsTradeSkillReady() then return false end
  local pid, pname, lv, mx
  local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
  if base and base.professionID then
    pid, pname, lv, mx = base.professionID, base.professionName, base.skillLevel, base.maxSkillLevel
  end
  local child = T.GetChildProfessionInfo and T.GetChildProfessionInfo()
  if child and child.skillLevel and child.skillLevel > 0 then
    lv, mx = child.skillLevel, child.maxSkillLevel
  end
  if not pid and T.GetTradeSkillLine then
    local id, name, rank, maxRank = T.GetTradeSkillLine()
    pid, pname, lv, mx = id, name, rank, maxRank
  end
  if not pid then return false end
  local learned, all, byType = {}, {}, {}
  for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
    local info = T.GetRecipeInfo(id)
    if info then
      all[#all + 1] = id
      if info.learned then learned[#learned + 1] = id end
      local cname = categoryName(T, info.categoryID) or "Autres"
      byType[cname] = byType[cname] or {}
      table.insert(byType[cname], id)
    end
  end
  local groups = {}
  for name, ids in pairs(byType) do groups[#groups + 1] = { n = name, l = sortedUnique(ids) } end
  table.sort(groups, function(a, b) return a.n < b.n end)
  return { p = pid, pn = pname, lv = lv, mx = mx, l = sortedUnique(learned), all = sortedUnique(all), groups = groups }
end

local function idFromLink(link)
  if not link then return nil end
  local spell = link:match("|Henchant:(%d+)") or link:match("|Hspell:(%d+)")
  if spell then return tonumber(spell) end
  local item = link:match("|Hitem:(%d+)")
  if item then return -tonumber(item) end
  return nil
end

local function professionId(name)
  for id, label in pairs(DR.Profile.PROFESSIONS) do
    if label == name then return id end
  end
  for _, p in ipairs((DR.db.myChars[DR.playerName] or {}).p or {}) do
    if p.nm == name then return p.id end
  end
  return nil
end

-- Clients à l'ancienne (fenêtre de métier et fenêtre d'enchantement).
local function scanClassic(kind)
  local learned = {}
  local pname, lv, mx
  if kind == "craft" and GetNumCrafts then
    if GetCraftDisplaySkillLine then pname, lv, mx = GetCraftDisplaySkillLine() end
    for i = 1, GetNumCrafts() do
      local _, _, ctype = GetCraftInfo(i)
      if ctype ~= "header" then
        local id = idFromLink(GetCraftItemLink and GetCraftItemLink(i))
        if id then learned[#learned + 1] = id end
      end
    end
  elseif GetNumTradeSkills then
    pname, lv, mx = GetTradeSkillLine()
    for i = 1, GetNumTradeSkills() do
      local _, ttype = GetTradeSkillInfo(i)
      if ttype ~= "header" and ttype ~= "subheader" then
        local id = idFromLink(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i))
          or idFromLink(GetTradeSkillItemLink and GetTradeSkillItemLink(i))
        if id then learned[#learned + 1] = id end
      end
    end
  end
  if not pname or pname == "UNKNOWN" or #learned == 0 then return false end
  local pid = professionId(pname) or Store.Hash(pname) % 100000 + 100000
  return { p = pid, pn = pname, lv = lv, mx = mx, l = sortedUnique(learned) }
end

function Crafts:SaveScan(scan)
  if not scan or not scan.p then return end
  local me = DR.playerName
  local mine = DR.db.myChars[me]
  if mine then
    mine.recipes = mine.recipes or {}
    mine.recipes[tostring(scan.p)] = { p = scan.p, pn = scan.pn, n = #scan.l, at = Util.Now() }
    DR:Emit("PROFILE_UPDATED", "recettes")
  end
  if not (IsInGuild() and Store:IsReady()) then return end
  local written = Store:Put("recipes", { c = me, p = scan.p, pn = scan.pn, lv = scan.lv, mx = scan.mx, l = scan.l })
  if scan.all and #scan.all > 0 then
    local cat = Store:Get("catalog", tostring(scan.p))
    -- Un catalogue plus complet, ou le premier rangé par type de craft, remplace l'ancien.
    if not cat or #(cat.l or {}) < #scan.all or (scan.groups and not cat.g) then
      Store:Put("catalog", { p = scan.p, pn = scan.pn, l = scan.all, g = scan.groups })
    end
  end
  self:AutoLearn(scan.l)
  if written then
    DR:Print(string.format("%s : %d recettes lues et partagées avec la guilde.", scan.pn or "Métier", #scan.l))
  end
end

function Crafts:Scan(kind)
  local scan = scanModern()
  if scan == nil then scan = scanClassic(kind) end
  if scan then self:SaveScan(scan) end
end

function Crafts:OnLogin()
  local scanSoon = DR.Debounce(1.5, function() self:Scan("trade") end)
  for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
    pcall(DR.On, DR, ev, scanSoon)
  end
  local craftSoon = DR.Debounce(1.5, function() self:Scan("craft") end)
  for _, ev in ipairs({ "CRAFT_SHOW", "CRAFT_UPDATE" }) do pcall(DR.On, DR, ev, craftSoon) end

  DR:Listen("DATA_CHANGED", function(ds, _, rec, old, origin)
    if ds == "recipes" or ds == "chars" or ds == "catalog" then self.index = nil end
    if ds == "orders" and origin == "remote" and rec and not rec.del then self:NotifyOrder(rec, old) end
  end)
  DR:Listen("STORE_BOUND", function() self.index = nil end)
end

---------------------------------------------------------------------------
-- Index « qui sait faire quoi »
---------------------------------------------------------------------------
function Crafts:BuildIndex()
  local byId, list, profs = {}, {}, {}
  for _, r in ipairs(Store:List("recipes")) do
    profs[r.p] = r.pn or profs[r.p]
    for _, id in ipairs(r.l or {}) do
      local e = byId[id]
      if not e then
        e = { id = id, p = r.p, pn = r.pn, crafters = {} }
        byId[id] = e
        list[#list + 1] = e
      end
      e.crafters[#e.crafters + 1] = r.c
    end
  end
  local missing, typeOf = {}, {}
  for _, cat in ipairs(Store:List("catalog")) do
    profs[cat.p] = profs[cat.p] or cat.pn
    for _, g in ipairs(type(cat.g) == "table" and cat.g or {}) do
      if type(g) == "table" and type(g.l) == "table" then
        for _, id in ipairs(g.l) do typeOf[id] = g.n end
      end
    end
    for _, id in ipairs(cat.l or {}) do
      if not byId[id] then
        missing[#missing + 1] = { id = id, p = cat.p, pn = cat.pn, crafters = {}, missing = true }
      end
    end
  end
  for _, e in ipairs(list) do e.cat = typeOf[e.id] end
  for _, e in ipairs(missing) do e.cat = typeOf[e.id] end
  self.index = { byId = byId, list = list, missing = missing, profs = profs, typeOf = typeOf }
  return self.index
end

function Crafts:Index()
  return self.index or self:BuildIndex()
end

local function decorate(e)
  if not e.name then
    e.name = Crafts:RecipeName(e.id)
    e.folded = Util.Fold(e.name)
  end
  return e
end

-- mode : "known" (quelqu'un sait la faire) ou "missing" (personne).
function Crafts:Search(text, prof, mode)
  local idx = self:Index()
  local source = (mode == "missing") and idx.missing or idx.list
  local q = Util.Fold(Util.Trim(text or ""))
  local out = {}
  for _, e in ipairs(source) do
    if not prof or e.p == prof then
      decorate(e)
      if q == "" or e.folded:find(q, 1, true) then out[#out + 1] = e end
    end
  end
  table.sort(out, function(a, b) return a.folded < b.folded end)
  return out
end

function Crafts:Professions()
  local out = {}
  for id, name in pairs(self:Index().profs) do
    out[#out + 1] = { id = id, name = self:ProfessionName(id, name) }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Artisans d'une recette : en ligne d'abord.
function Crafts:CraftersOf(id)
  local e = self:Index().byId[id]
  local out = {}
  if not e then return out end
  for _, name in ipairs(e.crafters) do
    out[#out + 1] = { name = name, online = DR.Guild:IsOnline(name), class = DR.Profile:ClassOf(name) }
  end
  table.sort(out, function(a, b)
    if a.online ~= b.online then return a.online end
    return a.name < b.name
  end)
  return out
end

function Crafts:WhoKnows(id)
  local e = self:Index().byId[id]
  return e and e.crafters or {}
end

---------------------------------------------------------------------------
-- Toute la liste d'un métier, rangée par type de craft
---------------------------------------------------------------------------
-- Toutes les recettes connues d'un métier : celles que des artisans savent
-- faire et celles que personne n'a apprises (vues dans une fenêtre de métier).
function Crafts:Entries(pid)
  local idx = self:Index()
  local out, seen = {}, {}
  for _, e in ipairs(idx.list) do
    if e.p == pid then seen[e.id] = true; out[#out + 1] = e end
  end
  for _, e in ipairs(idx.missing) do
    if e.p == pid and not seen[e.id] then out[#out + 1] = e end
  end
  return out
end

-- Recettes de ce métier que l'un de MES persos sait faire.
function Crafts:MyKnown(pid)
  local set = {}
  for _, r in ipairs(Store:List("recipes", function(r) return r.p == pid end)) do
    if DR.Profile:IsMine(r.c) then
      for _, id in ipairs(r.l or {}) do set[id] = true end
    end
  end
  return set
end

-- filter : "all", "lacking" (aucun de mes persos ne la sait), "nobody" (personne ne la sait).
-- Rend la liste des types de craft : { name, entries, total, nobody }.
function Crafts:Tree(pid, filter, text)
  local q = Util.Fold(Util.Trim(text or ""))
  local mine = self:MyKnown(pid)
  local byName, groups = {}, {}
  for _, e in ipairs(self:Entries(pid)) do
    decorate(e)
    local name = e.cat or "Autres"
    local g = byName[name]
    if not g then
      g = { name = name, entries = {}, total = 0, nobody = 0 }
      byName[name] = g
      groups[#groups + 1] = g
    end
    g.total = g.total + 1
    local nobody = #e.crafters == 0
    local keep = filter == "all" or (filter == "lacking" and not mine[e.id]) or (filter == "nobody" and nobody)
    if keep and (q == "" or e.folded:find(q, 1, true)) then
      g.entries[#g.entries + 1] = e
      if nobody then g.nobody = g.nobody + 1 end
    end
  end
  local out = {}
  for _, g in ipairs(groups) do
    if #g.entries > 0 then
      table.sort(g.entries, function(a, b) return a.folded < b.folded end)
      out[#out + 1] = g
    end
  end
  table.sort(out, function(a, b)
    if (a.name == "Autres") ~= (b.name == "Autres") then return b.name == "Autres" end
    return Util.Fold(a.name) < Util.Fold(b.name)
  end)
  return out
end

-- Combien de recettes dans le catalogue du métier, lu par combien de membres.
function Crafts:CatalogInfo(pid)
  local n = #self:Entries(pid)
  local readers = #Store:List("recipes", function(r) return r.p == pid end)
  local members = #Store:List("chars", function(c)
    for _, p in ipairs(c.p or {}) do if p.id == pid then return true end end
    return false
  end)
  return { recipes = n, readers = readers, members = members }
end

-- Membres qui ont ce métier mais n'ont pas encore partagé leurs recettes.
function Crafts:Unshared(pid)
  local out = {}
  for _, c in ipairs(Store:List("chars")) do
    for _, p in ipairs(c.p or {}) do
      if p.id == pid and not Store:Get("recipes", c.n .. "|" .. tostring(pid)) then
        out[#out + 1] = { name = c.n, lv = p.lv or 0 }
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Qui, dans la guilde, a le métier et pourrait l'apprendre (il ne la sait pas encore).
function Crafts:CouldLearn(e)
  local known = {}
  for _, n in ipairs(e.crafters or {}) do known[n] = true end
  local out = {}
  for _, c in ipairs(Store:List("chars")) do
    if not known[c.n] then
      for _, p in ipairs(c.p or {}) do
        if p.id == e.p then out[#out + 1] = { name = c.n, lv = p.lv or 0 } end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.lv ~= b.lv then return a.lv > b.lv end
    return a.name < b.name
  end)
  return out
end

---------------------------------------------------------------------------
-- « +1 » : je voudrais que la guilde achète cette recette
---------------------------------------------------------------------------
-- Pour chaque recette cherchée : recette -> { order, n (soutiens), mine }.
function Crafts:WantMap()
  local counts, mine = {}, {}
  for _, v in ipairs(Store:List("votes")) do
    counts[v.o] = (counts[v.o] or 0) + 1
    if DR.Profile:IsMine(v.c) then mine[v.o] = true end
  end
  local map = {}
  for _, o in ipairs(Store:List("orders", function(o)
    return o.k == "recette" and (o.s == "cherchee" or o.s == "trouvee")
  end)) do
    local id = o.sp or (o.it and -o.it)
    if id then map[id] = { order = o, n = counts[o.id] or 0, mine = mine[o.id] or false } end
  end
  return map
end

function Crafts:Wanters(orderId)
  local out = {}
  for _, v in ipairs(Store:List("votes", function(v) return v.o == orderId end)) do out[#out + 1] = v.c end
  table.sort(out)
  return out
end

-- +1 ou retirer mon +1. Crée la recette recherchée s'il n'y en a pas encore.
-- Rend l'ordre et vrai si j'ai maintenant mon +1.
function Crafts:ToggleWant(e)
  local current = self:WantMap()[e.id]
  if current then
    self:Vote(current.order.id, not current.mine)
    return current.order, not current.mine
  end
  local rec, msg = self:Wish({ sp = e.id > 0 and e.id or nil, it = e.id < 0 and -e.id or nil, nm = e.name },
    { id = e.p, name = e.pn })
  if not rec then return nil, false, msg end
  return rec, true
end

-- « Où la trouver » : renseigné par n'importe quel membre.
function Crafts:SetWhere(orderId, text)
  local o = Store:Get("orders", orderId)
  if not o then return false end
  text = Util.Trim(text or "")
  local rec = Util.Copy(o)
  if text == "" then rec.wh, rec.wb = nil, nil else rec.wh, rec.wb = Util.Truncate(text, 120), DR.playerName end
  Store:Put("orders", rec)
  return true
end

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------
function Crafts:NewId()
  return "o" .. Util.ToBase36(Util.Now()) .. Util.RandomId(3)
end

-- Lit ce qu'on a tapé ou collé : un lien du jeu ou un simple nom.
function Crafts.ParseWishInput(text)
  text = Util.Trim(text)
  if text == "" then return nil end
  local link = text:match("(|c%x+|H.-|h.-|h|r)") or text:match("(|H.-|h.-|h)")
  local kind, id = Util.LinkInfo(link or text)
  local out = { link = link, nm = link and Util.LinkName(link) or Util.Truncate(text, 120) }
  if kind == "spell" or kind == "enchant" then out.sp = id end
  if kind == "item" then out.it = id end
  return out
end

function Crafts:Wish(input, prof, note)
  local parsed = type(input) == "table" and input or Crafts.ParseWishInput(input)
  if not parsed then return nil, "Colle un lien (Maj+clic sur la recette) ou tape son nom." end
  if parsed.sp and #self:WhoKnows(parsed.sp) > 0 then
    return nil, "Quelqu'un de la guilde sait déjà la faire : regarde « Qui sait faire quoi »."
  end
  -- Déjà demandée ? On soutient la demande existante.
  for _, o in ipairs(Store:List("orders", function(o) return o.k == "recette" and o.s ~= "abandonnee" end)) do
    if (parsed.sp and o.sp == parsed.sp) or (parsed.it and o.it == parsed.it)
      or (not parsed.sp and not parsed.it and Util.Fold(o.nm or "") == Util.Fold(parsed.nm or "")) then
      self:Vote(o.id, true)
      return o, "Déjà recherchée : ton soutien est ajouté."
    end
  end
  local pid = prof and prof.id or nil
  local rec = Store:Put("orders", {
    id = self:NewId(), k = "recette", sp = parsed.sp, it = parsed.it, link = parsed.link,
    nm = parsed.nm or (parsed.sp and self:RecipeName(parsed.sp)) or "?",
    p = pid, pn = prof and prof.name or nil,
    req = DR.playerName, s = "cherchee",
    m = (note and note ~= "") and Util.Truncate(note, 200) or nil,
  })
  if rec then self:Vote(rec.id, true) end
  return rec
end

function Crafts:RequestCraft(recipeId, crafter, note)
  if not recipeId or not crafter then return nil, "Choisis une recette et un artisan." end
  local e = self:Index().byId[recipeId]
  return Store:Put("orders", {
    id = self:NewId(), k = "craft", sp = recipeId > 0 and recipeId or nil,
    it = recipeId < 0 and -recipeId or nil, nm = self:RecipeName(recipeId),
    p = e and e.p, pn = e and e.pn, req = DR.playerName, to = crafter, s = "demandee",
    m = (note and note ~= "") and Util.Truncate(note, 200) or nil,
  })
end

function Crafts:CanEdit(order)
  if not order then return false end
  if DR.Guild:IAmOfficer() then return true end
  if DR.Profile:IsMine(order.req) then return true end
  if order.to and DR.Profile:IsMine(order.to) then return true end
  if order.k == "recette" then return true end -- tout le monde peut dire « trouvée »
  return false
end

function Crafts:SetOrderStatus(id, status, who)
  local o = Store:Get("orders", id)
  if not o or not self:CanEdit(o) then return false end
  local rec = Util.Copy(o)
  rec.s = status
  if who then rec.who = who end
  if (status == "apprise" or status == "faite") and not rec.who then rec.who = DR.playerName end
  Store:Put("orders", rec)
  return true
end

function Crafts:DeleteOrder(id)
  local o = Store:Get("orders", id)
  if not o then return false end
  if not (DR.Guild:IAmOfficer() or DR.Profile:IsMine(o.req)) then return false end
  Store:Delete("orders", id)
  return true
end

function Crafts:Vote(orderId, on)
  if on then
    Store:Put("votes", { o = orderId, c = DR.playerName })
  else
    for _, v in ipairs(Store:List("votes", function(v) return v.o == orderId end)) do
      if DR.Profile:IsMine(v.c) then Store:Delete("votes", Store.KeyOf("votes", v)) end
    end
  end
end

function Crafts:Votes(orderId)
  local n, mine = 0, false
  for _, v in ipairs(Store:List("votes", function(v) return v.o == orderId end)) do
    n = n + 1
    if DR.Profile:IsMine(v.c) then mine = true end
  end
  return n, mine
end

-- kind : "recette" ou "craft" ; filter : "all", "mine" (mes demandes), "forme" (pour moi)
function Crafts:Orders(kind, filter)
  local statuses = kind == "craft" and Crafts.CRAFT_STATUS or Crafts.WISH_STATUS
  local list = Store:List("orders", function(o)
    if o.k ~= kind then return false end
    if filter == "mine" then return DR.Profile:IsMine(o.req) end
    if filter == "forme" then return o.to ~= nil and DR.Profile:IsMine(o.to) end
    return true
  end)
  local votes = {}
  for _, o in ipairs(list) do votes[o.id] = self:Votes(o.id) end
  table.sort(list, function(a, b)
    local sa, sb = statuses[a.s] and statuses[a.s].order or 9, statuses[b.s] and statuses[b.s].order or 9
    if sa ~= sb then return sa < sb end
    if votes[a.id] ~= votes[b.id] then return votes[a.id] > votes[b.id] end
    return (a.u or 0) > (b.u or 0)
  end)
  return list, votes
end

-- Quand j'apprends une recette que la guilde cherchait, je ferme la demande.
function Crafts:AutoLearn(learned)
  local set = {}
  for _, id in ipairs(learned or {}) do set[id] = true end
  for _, o in ipairs(Store:List("orders", function(o)
    return o.k == "recette" and (o.s == "cherchee" or o.s == "trouvee") and o.sp
  end)) do
    if set[o.sp] then
      local rec = Util.Copy(o)
      rec.s, rec.who = "apprise", DR.playerName
      Store:Put("orders", rec)
      DR:Print("tu as appris « " .. (o.nm or "?") .. " », que la guilde cherchait. Merci !")
    end
  end
end

function Crafts:NotifyOrder(rec, old)
  if rec.k ~= "craft" or not rec.to or not DR.Profile:IsMine(rec.to) then
    if rec.k == "craft" and DR.Profile:IsMine(rec.req) and old and old.s ~= rec.s then
      local st = Crafts.CRAFT_STATUS[rec.s]
      if st then DR:Print(string.format("ta commande « %s » : %s.", rec.nm or "?", st.label:lower())) end
    end
    return
  end
  if rec.s == "demandee" and (not old or old.del) then
    DR:Print(string.format("%s te demande : %s. /rempart artisans", Util.ShortName(rec.req), rec.nm or "?"))
  end
end
