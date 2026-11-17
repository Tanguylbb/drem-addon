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
-- Décision ("verdicts", seulement sur une sortie « sur validation », ap = 1) :
--   e (id de la sortie), c (perso), v (a = accepté, w = en réserve, r = pas retenu)
--   Écrite par le créateur ou un officier ; pas de décision = demande en attente.
--   Une décision d'un autre auteur est ignorée à la lecture (Cal:Entries).
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
Cal.ATTENTION = 24 * 3600    -- 24 h avant : les officiers voient les demandes sans réponse

Cal.VERDICTS = {
  a = { label = "Accepté", color = "72D3C6" },
  w = { label = "En réserve", color = "F4A95C" },
  r = { label = "Pas retenu", color = "E8553E" },
}

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

-- Une décision est-elle valable ? Seulement celle d'un officier, du site ou du créateur.
local function validVerdict(ev, v)
  if not v or v.del then return nil end
  if v.by == "site" or DR.Guild:IsOfficer(v.by) then return v.v end
  if ev and ev.own and Cal.SameOwner(ev.own, v.by) then return v.v end
  return nil
end

-- Règle de réception (Sync:Accept) : qui peut écrire une décision sur cette sortie ?
-- Si la sortie n'est pas encore connue ici on laisse passer ; la lecture revérifie.
function Cal.AcceptVerdict(rec, ev)
  local by = rec.by
  if by == "site" or DR.Guild:IsOfficer(by) then return true end
  if not ev then return true end
  return ev.own ~= nil and Cal.SameOwner(ev.own, by)
end

-- Les inscrits d'une sortie, chacun avec son état :
--   in      : compte dans la sortie
--   wait    : liste d'attente (plus de place) ; rank = son rang. Les « Présent » sont
--             servis dans l'ordre où ils se sont inscrits ; une place libérée est
--             donnée au suivant, sans rien faire (tout le monde calcule pareil).
--   pending : demande à valider (sortie sur validation, pas encore de décision) ;
--             late = la sortie a commencé sans réponse
--   reserve : en réserve (décision du créateur)
--   refused : pas retenu (décision du créateur)
--   no      : absent
-- by = qui a décidé. Triés : réponse, rôle, nom.
local STATE_ORDER = { wait = 5, pending = 6, reserve = 7, refused = 8 }

function Cal:Entries(eventId)
  local ev = type(eventId) == "table" and eventId or self:Get(eventId)
  local id = type(eventId) == "table" and eventId.id or eventId
  local verdicts = {}
  if ev and ev.ap then
    for _, v in ipairs(Store:List("verdicts", function(x) return x.e == id end)) do
      if validVerdict(ev, v) then verdicts[v.c] = v end
    end
  end
  local now = Util.Now()
  local entries, yes = {}, {}
  for _, s in ipairs(Store:List("signups", function(x) return x.e == id end)) do
    local e = { s = s, state = "in" }
    if s.s == "no" then
      e.state = "no"
    elseif ev and ev.ap then
      local v = verdicts[s.c]
      if not v then
        e.state, e.late = "pending", (ev.d or 0) < now
      elseif v.v == "a" then
        e.state, e.by = "in", v.by
      elseif v.v == "w" then
        e.state, e.by = "reserve", v.by
      else
        e.state, e.by = "refused", v.by
      end
    end
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
  local function order(e)
    return STATE_ORDER[e.state] or (Cal.STATUSES[e.s.s] and Cal.STATUSES[e.s.s].order or 9)
  end
  table.sort(entries, function(a, b)
    local oa, ob = order(a), order(b)
    if oa ~= ob then return oa < ob end
    if a.state == "wait" then return a.rank < b.rank end
    if (a.s.r or "") ~= (b.s.r or "") then return (a.s.r or "Z") < (b.s.r or "Z") end
    return a.s.c < b.s.c
  end)
  return entries
end

