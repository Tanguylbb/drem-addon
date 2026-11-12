-- Synchronisation entre les add-ons de la guilde.
--
-- 1. Chaque changement fait en jeu part tout de suite à la guilde ("up").
-- 2. À la connexion (puis toutes les 15 minutes), l'add-on envoie une
--    empreinte de ses données découpées en 16 seaux ("sq"). Un membre en
--    ligne dont les seaux diffèrent répond avec le contenu de ces seaux
--    ("sc" pour réserver la réponse, "sr" pour les données, "se" pour finir).
-- 3. Celui qui a demandé renvoie alors ce que l'autre n'avait pas.
-- Un seul membre répond à chaque demande : les autres voient la réservation
-- et se taisent.

local _, DR = ...
local Sync = DR:NewModule("Sync")
local Store, Util = DR.Store, DR.Util

local REQUEST_EVERY = 15 * 60
local BATCH_BYTES = 1800

local myRequests = {}     -- id -> { at, received = { ds = { key = rec } } }
local pendingReplies = {} -- id -> { cancelled }
local pendingAcks = {}    -- id -> { cancelled }
local pendingPush = {}    -- ds|key -> true
local outgoing = {}       -- ds -> { key -> rec } en attente d'envoi groupé
Sync.lastRequest, Sync.lastData = 0, 0
Sync.lastReply = nil      -- { by, at } : le dernier à avoir répondu à une de mes demandes
Sync.newerVersion = nil

function Sync:OnLogin()
  DR:Listen("COMM_MESSAGE", function(msg, sender) self:OnMessage(msg, sender) end)
  DR:Listen("DATA_CHANGED", function(ds, key, rec, _, origin)
    if origin == "local" or origin == "import" then self:Queue(ds, rec) end
    if origin ~= "local" then Sync.lastData = Util.Now() end
  end)
  DR:Listen("GUILD_READY", function()
    DR.After(8 + math.random() * 4, function() self:Request("connexion") end)
  end)
  self.flush = DR.Debounce(0.4, function() self:Flush() end)
  DR.Every(REQUEST_EVERY, function()
    if Store:IsReady() then self:Request("périodique") end
  end)
end

---------------------------------------------------------------------------
-- Envoi des changements faits ici
---------------------------------------------------------------------------
function Sync:Queue(ds, rec)
  local key = Store.KeyOf(ds, rec)
  if not key then return end
  outgoing[ds] = outgoing[ds] or {}
  outgoing[ds][key] = rec
  self.flush()
end

-- Diffuse tout de suite un ou plusieurs enregistrements.
function Sync:Broadcast(ds, recs)
  if recs.u then recs = { recs } end
  for _, r in ipairs(recs) do self:Queue(ds, r) end
end

