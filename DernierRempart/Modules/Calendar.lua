-- Sorties de la guilde (raids, donjons, soirées) et inscriptions.
--
-- Sortie ("events") :
--   id, t (titre), k (raid|donjon|soiree|autre), d (début, horodatage),
--   dur (durée en minutes), cap (places ; absent = pas de limite),
--   nt/nh/nd (tanks, soins, DPS voulus ; tous à 0 = sortie sans rôle),
--   lead (chef de raid), rdv (rendez-vous), note, st (open|closed|cancelled),
--   lock (fermeture des inscriptions, facultatif), src ("site" ou "jeu"),
--   own (perso qui a créé la sortie : il peut la modifier, la fermer, la
--   supprimer ; les officiers le peuvent toujours), ap (1 = inscriptions sur
--   validation du créateur)
-- Inscription ("signups") :
--   e (id de la sortie), c (perso), cl (classe), r (T|H|D),
--   s (yes|maybe|bench|no), m (petit mot), acc (compte),
--   ft (quand il s'est mis « Présent » : l'ordre de la liste d'attente)
--
-- Qui peut quoi : les officiers créent tout. Un membre crée donjons, soirées et
-- autres (pas les raids), au plus MAX_ACTIVE sorties à venir à la fois, et
-- gère les siennes. Les autres add-ons refusent le reste (Sync:Accept).

local _, DR = ...
local Cal = DR:NewModule("Calendar")
local Util, Store = DR.Util, DR.Store

Cal.KINDS = {
  raid = { label = "Raid", color = "F1D796" },
  donjon = { label = "Donjon", color = "86B6EE" },
  soiree = { label = "Soirée", color = "66CC85" },
  autre = { label = "Autre", color = "B9C2D0" },
}
Cal.KIND_ORDER = { "raid", "donjon", "soiree", "autre" }

Cal.STATUSES = {
  yes = { label = "Présent", color = "72D3C6", order = 1 },
  maybe = { label = "Peut-être", color = "F1D796", order = 2 },
  bench = { label = "Remplaçant", color = "86B6EE", order = 3 },
  no = { label = "Absent", color = "F4A95C", order = 4 },
}
Cal.STATUS_ORDER = { "yes", "maybe", "bench", "no" }

local ONGOING = 4 * 3600 -- une sortie reste « à venir » 4 h après son début
Cal.MAX_ACTIVE = 5           -- sorties à venir qu'un membre (non officier) peut avoir à la fois
Cal.MAX_AHEAD = 60 * 86400   -- pas plus de 60 jours devant

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------
function Cal:Get(id)
  return Store:Get("events", id)
end

function Cal:Upcoming(days)
  local now = Util.Now()
  local limit = now + (days or 60) * 86400
  local list = Store:List("events", function(e)
    return e.d and e.d >= now - ONGOING and e.d <= limit
  end)
  table.sort(list, function(a, b) return a.d < b.d end)
  return list
end

function Cal:Past(days)
  local now = Util.Now()
  local list = Store:List("events", function(e)
    return e.d and e.d < now - ONGOING and e.d >= now - (days or 60) * 86400
  end)
  table.sort(list, function(a, b) return a.d > b.d end)
  return list
end

function Cal:Signups(eventId)
  local list = Store:List("signups", function(s) return s.e == eventId end)
  table.sort(list, function(a, b)
    local oa, ob = Cal.STATUSES[a.s] and Cal.STATUSES[a.s].order or 9, Cal.STATUSES[b.s] and Cal.STATUSES[b.s].order or 9
    if oa ~= ob then return oa < ob end
    if (a.r or "") ~= (b.r or "") then return (a.r or "Z") < (b.r or "Z") end
    return a.c < b.c
  end)
  return list
end

-- Un rôle est-il demandé ? (Sinon : soirée, entraide… personne n'a de rôle.)
function Cal.WantsRoles(ev)
  return ev ~= nil and ((ev.nt or 0) + (ev.nh or 0) + (ev.nd or 0)) > 0
end

-- Les places : absent ou 0 = pas de limite.
function Cal.Capacity(ev)
  local cap = ev and tonumber(ev.cap) or 0
  return cap > 0 and cap or nil
end

local function queueTime(s) return s.ft or s.u or 0 end

-- Les inscrits d'une sortie, chacun avec son état :
--   in      : compte dans la sortie
--   wait    : liste d'attente (plus de place) ; rank = son rang. Les « Présent » sont
--             servis dans l'ordre où ils se sont inscrits ; une place libérée est
--             donnée au suivant, sans rien faire (tout le monde calcule pareil).
--   no      : absent
-- Triés : réponse, rôle, nom.
function Cal:Entries(eventId)
  local ev = type(eventId) == "table" and eventId or self:Get(eventId)
  local id = type(eventId) == "table" and eventId.id or eventId
  local entries, yes = {}, {}
  for _, s in ipairs(Store:List("signups", function(x) return x.e == id end)) do
    local e = { s = s, state = (s.s == "no") and "no" or "in" }
    entries[#entries + 1] = e
    if e.state == "in" and s.s == "yes" then yes[#yes + 1] = e end
  end
  local cap = Cal.Capacity(ev)
  if cap and #yes > cap then
    table.sort(yes, function(a, b)
      local ta, tb = queueTime(a.s), queueTime(b.s)
      if ta ~= tb then return ta < tb end
      return a.s.c < b.s.c
    end)
    for i = cap + 1, #yes do
      yes[i].state = "wait"
      yes[i].rank = i - cap
    end
  end
  table.sort(entries, function(a, b)
    local oa = a.state == "wait" and 5 or (Cal.STATUSES[a.s.s] and Cal.STATUSES[a.s.s].order or 9)
    local ob = b.state == "wait" and 5 or (Cal.STATUSES[b.s.s] and Cal.STATUSES[b.s.s].order or 9)
    if oa ~= ob then return oa < ob end
    if a.state == "wait" then return a.rank < b.rank end
    if (a.s.r or "") ~= (b.s.r or "") then return (a.s.r or "Z") < (b.s.r or "Z") end
    return a.s.c < b.s.c
  end)
  return entries
end

-- Mon état dans la sortie (voir Entries) et mon rang d'attente, s'il y en a un.
function Cal:MyState(eventId)
  local mine = self:MySignup(eventId)
  if not mine then return nil end
  for _, e in ipairs(self:Entries(eventId)) do
    if e.s.c == mine.c then return e.state, e.rank, mine end
  end
  return nil
end

function Cal:Counts(eventId)
  local c = { yes = 0, maybe = 0, bench = 0, no = 0, wait = 0, T = 0, H = 0, D = 0, total = 0 }
  for _, e in ipairs(self:Entries(eventId)) do
    c.total = c.total + 1
    if e.state == "wait" then
      c.wait = c.wait + 1
    else
      local st = e.s.s
      if c[st] then c[st] = c[st] + 1 end
      if st == "yes" and c[e.s.r or ""] then c[e.s.r] = c[e.s.r] + 1 end
    end
  end
  return c
end

-- Places qui manquent par rôle, parmi les présents.
function Cal:Missing(ev, counts)
  counts = counts or self:Counts(ev.id)
  local m = {
    T = math.max(0, (ev.nt or 0) - counts.T),
    H = math.max(0, (ev.nh or 0) - counts.H),
    D = math.max(0, (ev.nd or 0) - counts.D),
  }
  m.any = m.T + m.H + m.D > 0
  return m
end

function Cal:MissingText(ev, counts)
  local m = self:Missing(ev, counts)
  if not m.any then return nil end
  local parts = {}
  for _, r in ipairs(Util.ROLES) do
    if m[r] > 0 then
      local word = m[r] > 1 and Util.ROLE_PLURAL[r] or (r == "T" and "tank" or (r == "H" and "soin" or "DPS"))
      parts[#parts + 1] = m[r] .. " " .. word
    end
  end
  return "Manque " .. table.concat(parts, ", ")
end

-- Mon inscription (n'importe lequel de mes persos), la plus récente.
function Cal:MySignup(eventId)
  local best
  for _, s in ipairs(Store:List("signups", function(x) return x.e == eventId end)) do
    if DR.Profile:IsMine(s.c) and (not best or (s.u or 0) > (best.u or 0)) then best = s end
  end
  return best
end

-- Qui a vu la sortie ? Compte les persos de la liste de guilde :
--   answered  : ont répondu (un par compte)
--   pending   : ont l'add-on mais n'ont pas répondu (un par compte)
--   noAddon   : n'ont pas l'add-on (à relancer sur Discord)
-- Approximatif : un joueur qui a plusieurs persos sans add-on compte plusieurs fois.
function Cal:SeenBy(eventId)
  local answeredAcc, answeredName, answered = {}, {}, 0
  for _, s in ipairs(Store:List("signups", function(x) return x.e == eventId end)) do
    local acc = s.acc
    if not acc then
      local c = Store:Get("chars", s.c)
      acc = c and c.acc
    end
    answeredName[s.c] = true
    if acc then
      if not answeredAcc[acc] then answeredAcc[acc] = true; answered = answered + 1 end
    else
      answered = answered + 1
    end
  end
  local pending, noAddon, pendingAcc = 0, 0, {}
  local pendingNames, noAddonNames = {}, {}
  for _, m in pairs(DR.Guild.members) do
    if DR.Guild:HasAddon(m.name) then
      local c = Store:Get("chars", m.name)
      local acc = c and c.acc
      if not answeredName[m.name] and not (acc and (answeredAcc[acc] or pendingAcc[acc])) then
        pending = pending + 1
        pendingNames[#pendingNames + 1] = m.name
        if acc then pendingAcc[acc] = true end
      end
    else
      noAddon = noAddon + 1
      noAddonNames[#noAddonNames + 1] = m.name
    end
  end
  table.sort(pendingNames)
  table.sort(noAddonNames)
  return { answered = answered, pending = pending, noAddon = noAddon,
    pendingNames = pendingNames, noAddonNames = noAddonNames }
end

function Cal:IsOpen(ev)
  if not ev or ev.st == "cancelled" or ev.st == "closed" then return false end
  local now = Util.Now()
  if ev.lock and now >= ev.lock then return false end
  return (ev.d or 0) > now - ONGOING
end

-- Sorties à venir qui attendent ma réponse.
function Cal:AwaitingAnswer()
  local out = {}
  for _, ev in ipairs(self:Upcoming(21)) do
    if self:IsOpen(ev) and not self:MySignup(ev.id) then out[#out + 1] = ev end
  end
  return out
end

function Cal:Next()
  for _, ev in ipairs(self:Upcoming(60)) do
    if ev.st ~= "cancelled" then return ev end
  end
  return nil
end

---------------------------------------------------------------------------
-- Droits
---------------------------------------------------------------------------
-- Deux persos sont-ils au même joueur ? (même nom, ou même compte)
function Cal.SameOwner(a, b)
  if not a or not b then return false end
  if Util.SameName(a, b) then return true end
  local ca, cb = Store:Get("chars", a), Store:Get("chars", b)
  return (ca and cb and ca.acc ~= nil and ca.acc == cb.acc) or false
end

-- Mes sorties à venir (celles que j'ai créées, annulées exclues).
function Cal:MyActiveCount()
  local now = Util.Now()
  return #Store:List("events", function(e)
    return e.own ~= nil and DR.Profile:IsMine(e.own) and e.st ~= "cancelled" and (e.d or 0) >= now - ONGOING
  end)
end

-- Puis-je créer une sortie de ce type ? Rend true, ou false et la raison.
function Cal:CanCreate(kind)
  if DR.Guild:IAmOfficer() then return true end
  if kind == "raid" then return false, "Les raids sont réservés aux officiers." end
  if self:MyActiveCount() >= Cal.MAX_ACTIVE then
    return false, "Tu as déjà " .. Cal.MAX_ACTIVE .. " sorties à venir : annule-en une ou attends qu'elle passe."
  end
  return true
end

-- Puis-je modifier, fermer, annuler ou supprimer cette sortie ?
function Cal:CanEdit(ev)
  if not ev then return false end
  if DR.Guild:IAmOfficer() then return true end
  return ev.own ~= nil and DR.Profile:IsMine(ev.own)
end

-- Règle de réception (Sync:Accept) : cette version de la sortie, venue de rec.by,
-- est-elle permise ? Les officiers et le site : tout. Un membre : seulement ses
-- propres sorties, jamais un raid.
function Cal.AcceptEvent(rec, old)
  local Guild = DR.Guild
  local by = rec.by
  if by == "site" or Guild:IsOfficer(by) then return true end
  local live = old and not old.del and old or nil
  if rec.del then
    return live ~= nil and live.own ~= nil and Cal.SameOwner(live.own, by)
  end
  if rec.k == "raid" then return false end
  if rec.own == nil or not Cal.SameOwner(rec.own, by) then return false end
  if live and not (live.own and Cal.SameOwner(live.own, rec.own)) then return false end
  return true
end

---------------------------------------------------------------------------
-- Écriture
---------------------------------------------------------------------------
-- Rend true, puis mon état dans la sortie (« in » ou « wait ») et mon rang d'attente ;
-- ou false et la raison.
function Cal:SetSignup(eventId, charName, status, role, note)
  local ev = self:Get(eventId)
  if not ev then return false, "Sortie introuvable." end
  local officer = DR.Guild:IAmOfficer()
  if not self:IsOpen(ev) and not officer then
    return false, "Les inscriptions de cette sortie sont fermées."
  end
  if not Cal.STATUSES[status] then return false, "Réponse inconnue." end
  charName = charName or DR.playerName
  if not DR.Profile:IsMine(charName) and not officer then
    return false, "Tu ne peux inscrire que tes propres persos."
  end
  -- Un seul perso par compte et par sortie. Changer de perso garde sa place d'attente.
  local first
  for _, s in ipairs(Store:List("signups", function(x) return x.e == eventId end)) do
    if s.c ~= charName and DR.Profile:IsMine(s.c) and DR.Profile:IsMine(charName) then
      if s.s == "yes" and s.ft then first = math.min(first or s.ft, s.ft) end
      Store:Delete("signups", Store.KeyOf("signups", s))
    end
  end
  local char = Store:Get("chars", charName) or DR.db.myChars[charName] or {}
  -- Place dans la file : on la garde tant qu'on reste « Présent » ; si on quitte puis
  -- qu'on revient, on repart au bout de la file.
  local before = Store:Get("signups", eventId .. "|" .. charName)
  local ft
  if status == "yes" then
    ft = (before and before.s == "yes" and before.ft) or first or Util.Now()
  end
  Store:Put("signups", {
    e = eventId, c = charName, cl = char.cl or DR.Profile:ClassOf(charName),
    r = role or char.r or "D", s = status,
    m = (note and note ~= "") and Util.Truncate(note, 60) or nil,
    acc = char.acc, ft = ft,
  })
  DR:Emit("SIGNUP_CHANGED", eventId)
  local state, rank = self:MyState(eventId)
  return true, state, rank
end

function Cal:NewId()
  return "g" .. Util.ToBase36(Util.Now()) .. Util.RandomId(3)
end

-- Crée ou modifie une sortie. Officiers : toutes ; membres : les leurs, sans raid.
-- Rend l'enregistrement écrit, ou nil et la raison.
function Cal:SaveEvent(fields)
  local t = Util.Trim(fields.t)
  local old = fields.id and Store:GetRaw("events", fields.id)
  if old and old.del then old = nil end
  local officer = DR.Guild:IAmOfficer()
  local kind = Cal.KINDS[fields.k] and fields.k or (old and old.k) or "raid"
  if old then
    if not self:CanEdit(old) then return nil, "Tu ne peux modifier que tes propres sorties." end
    if not officer and kind == "raid" then return nil, "Les raids sont réservés aux officiers." end
  else
    local ok, why = self:CanCreate(kind)
    if not ok then return nil, why end
  end
  if t == "" then return nil, "Donne un titre à la sortie." end
  if not fields.d then return nil, "Date ou heure invalide (JJ/MM et HH:MM)." end
  if not officer and fields.d > Util.Now() + Cal.MAX_AHEAD then
    return nil, "Pas plus de 60 jours devant."
  end
  local cap = tonumber(fields.cap)
  local rec = {
    id = fields.id or self:NewId(),
    t = Util.Truncate(t, 80),
    k = kind,
    d = fields.d,
    dur = tonumber(fields.dur) or 120,
    cap = (cap and cap > 0) and math.floor(cap) or nil,
    nt = tonumber(fields.nt) or 0,
    nh = tonumber(fields.nh) or 0,
    nd = tonumber(fields.nd) or 0,
    lead = Util.Trim(fields.lead or "") ~= "" and Util.Trim(fields.lead) or nil,
    rdv = Util.Trim(fields.rdv or "") ~= "" and Util.Trim(fields.rdv) or nil,
    note = Util.Trim(fields.note or "") ~= "" and Util.Truncate(Util.Trim(fields.note), 500) or nil,
    st = fields.st or (old and not old.del and old.st) or "open",
    lock = fields.lock,
    src = (old and old.src) or "jeu",
    own = old and old.own or ((not old) and DR.playerName or nil),
    ap = fields.ap and 1 or nil,
  }
  local written = Store:Put("events", rec)
  DR:Emit("EVENTS_CHANGED")
  return written or rec
end

function Cal:SetStatus(id, st)
  local ev = Store:Get("events", id)
  if not ev or not self:CanEdit(ev) then return false end
  local rec = Util.Copy(ev)
  rec.st = st
  Store:Put("events", rec)
  DR:Emit("EVENTS_CHANGED")
  return true
end

function Cal:Delete(id)
  local ev = Store:Get("events", id)
  if not ev or not self:CanEdit(ev) then return false end
  Store:Delete("events", id)
  DR:Emit("EVENTS_CHANGED")
  return true
end