-- Les demandes qui attendent une décision (la sortie n'a pas encore commencé).
function Cal:Pending(ev)
  local out = {}
  for _, e in ipairs(self:Entries(ev)) do
    if e.state == "pending" and not e.late then out[#out + 1] = e end
  end
  return out
end

-- Mon état dans la sortie (voir Entries), mon rang d'attente, mon inscription et l'entrée.
function Cal:MyState(eventId)
  local mine = self:MySignup(eventId)
  if not mine then return nil end
  for _, e in ipairs(self:Entries(eventId)) do
    if e.s.c == mine.c then return e.state, e.rank, mine, e end
  end
  return nil
end

function Cal:Counts(eventId)
  local c = { yes = 0, maybe = 0, bench = 0, no = 0, wait = 0, pending = 0, reserve = 0, refused = 0,
    T = 0, H = 0, D = 0, total = 0 }
  for _, e in ipairs(self:Entries(eventId)) do
    c.total = c.total + 1
    if e.state == "wait" or e.state == "pending" or e.state == "reserve" or e.state == "refused" then
      c[e.state] = c[e.state] + 1
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
  -- Sur validation : celui qui décide n'a pas à se demander la permission.
  if ev.ap and status ~= "no" and self:CanEdit(ev) then
    self:SetVerdict(eventId, charName, "a", true)
  end
  DR:Emit("SIGNUP_CHANGED", eventId)
  local state, rank = self:MyState(eventId)
  return true, state, rank
end

-- Décider d'une demande : "a" (accepter), "w" (en réserve), "r" (pas retenu), ou nil pour
-- la remettre en attente. Le créateur et les officiers seulement. force : ne pas vérifier
-- les places (le créateur qui s'inscrit lui-même ; la liste d'attente fait le reste).
function Cal:SetVerdict(eventId, charName, v, force)
  local ev = self:Get(eventId)
  if not ev then return false, "Sortie introuvable." end
  if not ev.ap then return false, "Cette sortie n'est pas sur validation." end
  if not self:CanEdit(ev) then return false, "Seuls l'organisateur et les officiers décident." end
  local signup = Store:Get("signups", eventId .. "|" .. charName)
  if not signup then return false, "Cette inscription n'existe plus." end
  if v ~= nil and not Cal.VERDICTS[v] then return false, "Décision inconnue." end
  if v == "a" and signup.s == "yes" and not force then
    local cap = Cal.Capacity(ev)
    if cap then
      local taken = 0
      for _, e in ipairs(self:Entries(ev)) do
        if e.state == "in" and e.s.s == "yes" and e.s.c ~= charName then taken = taken + 1 end
      end
      if taken >= cap then return false, "La sortie est complète : mets-le en réserve." end
    end
  end
  if v == nil then
    Store:Delete("verdicts", eventId .. "|" .. charName)
  else
    Store:Put("verdicts", { e = eventId, c = charName, v = v })
  end
  DR:Emit("SIGNUP_CHANGED", eventId)
  return true
end

-- Les sorties dont j'ai des demandes à décider : les miennes, et pour un officier
-- celles qui commencent dans moins de 24 h (à la place de l'organisateur).
-- Rend { ev, n, mine } par sortie.
function Cal:ToJudge()
  local out, now = {}, Util.Now()
  if not Store:IsReady() then return out end
  for _, ev in ipairs(self:Upcoming(60)) do
    if ev.ap and ev.st ~= "cancelled" then
      local mine = ev.own ~= nil and DR.Profile:IsMine(ev.own)
      if mine or (DR.Guild:IAmOfficer() and (ev.d or 0) - now <= Cal.ATTENTION) then
        local n = #self:Pending(ev)
        if n > 0 then out[#out + 1] = { ev = ev, n = n, mine = mine } end
      end
    end
  end
  return out
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
  -- On passe en « sur validation » : ceux qui étaient déjà inscrits sont acceptés,
  -- sinon ils retomberaient tous en attente.
  if rec.ap and not (old and old.ap) then
    for _, sg in ipairs(Store:List("signups", function(x) return x.e == rec.id and x.s ~= "no" end)) do
      Store:Put("verdicts", { e = rec.id, c = sg.c, v = "a" })
    end
  end
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

---------------------------------------------------------------------------
-- Prévenir sans déranger
---------------------------------------------------------------------------
-- Une ligne dans la discussion, jamais en combat ni pendant un boss, et jamais plus
-- d'une fois par `gap` secondes pour la même raison. La pastille de l'onglet Sorties
-- reste là pour ce que la discussion a laissé passer.
local told = {}

local function tell(key, gap, text)
  local now = Util.Now()
  if told[key] and now - told[key] < gap then return false end
  if DR.Guard.InCombat() or DR.Guard.ChatLocked() then return false end
  told[key] = now
  DR:Print(text)
  return true
end

local function recent(rec) return (rec.u or 0) > Util.Now() - 600 end

local DECISION_TEXT = {
  a = "est acceptée. À tout à l'heure !",
  w = "est en réserve : l'organisateur te garde sous le coude.",
  r = "n'est pas retenue cette fois.",
}

function Cal:OnLogin()
  -- Une demande qui arrive (organisateur), une décision qui arrive (demandeur).
  DR:Listen("DATA_CHANGED", function(ds, _, rec, _, origin)
    if origin ~= "remote" or not rec or rec.del or not recent(rec) then return end
    if ds == "signups" and rec.s ~= "no" then
      local ev = Cal:Get(rec.e)
      if ev and ev.ap and ev.own and DR.Profile:IsMine(ev.own) and not DR.Profile:IsMine(rec.c) then
        local n = #Cal:Pending(ev)
        if n > 0 then
          tell("req:" .. ev.id, 600, n == 1
            and (Util.ShortName(rec.c) .. " demande à rejoindre « " .. ev.t .. " ». Onglet Sorties pour répondre.")
            or (n .. " demandes à valider pour « " .. ev.t .. " ». Onglet Sorties."))
        end
      end
    elseif ds == "verdicts" and DR.Profile:IsMine(rec.c) and DECISION_TEXT[rec.v] then
      local ev = Cal:Get(rec.e)
      if ev then tell("ver:" .. rec.e .. rec.v, 5, "Ta demande pour « " .. ev.t .. " » " .. DECISION_TEXT[rec.v]) end
    end
  end)
  -- Une fois connecté et la synchro faite : un résumé, puis un rappel toutes les 10 minutes
  -- pour les sorties qui commencent dans moins de 24 h.
  DR.After(45, function() Cal:LoginSummary() end)
  DR.Every(600, function() Cal:Remind() end)
end

function Cal:LoginSummary()
  local total, first = 0, nil
  for _, j in ipairs(self:ToJudge()) do
    if j.mine then
      total = total + j.n
      first = first or j.ev.t
    end
  end
  if total > 0 then
    tell("login", 3600, total .. (total > 1 and " demandes attendent" or " demande attend") .. " ta réponse pour « "
      .. first .. " ». Onglet Sorties.")
  end
end

-- Moins de 24 h avant le début : il reste des demandes sans réponse.
function Cal:Remind()
  for _, j in ipairs(self:ToJudge()) do
    local ev = j.ev
    if (ev.d or 0) - Util.Now() <= Cal.ATTENTION then
      if j.mine then
        tell("late:" .. ev.id, 6 * 3600, "Il reste " .. j.n .. (j.n > 1 and " demandes" or " demande") .. " sans réponse pour « "
          .. ev.t .. " » (" .. Util.Until(ev.d) .. ").")
      else
        tell("late:" .. ev.id, 6 * 3600, "« " .. ev.t .. " » : " .. j.n .. (j.n > 1 and " demandes" or " demande")
          .. " sans réponse (organisateur : " .. Util.ShortName(ev.own or "?") .. "). Tu peux les décider à sa place.")
      end
    end
  end
end
