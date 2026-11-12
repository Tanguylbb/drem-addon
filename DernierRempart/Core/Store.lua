-- Magasin des données partagées de la guilde.
--
-- Chaque jeu de données (sorties, inscriptions, persos, recettes...) est une
-- table clé -> enregistrement. Un enregistrement porte toujours :
--   u   : date de sa dernière modification (heure du serveur, en secondes)
--   by  : qui l'a modifié (nom complet du perso, ou "site")
--   del : 1 quand il est supprimé (on garde une pierre tombale pour que la
--         suppression voyage elle aussi)
-- Les champs qui commencent par "_" restent locaux (jamais envoyés).
--
-- Règle de fusion : la version la plus récente gagne. À égalité de date, la
-- comparaison du texte canonique départage, pour que tout le monde converge
-- vers la même version.

local _, DR = ...
local Store = {}
DR.Store = Store

local Json = DR.Json

Store.BUCKETS = 16
Store.DATASETS = { "events", "signups", "chars", "recipes", "catalog", "orders", "votes", "meta", "goals", "gifts" }

local DAY = 86400

-- Clé de chaque enregistrement, tirée de ses propres champs.
local KEYS = {
  events = function(r) return r.id end,
  signups = function(r) return r.e and r.c and (r.e .. "|" .. r.c) end,
  chars = function(r) return r.n end,
  recipes = function(r) return r.c and r.p and (r.c .. "|" .. tostring(r.p)) end,
  catalog = function(r) return r.p and tostring(r.p) end,
  orders = function(r) return r.id end,
  votes = function(r) return r.o and r.c and (r.o .. "|" .. r.c) end,
  meta = function(r) return r.id end,
  goals = function(r) return r.id end,
  gifts = function(r) return r.id end,
}

-- Champs gardés sur une pierre tombale (ceux qui forment la clé).
local KEY_FIELDS = {
  events = { "id" }, signups = { "e", "c" }, chars = { "n" }, recipes = { "c", "p" },
  catalog = { "p" }, orders = { "id" }, votes = { "o", "c" }, meta = { "id" },
  goals = { "id" }, gifts = { "id" },
}

-- Durée de vie avant oubli (les données expirées ne sont plus échangées).
local function isExpired(ds, r, now)
  if r.del then return (r.u or 0) < now - 30 * DAY end
  if ds == "events" then return (r.d or now) < now - 60 * DAY end
  if ds == "signups" then return (r.u or 0) < now - 75 * DAY end
  if ds == "orders" then
    local final = r.s == "faite" or r.s == "annulee" or r.s == "apprise" or r.s == "abandonnee"
    return final and (r.u or 0) < now - 60 * DAY
  end
  if ds == "votes" then return (r.u or 0) < now - 120 * DAY end
  if ds == "chars" or ds == "recipes" then return (r.u or 0) < now - 180 * DAY end
  if ds == "goals" then return r.st == "closed" and (r.u or 0) < now - 120 * DAY end
  if ds == "gifts" then return (r.at or r.u or 0) < now - 150 * DAY end
  return false
end
Store.IsExpired = isExpired

---------------------------------------------------------------------------
-- Liaison avec la base de la guilde
---------------------------------------------------------------------------
function Store:Bind(guildDB)
  self.guildDB = guildDB
  self.data = guildDB and guildDB.data or nil
  self.hashes = {}
  if self.data then
    for _, ds in ipairs(Store.DATASETS) do
      self.data[ds] = self.data[ds] or {}
      self.hashes[ds] = {}
    end
    self:Purge()
  end
  DR:Emit("STORE_BOUND")
end

function Store:IsReady()
  return self.data ~= nil
end

function Store.KeyOf(ds, rec)
  local f = KEYS[ds]
  if not f or type(rec) ~= "table" then return nil end
  local ok, key = pcall(f, rec)
  if ok and type(key) == "string" and key ~= "" and #key <= 200 then return key end
  return nil
end

function Store.IsDataset(ds)
  return KEYS[ds] ~= nil
end

---------------------------------------------------------------------------
-- Forme canonique et empreinte
---------------------------------------------------------------------------
function Store.Canon(rec)
  return Json.Encode(rec, true)