local function batches(recs)
  local out, current, size = {}, {}, 0
  for _, r in ipairs(recs) do
    local s = #DR.Json.Encode(r, true)
    if size + s > BATCH_BYTES and #current > 0 then
      out[#out + 1] = current
      current, size = {}, 0
    end
    current[#current + 1] = r
    size = size + s
  end
  if #current > 0 then out[#out + 1] = current end
  return out
end
Sync.Batches = batches

local function stripList(recs)
  local out = {}
  for i, r in ipairs(recs) do
    local c = {}
    for k, v in pairs(r) do
      if type(k) ~= "string" or k:sub(1, 1) ~= "_" then c[k] = v end
    end
    out[i] = c
  end
  return out
end

function Sync:Flush(priority)
  for ds, map in pairs(outgoing) do
    local list = {}
    for _, r in pairs(map) do list[#list + 1] = r end
    outgoing[ds] = nil
    for _, batch in ipairs(batches(stripList(list))) do
      DR.Comm:Send({ t = "up", ds = ds, r = batch }, priority or "high")
    end
  end
end

---------------------------------------------------------------------------
-- Demande de synchro
---------------------------------------------------------------------------
function Sync:Request(reason)
  if not Store:IsReady() or not IsInGuild() then return end
  local id = Util.RandomId(6)
  local digests = {}
  for _, ds in ipairs(Store.DATASETS) do
    digests[ds] = Store.DigestToString(Store:Digest(ds))
  end
  myRequests[id] = { at = Util.Now(), received = {} }
  self.lastRequest = Util.Now()
  DR.Comm:Send({ t = "sq", id = id, av = DR.version, d = digests }, "high")
  DR:Debug("synchro demandée (" .. tostring(reason) .. ")")
  -- Oublie les vieilles demandes.
  for rid, req in pairs(myRequests) do
    if req.at < Util.Now() - 600 then myRequests[rid] = nil end
  end
end

---------------------------------------------------------------------------
-- Droits : qui peut écrire quoi
---------------------------------------------------------------------------
function Sync:Accept(ds, rec)
  local Guild = DR.Guild
  if not next(Guild.members) then return true end -- liste pas encore chargée
  if ds == "events" then
    return Guild:IsOfficer(rec.by) or rec.by == "site"
  end
  if ds == "meta" then
    if rec.id == "config" then
      local m = Guild:Get(rec.by or "")
      return m ~= nil and m.rankIndex == 0
    end
    -- « La banque a été lue » : n'importe quel membre qui ouvre la banque.
    if rec.id == "bank" then return true end
    return Guild:IsOfficer(rec.by) or rec.by == "site"
  end
  -- Les objectifs de l'effort de guerre sont fixés par les officiers.
  if ds == "goals" then
    return Guild:IsOfficer(rec.by) or rec.by == "site"
  end
  return true
end

-- Fusionne une liste reçue ; programme une correction quand l'autre est en
-- retard sur nous.
function Sync:MergeList(ds, recs, received)
  if not Store.IsDataset(ds) or type(recs) ~= "table" then return 0 end
  local taken = 0
  for _, rec in ipairs(recs) do
    if type(rec) == "table" and self:Accept(ds, rec) then
      local key = Store.KeyOf(ds, rec)
      if key then
        if received then received[key] = rec end
        pendingPush[ds .. "|" .. key] = nil
        local res = Store:Merge(ds, rec, "remote")
        if res == "new" then
          taken = taken + 1
        elseif res == "older" then
          self:SchedulePush(ds, key)
        end
      end
    end
  end
  return taken
end

-- Un autre a une version plus ancienne : on renverra la nôtre, après un
-- délai au hasard (si quelqu'un l'a fait entre-temps, on ne fait rien).
function Sync:SchedulePush(ds, key)
  local k = ds .. "|" .. key
  if pendingPush[k] then return end
  pendingPush[k] = true
  DR.After(2 + math.random() * 8, function()
    if not pendingPush[k] then return end
    pendingPush[k] = nil
    local rec = Store:GetRaw(ds, key)
    if rec then self:Queue(ds, rec) end
  end)
end

---------------------------------------------------------------------------
-- Réception
---------------------------------------------------------------------------
function Sync:OnMessage(msg, sender)
  if msg.av and Util.CompareVersions(msg.av, DR.version) > 0 then
    if not self.newerVersion or Util.CompareVersions(msg.av, self.newerVersion) > 0 then
      self.newerVersion = msg.av
      DR:Print("une version plus récente de l'add-on existe (" .. tostring(msg.av)
        .. "). Mets-le à jour avec CurseForge.")
      DR:Emit("NEWER_VERSION", msg.av)
    end
  end
  -- Format d'échange différent (add-on trop ancien ou trop récent) : on n'y touche pas.
  if (msg.v or 1) ~= DR.PROTOCOL then return end
  if not Store:IsReady() then return end
  local t = msg.t
  if t == "up" then
    if self:MergeList(msg.ds, msg.r) > 0 then DR:Emit("SYNC_RECEIVED", msg.ds) end
  elseif t == "sq" then
    self:OnRequest(msg, sender)
  elseif t == "sc" then
    local p = pendingReplies[msg.id]
    if p then p.cancelled = true end
    self:NoteReply(msg.id, sender)
  elseif t == "sa" then
    -- « Je n'ai rien de plus que toi » : un seul membre le dit, les autres se taisent.
    local p = pendingAcks[msg.id]
    if p then p.cancelled = true end
    self:NoteReply(msg.id, sender)
  elseif t == "sr" then
    local req = myRequests[msg.id]
    local received
    if req then
      req.received[msg.ds] = req.received[msg.ds] or {}
      received = req.received[msg.ds]
    end
    self:NoteReply(msg.id, sender)
    if self:MergeList(msg.ds, msg.r, received) > 0 then DR:Emit("SYNC_RECEIVED", msg.ds) end
  elseif t == "se" then
    self:OnResponseEnd(msg)
  end
end

-- Quelqu'un répond à une de MES demandes : on garde qui et quand.
function Sync:NoteReply(id, sender)
  if not myRequests[id] then return end
  self.lastReply = { by = sender, at = Util.Now() }
  DR:Emit("SYNC_REPLY", sender)
end

-- État de la synchro, en une phrase pour l'onglet Sorties.
-- level : "ok" (à jour), "wait" (en cours), "alone" (personne d'autre), "late" (pas de réponse).
function Sync:Status()
  local now = Util.Now()
  if not Store:IsReady() then
    return { level = "wait", text = IsInGuild() and "Chargement de la guilde…" or "Pas de guilde : rien n'est partagé." }
  end
  local withAddon = DR.Guild:OnlineWithAddon()
  local others = math.max(0, withAddon - 1)
  local tail = " · " .. withAddon .. " membre" .. (withAddon > 1 and "s ont" or " a") .. " l'add-on en ligne"
  local reply = self.lastReply
  if reply and now - reply.at < 30 * 60 then
    return { level = "ok", text = "À jour : dernière réponse de " .. Util.ShortName(reply.by) .. " " .. Util.Ago(reply.at) .. tail }
  end
  if self.lastRequest == 0 or now - self.lastRequest < 20 then
    return { level = "wait", text = "Synchro en cours…" .. tail }
  end
  if others == 0 then
    return { level = "alone", text = "Personne d'autre n'a l'add-on en ligne : rien à recevoir pour l'instant." }
  end
  return { level = "late", text = "Pas de réponse depuis " .. Util.Ago(self.lastRequest):gsub("^il y a ", "") .. " : redemande à la guilde." .. tail }
end

-- Quelqu'un demande : si nos données diffèrent, on se propose pour répondre.
function Sync:OnRequest(msg, sender)
  if type(msg.d) ~= "table" or type(msg.id) ~= "string" then return end
  local diffs, any = {}, false
  for _, ds in ipairs(Store.DATASETS) do
    local theirs = Store.DigestFromString(msg.d[ds])
    if theirs then
      local b = Store:DiffBuckets(ds, theirs)
      if #b > 0 then diffs[ds] = b; any = true end
    end
  end
  if not any then
    -- Rien à envoyer : un seul membre le dit, pour que le demandeur sache que
    -- la guilde a répondu et qu'il est à jour.
    local ack = { cancelled = false }
    pendingAcks[msg.id] = ack
    DR.After(3 + math.random() * 5, function()
      pendingAcks[msg.id] = nil
      if ack.cancelled then return end
      DR.Comm:Send({ t = "sa", id = msg.id, to = sender }, "bulk")
    end)
    return
  end
  local reply = { cancelled = false }
  pendingReplies[msg.id] = reply
  local officer = DR.Guild:IAmOfficer()
  local delay = officer and (0.5 + math.random() * 1.5) or (2 + math.random() * 4)
  DR.After(delay, function()
    pendingReplies[msg.id] = nil
    if reply.cancelled then return end
    self:SendResponse(msg.id, sender, diffs)
  end)
end

function Sync:SendResponse(id, requester, diffs)
  -- Toute la réponse sur le même préfixe : la fin ("se") arrive après les données.
  local lane = DR.Comm:PickPrefix()
  DR.Comm:Send({ t = "sc", id = id, to = requester }, "high", lane)
  for ds, buckets in pairs(diffs) do
    local recs = stripList(Store:RecordsInBuckets(ds, buckets))
    for _, batch in ipairs(batches(recs)) do
      DR.Comm:Send({ t = "sr", id = id, ds = ds, r = batch }, "bulk", lane)
    end
  end
  DR.Comm:Send({ t = "se", id = id, b = diffs }, "bulk", lane)
  DR:Debug("réponse de synchro envoyée à " .. tostring(requester))
end

-- Fin d'une réponse à NOTRE demande : on renvoie ce que l'autre n'a pas.
function Sync:OnResponseEnd(msg)
  local req = myRequests[msg.id]
  if not req or type(msg.b) ~= "table" then return end
  myRequests[msg.id] = nil
  for ds, buckets in pairs(msg.b) do
    if Store.IsDataset(ds) and type(buckets) == "table" then
      local received = req.received[ds] or {}
      local push = {}
      for _, rec in ipairs(Store:RecordsInBuckets(ds, buckets)) do
        local key = Store.KeyOf(ds, rec)
        local theirs = received[key]
        if not theirs or Store.Newer(rec, theirs) then push[#push + 1] = rec end
      end
      if #push > 0 then
        for _, batch in ipairs(batches(stripList(push))) do
          DR.Comm:Send({ t = "up", ds = ds, r = batch }, "bulk")
        end
      end
    end
  end
  DR:Emit("SYNC_DONE")
end
