-- Artisans de la guilde : qui sait fabriquer quoi, recettes que la guilde
-- cherche, commandes de fabrication.
--
-- Recettes d'un perso ("recipes") : c (perso), p (métier), pn (nom du métier),
--   lv/mx (niveau du métier), l (liste des recettes apprises : identifiants
--   de sort ; un nombre négatif désigne un objet quand le sort est inconnu)
-- Catalogue d'un métier ("catalog") : p, pn, l (toutes les recettes vues,
--   apprises ou non, quand le jeu les montre)
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
  local learned, all = {}, {}
  for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
    local info = T.GetRecipeInfo(id)
    if info then
      all[#all + 1] = id
      if info.learned then learned[#learned + 1] = id end
    end
  end
  return { p = pid, pn = pname, lv = lv, mx = mx, l = sortedUnique(learned), all = sortedUnique(all) }
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
    mine.recipes[tostring(scan.p)] = { p = scan.p, pn = scan.pn, n = #scan.l }
  end
  if not (IsInGuild() and Store:IsReady()) then return end
  local written = Store:Put("recipes", { c = me, p = scan.p, pn = scan.pn, lv = scan.lv, mx = scan.mx, l = scan.l })
  if scan.all and #scan.all > 0 then
    local cat = Store:Get("catalog", tostring(scan.p))
    if not cat or #(cat.l or {}) < #scan.all then
      Store:Put("catalog", { p = scan.p, pn = scan.pn, l = scan.all })
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
  local missing = {}
  for _, cat in ipairs(Store:List("catalog")) do
    profs[cat.p] = profs[cat.p] or cat.pn
    for _, id in ipairs(cat.l or {}) do
      if not byId[id] then
        missing[#missing + 1] = { id = id, p = cat.p, pn = cat.pn, crafters = {}, missing = true }
      end
    end
  end
  self.index = { byId = byId, list = list, missing = missing, profs = profs }
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
