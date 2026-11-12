-- Effort de guerre : des objectifs fixés par les officiers (une somme d'or,
-- ou des objets pour un raid) et les dons des membres, lus dans le journal de
-- la banque de guilde ou déclarés à la main.
--
-- Objectif ("goals") :
--   id, t (titre), k ("or" | "objet"), amt (cible : cuivres pour l'or, quantité
--   pour un objet), it (identifiant de l'objet), nm (nom de l'objet), tag
--   (petite étiquette, « Cœur du Magma »), from (début), to (fin, facultative),
--   st ("open" | "closed")
-- Don ("gifts") :
--   id, c (qui), k ("or" | "objet"), a (cuivres ou quantité), it, nm, at (quand,
--   à l'heure près), src ("bank" | "hand"), rd (qui l'a lu dans la banque),
--   tab (onglet de la banque), g (objectif choisi à la main ; "-" : ne compte
--   pour aucun), n (petit mot)
-- Réglages ("meta") :
--   id = "effort", vis = "all" | "officers" : qui voit les noms et les montants
--   id = "bank", at, by, n, nw : dernière lecture du journal de la banque
--
-- Le journal de la banque donne l'heure d'un mouvement par « il y a N heures » :
-- deux membres qui lisent le même journal peuvent estimer l'heure à une heure
-- près. Chaque lecteur garde donc ses propres lignes (champ rd), et au calcul
-- les lignes identiques proches dans le temps ne comptent qu'une fois par
-- lecteur le plus complet.

local _, DR = ...
local Effort = DR:NewModule("Effort")
local Util, Store = DR.Util, DR.Store

local HOUR, DAY = 3600, 86400

---------------------------------------------------------------------------
-- Objectifs
---------------------------------------------------------------------------
function Effort:NewId(prefix)
  return prefix .. Util.ToBase36(Util.Now()) .. Util.RandomId(4)
end