end

-- Empreinte sur 31 bits (modulo le nombre premier 2^31 - 1).
local MOD = 2147483647
function Store.Hash(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % MOD
  end
  return h
end

function Store.BucketOf(key)
  return Store.Hash(key) % Store.BUCKETS
end

-- a est-il plus récent que b ?
function Store.Newer(a, b)
  if not b then return true end
  if not a then return false end
  local ua, ub = a.u or 0, b.u or 0
  if ua ~= ub then return ua > ub end
  return Store.Canon(a) > Store.Canon(b)
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------
function Store:Get(ds, key)
  if not self.data or not key then return nil end
  local r = self.data[ds][key]
  if r and not r.del then return r end
  return nil
end

function Store:GetRaw(ds, key)
  if not self.data or not key then return nil end
  return self.data[ds][key]
end

-- Liste des enregistrements vivants (non supprimés), filtrés au besoin.
function Store:List(ds, filter)
  local out = {}
  if not self.data then return out end
  for key, r in pairs(self.data[ds]) do
    if not r.del and (not filter or filter(r, key)) then out[#out + 1] = r end
  end
  return out
end

function Store:Count(ds)
  local n = 0
  if not self.data then return 0 end
  for _, r in pairs(self.data[ds]) do if not r.del then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
-- Écriture
---------------------------------------------------------------------------
local function strip(rec)
  local c = {}
  for k, v in pairs(rec) do
    if type(k) ~= "string" or k:sub(1, 1) ~= "_" then c[k] = DR.Util.Copy(v) end
  end
  return c
end

function Store:_set(ds, key, rec, origin)
  local old = self.data[ds][key]
  rec._r = DR.Util.Now() -- reçu ici à cette heure (sert à l'export vers le site)
  self.data[ds][key] = rec
  self.hashes[ds][key] = nil
  DR:Emit("DATA_CHANGED", ds, key, rec, old, origin)
end

-- Modification faite ici même : date et auteur posés automatiquement.
-- Rend l'enregistrement écrit (à diffuser), ou nil si rien n'a changé.
function Store:Put(ds, rec, author)
  if not self.data then return nil end
  local key = Store.KeyOf(ds, rec)
  if not key then return nil end
  local old = self.data[ds][key]
  local new = strip(rec)
  new.del = nil
  new.u, new.by = nil, nil
  if old and not old.del then
    local cmp = strip(old)
    cmp.u, cmp.by = nil, nil
    if Store.Canon(cmp) == Store.Canon(new) then return nil end
  end
  local now = DR.Util.Now()
  new.u = math.max(now, old and (old.u or 0) + 1 or 0)
  new.by = author or DR.playerName or "?"
  self:_set(ds, key, new, "local")
  return new
end

-- Suppression faite ici : pose une pierre tombale.
function Store:Delete(ds, key, author)
  if not self.data then return nil end
  local old = self.data[ds][key]
  if not old or old.del then return nil end
  local tomb = { del = 1 }
  for _, f in ipairs(KEY_FIELDS[ds]) do tomb[f] = old[f] end
  local now = DR.Util.Now()
  tomb.u = math.max(now, (old.u or 0) + 1)
  tomb.by = author or DR.playerName or "?"
  self:_set(ds, key, tomb, "local")
  return tomb
end

-- Vérifie la forme d'un enregistrement reçu d'ailleurs.
local LIMITS = { t = 80, note = 500, m = 200, rdv = 120, lead = 64, nm = 120, link = 400, pn = 64, sp = 64,
  wh = 120, wb = 64, tag = 40, n = 120, rd = 64 }

function Store.Sanitize(ds, rec)
  if type(rec) ~= "table" then return nil end
  if type(rec.u) ~= "number" or rec.u < 0 then return nil end
  if rec.by ~= nil and type(rec.by) ~= "string" then return nil end
  local clean = {}
  for k, v in pairs(rec) do
    if type(k) == "string" and k:sub(1, 1) ~= "_" then
      local tv = type(v)
      if tv == "string" then
        clean[k] = DR.Util.Truncate(v, LIMITS[k] or 300)
      elseif tv == "number" or tv == "boolean" or tv == "table" then
        clean[k] = v
      end
    end
  end
  if not Store.KeyOf(ds, clean) then return nil end
  return clean
end

-- Enregistrement venu d'un autre membre ou du site.
-- Rend "new" (pris), "same" (déjà connu), "older" (le nôtre est plus récent)
-- ou "rejected".
function Store:Merge(ds, rec, origin)
  if not self.data or not KEYS[ds] then return "rejected" end
  rec = Store.Sanitize(ds, rec)
  if not rec then return "rejected" end
  local now = DR.Util.Now()
  if rec.u > now + 3600 then return "rejected" end -- horloge folle
  if isExpired(ds, rec, now) then return "same" end
  local key = Store.KeyOf(ds, rec)
  local old = self.data[ds][key]
  if old then
    if Store.Canon(old) == Store.Canon(rec) then return "same" end
    if not Store.Newer(rec, old) then return "older" end
  end
  self:_set(ds, key, rec, origin or "remote")
  return "new"
end

---------------------------------------------------------------------------
-- Empreintes par seau (pour savoir quoi échanger)
---------------------------------------------------------------------------
function Store:RecordHash(ds, key)
  local h = self.hashes[ds][key]
  if not h then
    local r = self.data[ds][key]
    h = Store.Hash(key .. "#" .. Store.Canon(r))
    self.hashes[ds][key] = h
  end
  return h
end

-- Rend un tableau de BUCKETS sommes (indices 0..15).
function Store:Digest(ds)
  local sums = {}
  for i = 0, Store.BUCKETS - 1 do sums[i] = 0 end
  if not self.data then return sums end
  local now = DR.Util.Now()
  for key, r in pairs(self.data[ds]) do
    if not isExpired(ds, r, now) then
      local b = Store.BucketOf(key)
      sums[b] = (sums[b] + self:RecordHash(ds, key)) % MOD
    end
  end
  return sums
end

function Store.DigestToString(sums)
  local parts = {}
  for i = 0, Store.BUCKETS - 1 do parts[#parts + 1] = DR.Util.ToBase36(sums[i] or 0) end
  return table.concat(parts, ".")
end

function Store.DigestFromString(s)
  local sums, i = {}, 0
  for part in tostring(s or ""):gmatch("[^%.]+") do
    sums[i] = DR.Util.FromBase36(part) or -1
    i = i + 1
  end
  if i ~= Store.BUCKETS then return nil end
  return sums
end

-- Seaux qui diffèrent entre mon empreinte et celle reçue.
function Store:DiffBuckets(ds, theirs)
  local mine = self:Digest(ds)
  local out = {}
  for i = 0, Store.BUCKETS - 1 do
    if mine[i] ~= theirs[i] then out[#out + 1] = i end
  end
  return out
end

-- Enregistrements (pierres tombales comprises) des seaux demandés.
function Store:RecordsInBuckets(ds, buckets)
  local wanted = {}
  for _, b in ipairs(buckets) do wanted[b] = true end
  local out = {}
  if not self.data then return out end
  local now = DR.Util.Now()
  for key, r in pairs(self.data[ds]) do
    if wanted[Store.BucketOf(key)] and not isExpired(ds, r, now) then
      out[#out + 1] = r
    end
  end
  table.sort(out, function(a, b) return (a.u or 0) > (b.u or 0) end)
  return out
end

---------------------------------------------------------------------------
-- Ménage
---------------------------------------------------------------------------
function Store:Purge()
  if not self.data then return 0 end
  local now, n = DR.Util.Now(), 0
  for _, ds in ipairs(Store.DATASETS) do
    for key, r in pairs(self.data[ds]) do
      if type(r) ~= "table" or isExpired(ds, r, now) then
        self.data[ds][key] = nil
        n = n + 1
      end
    end
  end
  return n
end

-- Enregistrements reçus ou modifiés ici depuis une date (pour le pont).
function Store:ChangedSince(ds, since)
  local out = {}
  if not self.data then return out end
  local now = DR.Util.Now()
  for _, r in pairs(self.data[ds]) do
    if (r._r or r.u or 0) > since and not isExpired(ds, r, now) then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return (a.u or 0) < (b.u or 0) end)
  return out
end
