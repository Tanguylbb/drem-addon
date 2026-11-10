-- Sorties de la guilde (raids, donjons, soirées) et inscriptions.
--
-- Sortie ("events") :
--   id, t (titre), k (raid|donjon|soiree|autre), d (début, horodatage),
--   dur (durée en minutes), cap (places), nt/nh/nd (tanks, soins, DPS voulus),
--   lead (chef de raid), rdv (rendez-vous), note, st (open|closed|cancelled),
--   lock (fermeture des inscriptions, facultatif), src ("site" ou "jeu")
-- Inscription ("signups") :
--   e (id de la sortie), c (perso), cl (classe), r (T|H|D),
--   s (yes|maybe|bench|no), m (petit mot), acc (compte)

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

function Cal:Counts(eventId)
  local c = { yes = 0, maybe = 0, bench = 0, no = 0, T = 0, H = 0, D = 0, total = 0 }
  for _, s in ipairs(Store:List("signups", function(x) return x.e == eventId end)) do
    if c[s.s] then c[s.s] = c[s.s] + 1 end
    if s.s == "yes" and c[s.r or ""] then c[s.r] = c[s.r] + 1 end
    c.total = c.total + 1
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
-- Écriture
---------------------------------------------------------------------------
-- Rend true, ou false et la raison.
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
  -- Un seul perso par compte et par sortie.
  for _, s in ipairs(Store:List("signups", function(x) return x.e == eventId end)) do
    if s.c ~= charName and DR.Profile:IsMine(s.c) and DR.Profile:IsMine(charName) then
      Store:Delete("signups", Store.KeyOf("signups", s))
    end
  end
  local char = Store:Get("chars", charName) or DR.db.myChars[charName] or {}
  Store:Put("signups", {
    e = eventId, c = charName, cl = char.cl or DR.Profile:ClassOf(charName),
    r = role or char.r or "D", s = status,
    m = (note and note ~= "") and Util.Truncate(note, 60) or nil,
    acc = char.acc,
  })
  DR:Emit("SIGNUP_CHANGED", eventId)
  return true
end

function Cal:NewId()
  return "g" .. Util.ToBase36(Util.Now()) .. Util.RandomId(3)
end

-- Crée ou modifie une sortie (officiers).
function Cal:SaveEvent(fields)
  if not DR.Guild:IAmOfficer() then return nil, "Réservé aux officiers." end
  local t = Util.Trim(fields.t)
  if t == "" then return nil, "Donne un titre à la sortie." end
  if not fields.d then return nil, "Date ou heure invalide (JJ/MM et HH:MM)." end
  local old = fields.id and Store:GetRaw("events", fields.id)
  local rec = {
    id = fields.id or self:NewId(),
    t = Util.Truncate(t, 80),
    k = Cal.KINDS[fields.k] and fields.k or "raid",
    d = fields.d,
    dur = tonumber(fields.dur) or 120,
    cap = tonumber(fields.cap) or nil,
    nt = tonumber(fields.nt) or 0,
    nh = tonumber(fields.nh) or 0,
    nd = tonumber(fields.nd) or 0,
    lead = Util.Trim(fields.lead or "") ~= "" and Util.Trim(fields.lead) or nil,
    rdv = Util.Trim(fields.rdv or "") ~= "" and Util.Trim(fields.rdv) or nil,
    note = Util.Trim(fields.note or "") ~= "" and Util.Truncate(Util.Trim(fields.note), 500) or nil,
    st = fields.st or (old and not old.del and old.st) or "open",
    lock = fields.lock,
    src = (old and old.src) or "jeu",
  }
  local written = Store:Put("events", rec)
  DR:Emit("EVENTS_CHANGED")
  return written or rec
end

function Cal:SetStatus(id, st)
  if not DR.Guild:IAmOfficer() then return false end
  local ev = Store:Get("events", id)
  if not ev then return false end
  local rec = Util.Copy(ev)
  rec.st = st
  Store:Put("events", rec)
  DR:Emit("EVENTS_CHANGED")
  return true
end

function Cal:Delete(id)
  if not DR.Guild:IAmOfficer() then return false end
  Store:Delete("events", id)
  DR:Emit("EVENTS_CHANGED")
  return true
end