-- view : "open" (en cours), "closed" (terminés : fermés ou atteints).
function Effort:Goals(view)
  local snap = self:Snapshot()
  local out = {}
  for _, g in ipairs(snap.goals) do
    local p = snap.progress[g.id]
    local finished = g.st == "closed" or p.status == "done"
    if (view == "closed") == finished then out[#out + 1] = g end
  end
  return out
end

-- Crée ou modifie un objectif (officiers). f : t, k, amt (texte), item (lien),
-- tag, from, to (JJ/MM ou JJ/MM/AAAA). Rend l'objectif, ou nil et la raison.
function Effort:SaveGoal(f)
  if not DR.Guild:IAmOfficer() then return nil, "Réservé aux officiers." end
  if not Store:IsReady() then return nil, "Pas de guilde chargée." end
  local t = Util.Trim(f.t)
  if t == "" then return nil, "Donne un titre à l'objectif." end
  local old = f.id and Store:Get("goals", f.id)
  local rec = {
    id = f.id or self:NewId("e"), t = Util.Truncate(t, 80), k = f.k == "objet" and "objet" or "or",
    tag = Util.Trim(f.tag or "") ~= "" and Util.Truncate(Util.Trim(f.tag), 40) or nil,
    st = (old and old.st) or "open",
  }
  if rec.k == "or" then
    local copper = Util.ParseGold(f.amt)
    if not copper or copper <= 0 then return nil, "Montant invalide : écris par exemple 200 po." end
    rec.amt = copper
  else
    local n = tonumber(Util.Trim(f.amt or ""))
    if not n or n < 1 or n ~= math.floor(n) then return nil, "Quantité invalide : écris un nombre entier." end
    rec.amt = n
    local kind, id = Util.LinkInfo(f.item)
    if kind ~= "item" or not id then return nil, "Colle le lien de l'objet (Maj+clic) dans le champ Objet." end
    rec.it, rec.nm = id, Util.LinkName(f.item)
  end
  local now = Util.Now()
  if Util.Trim(f.from or "") ~= "" then
    rec.from = Util.ParseDateTime(f.from, "00:00")
    if not rec.from then return nil, "Début invalide (JJ/MM)." end
  else
    rec.from = (old and old.from) or now
  end
  if Util.Trim(f.to or "") ~= "" then
    rec.to = Util.ParseDateTime(f.to, "23:59")
    if not rec.to then return nil, "Date de fin invalide (JJ/MM)." end
    if rec.to < rec.from then return nil, "La fin est avant le début." end
  end
  Store:Put("goals", rec)
  DR:Emit("EFFORT_CHANGED")
  return rec
end

-- Fermer arrête de compter les nouveaux dons : la date de fin devient maintenant.
function Effort:SetGoalStatus(id, st)
  if not DR.Guild:IAmOfficer() then return false end
  local g = Store:Get("goals", id)
  if not g then return false end
  local rec = Util.Copy(g)
  rec.st = st
  if st == "closed" then
    local now = Util.Now()
    if not rec.to or rec.to > now then rec.to = now end
  end
  Store:Put("goals", rec)
  DR:Emit("EFFORT_CHANGED")
  return true
end

function Effort:DeleteGoal(id)
  if not DR.Guild:IAmOfficer() then return false end
  Store:Delete("goals", id)
  DR:Emit("EFFORT_CHANGED")
  return true
end

---------------------------------------------------------------------------
-- Dons : lignes de la banque regroupées, rattachées à un objectif
---------------------------------------------------------------------------
local function tolerance(now, at)
  -- Au-delà de 25 jours, le journal ne donne plus l'heure qu'à un jour près.
  return (now - at) > 25 * DAY and 3 * DAY or 2 * HOUR
end

local function giftKey(r)
  return tostring(r.c or "?") .. "|" .. tostring(r.k or "") .. "|" .. tostring(r.a) .. "|" .. tostring(r.it or "")
end

-- Les dons sans doublon : une ligne de la banque lue par plusieurs membres ne
-- compte qu'une fois.
function Effort:GiftList()
  local now = Util.Now()
  local out, bank = {}, {}
  for _, r in ipairs(Store:List("gifts")) do
    if r.src == "bank" then
      local key = giftKey(r)
      bank[key] = bank[key] or {}
      table.insert(bank[key], r)
    else
      out[#out + 1] = { c = r.c, k = r.k, a = r.a or 0, it = r.it, nm = r.nm, at = r.at or r.u or 0,
        src = "hand", g = r.g, n = r.n, recs = { r }, id = r.id }
    end
  end
  for _, list in pairs(bank) do
    table.sort(list, function(a, b) return (a.at or 0) < (b.at or 0) end)
    local cluster
    local function flush()
      if not cluster then return end
      local perReader, count, explicit = {}, 0, nil
      for _, r in ipairs(cluster.recs) do
        local who = r.rd or r.by or "?"
        perReader[who] = (perReader[who] or 0) + 1
        if perReader[who] > count then count = perReader[who] end
        if r.g and not explicit then explicit = r.g end
      end
      local first = cluster.recs[1]
      for i = 1, count do
        out[#out + 1] = { c = first.c, k = first.k, a = first.a or 0, it = first.it, nm = first.nm,
          at = first.at or 0, src = "bank", g = explicit, tab = first.tab, recs = cluster.recs,
          id = first.id .. "#" .. i }
      end
    end
    for _, r in ipairs(list) do
      local at = r.at or 0
      if cluster and at - cluster.last <= tolerance(now, cluster.last) then
        table.insert(cluster.recs, r)
        cluster.last = at
      else
        flush()
        cluster = { recs = { r }, last = at }
      end
    end
    flush()
  end
  table.sort(out, function(a, b)
    if a.at ~= b.at then return a.at > b.at end
    return a.id < b.id
  end)
  return out
end

-- Objectifs qui pourraient accueillir ce don : même sorte, même objet, et le
-- don tombe dans la période de l'objectif.
local function candidates(gift, goals)
  local list = {}
  for _, g in ipairs(goals) do
    if g.k == gift.k and (g.k ~= "objet" or g.it == gift.it) then
      -- Le journal donne l'heure à l'heure près, arrondie vers le bas : un dépôt
      -- fait après la création de l'objectif, dans la même heure, compte.
      local slack = gift.src == "bank" and HOUR or 0
      if gift.at + slack >= (g.from or 0) and gift.at <= (g.to or math.huge) then list[#list + 1] = g end
    end
  end
  return list
end

-- L'objectif d'un don, ou nil et pourquoi : "ignore" (compte pour aucun),
-- "classer" (plusieurs possibles : un officier doit choisir), "aucun".
function Effort:GoalOf(gift, goals)
  if gift.g == "-" then return nil, "ignore" end
  if gift.g then
    local g = Store:Get("goals", gift.g)
    if g then return g end
  end
  local c = candidates(gift, goals or Store:List("goals"))
  if #c == 1 then return c[1] end
  if #c > 1 then return nil, "classer" end
  return nil, "aucun"
end

-- Tout le calcul d'un coup, gardé jusqu'au prochain changement de données.
function Effort:Snapshot()
  -- Gardé une minute : « en retard » dépend de l'heure, pas seulement des données.
  if self.snap and Util.Now() - (self.snapAt or 0) < 60 then return self.snap end
  local goals = Store:List("goals")
  table.sort(goals, function(a, b)
    local fa, fb = a.st == "closed", b.st == "closed"
    if fa ~= fb then return fb end
    local ta, tb = a.to or math.huge, b.to or math.huge
    if ta ~= tb then return ta < tb end
    return (a.u or 0) > (b.u or 0)
  end)
  local progress = {}
  for _, g in ipairs(goals) do progress[g.id] = { total = 0, donors = 0, donorSet = {}, gifts = {} } end
  local gifts = self:GiftList()
  for _, gift in ipairs(gifts) do
    local g, why = self:GoalOf(gift, goals)
    gift.goal, gift.why = g, why
    if g then
      local p = progress[g.id]
      p.total = p.total + gift.a
      if not p.donorSet[gift.c] then p.donorSet[gift.c] = true; p.donors = p.donors + 1 end
      p.gifts[#p.gifts + 1] = gift
    end
  end
  local now = Util.Now()
  for _, g in ipairs(goals) do
    local p = progress[g.id]
    p.pct = (g.amt and g.amt > 0) and math.min(1, p.total / g.amt) or 0
    p.status = self:StatusOf(g, p, now)
  end
  self.snap = { goals = goals, progress = progress, gifts = gifts }
  self.snapAt = now
  return self.snap
end

-- "done" (atteint), "closed" (fermé avant la cible), "late" (en retard sur la date), "going".
function Effort:StatusOf(g, p, now)
  if g.amt and g.amt > 0 and p.total >= g.amt then return "done" end
  if g.st == "closed" then return "closed" end
  if g.to then
    if now > g.to then return "late" end
    local from = g.from or now
    local span = g.to - from
    if span > 0 then
      local pace = (now - from) / span
      if pace >= 0.15 and p.total / g.amt < pace * 0.75 then return "late" end
    end
  end
  return "going"
end

function Effort:Progress(goal)
  return self:Snapshot().progress[goal.id]
end

-- Mes dons lus ou déclarés pour les objectifs en cours.
function Effort:Mine()
  local gold, items = 0, 0
  for _, gift in ipairs(self:Snapshot().gifts) do
    if gift.goal and gift.goal.st == "open" and DR.Profile:IsMine(gift.c) then
      if gift.k == "or" then gold = gold + gift.a else items = items + gift.a end
    end
  end
  return gold, items
end

-- Dons à classer par un officier : plusieurs objectifs possibles.
function Effort:ToSort()
  local n = 0
  for _, gift in ipairs(self:Snapshot().gifts) do
    if gift.why == "classer" then n = n + 1 end
  end
  return n
end

-- Derniers dons, du plus récent au plus ancien.
function Effort:Recent(limit)
  local out = {}
  for _, gift in ipairs(self:Snapshot().gifts) do
    out[#out + 1] = gift
    if #out >= (limit or 40) then break end
  end
  return out
end

function Effort:GiftText(gift)
  if gift.k == "or" then return Util.Money(gift.a) end
  return gift.a .. " " .. (gift.nm or "objet")
end

---------------------------------------------------------------------------
-- Écrire un don
---------------------------------------------------------------------------
-- Les lignes lues dans la banque. entries : { c, k, a, it, nm, at, tab }.
-- Rend le nombre de dons nouveaux.
function Effort:RecordBank(entries)
  if not Store:IsReady() then return 0 end
  local me, now, new = DR.playerName, Util.Now(), 0
  local mine = {}
  for _, r in ipairs(Store:List("gifts", function(r) return r.src == "bank" and r.rd == me end)) do
    local key = giftKey(r)
    mine[key] = mine[key] or {}
    table.insert(mine[key], { rec = r })
  end
  table.sort(entries, function(a, b) return a.at < b.at end)
  for _, e in ipairs(entries) do
    local key = giftKey(e)
    local matched = false
    for _, m in ipairs(mine[key] or {}) do
      local at = m.rec.at or 0
      if not m.used and math.abs(at - e.at) <= tolerance(now, math.min(at, e.at)) then
        m.used, matched = true, true
        break
      end
    end
    if not matched then
      local rec = Store:Put("gifts", {
        id = "b" .. Util.ToBase36(now) .. Util.RandomId(4), c = e.c, k = e.k, a = e.a, it = e.it,
        nm = e.nm, at = e.at, src = "bank", rd = me, tab = e.tab,
      })
      if rec then
        new = new + 1
        mine[key] = mine[key] or {}
        table.insert(mine[key], { rec = rec, used = true })
      end
    end
  end
  return new
end

-- Un don que le membre déclare à la main, pour le cas où la banque ne l'a pas
-- montré. Rend le don, ou nil et la raison.
function Effort:Declare(goalId, amountText, note)
  local g = Store:Get("goals", goalId)
  if not g then return nil, "Choisis un objectif." end
  if g.st ~= "open" then return nil, "Cet objectif est fermé." end
  local a
  if g.k == "or" then
    a = Util.ParseGold(amountText)
  else
    a = tonumber(Util.Trim(amountText or ""))
    if a and (a < 1 or a ~= math.floor(a)) then a = nil end
  end
  if not a or a <= 0 then
    return nil, g.k == "or" and "Montant invalide : écris par exemple 25 po." or "Quantité invalide : écris un nombre entier."
  end
  local rec = Store:Put("gifts", {
    id = self:NewId("h"), c = DR.playerName, k = g.k, a = a, it = g.it, nm = g.nm, at = Util.Now(),
    src = "hand", g = g.id, n = Util.Trim(note or "") ~= "" and Util.Truncate(Util.Trim(note), 120) or nil,
  })
  DR:Emit("EFFORT_CHANGED")
  return rec
end

-- Un officier range un don : vers un objectif, ou "-" pour ne le compter nulle part.
function Effort:Classify(gift, goalId)
  if not DR.Guild:IAmOfficer() then return false end
  for _, r in ipairs(gift.recs or {}) do
    local rec = Util.Copy(r)
    rec.g = goalId
    Store:Put("gifts", rec)
  end
  DR:Emit("EFFORT_CHANGED")
  return true
end

-- Un officier retire un don déclaré à tort. Une ligne de la banque ne se retire
-- pas : on la range sur « ne compte pour aucun ».
function Effort:Remove(gift)
  if not DR.Guild:IAmOfficer() then return false end
  if gift.src == "bank" then return self:Classify(gift, "-") end
  for _, r in ipairs(gift.recs or {}) do Store:Delete("gifts", r.id) end
  DR:Emit("EFFORT_CHANGED")
  return true
end

---------------------------------------------------------------------------
-- Réglages et état de la lecture de la banque
---------------------------------------------------------------------------
function Effort:Visibility()
  local m = Store:Get("meta", "effort")
  return (m and m.vis == "officers") and "officers" or "all"
end

function Effort:SetVisibility(vis)
  if not DR.Guild:IAmOfficer() then return false end
  Store:Put("meta", { id = "effort", vis = vis == "officers" and "officers" or "all" })
  DR:Emit("EFFORT_CHANGED")
  return true
end

-- Puis-je voir qui a donné quoi ?
function Effort:CanSeeDetails()
  return self:Visibility() == "all" or DR.Guild:IAmOfficer()
end

-- Dernière lecture du journal de la banque, par n'importe quel membre.
function Effort:BankStatus()
  local m = Store:Get("meta", "bank")
  if not m then return nil end
  return { at = m.at, by = m.by, n = m.n or 0, nw = m.nw or 0 }
end

function Effort:NoteBankRead(n, new)
  local last = Store:Get("meta", "bank")
  local now = Util.Now()
  -- Pas plus d'un message toutes les 10 minutes, sauf s'il y a du nouveau.
  if last and last.by == DR.playerName and now - (last.at or 0) < 600 and new == 0 then return end
  Store:Put("meta", { id = "bank", at = now, by = DR.playerName, n = n, nw = new })
end

function Effort:OnLogin()
  DR:Listen("DATA_CHANGED", function(ds)
    if ds == "goals" or ds == "gifts" or ds == "meta" then self.snap = nil end
  end)
  DR:Listen("STORE_BOUND", function() self.snap = nil end)
end
