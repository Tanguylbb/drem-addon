-- Pont entre le jeu et dernier-rempart.eu, tenu par les officiers.
--
-- Un add-on n'a pas accès à internet : les données passent par un code à
-- copier-coller, "DR2:" suivi de JSON encodé en Base64. Le format est décrit
-- dans docs/PONT.md.
--   Site -> jeu : l'officier colle le code du site, l'add-on montre ce qui va
--                 changer, puis l'applique et le diffuse à la guilde.
--   Jeu -> site : l'add-on fabrique un code avec ce qui a changé depuis le
--                 dernier code, l'officier le colle sur le site.
-- Coller deux fois le même code ne compte rien deux fois : chaque
-- enregistrement porte sa date, la plus récente gagne.

local _, DR = ...
local Bridge = DR:NewModule("Bridge")
local Util, Store, Json, Base64 = DR.Util, DR.Store, DR.Json, DR.Base64

Bridge.MAGIC = "DR2:"
Bridge.FORMAT = 2

-- Ce que le site envoie, ce que le jeu renvoie.
Bridge.FROM_SITE = { "events", "signups", "orders", "votes", "meta", "goals" }
Bridge.TO_SITE = { "events", "signups", "chars", "recipes", "orders", "votes", "goals", "gifts" }

Bridge.LABELS = {
  events = "sorties", signups = "inscriptions", chars = "fiches perso", recipes = "listes de recettes",
  catalog = "catalogues", orders = "commandes", votes = "soutiens", meta = "réglages",
  goals = "objectifs", gifts = "dons",
}
-- Singulier, pour « 1 sortie » (le pluriel est LABELS).
Bridge.LABELS_ONE = {
  events = "sortie", signups = "inscription", chars = "fiche perso", recipes = "liste de recettes",
  catalog = "catalogue", orders = "commande", votes = "soutien", meta = "réglage",
  goals = "objectif", gifts = "don",
}

-- « 3 inscriptions, 1 commande, 2 fiches perso » à partir de { signups = 3, … }.
function Bridge.CountsText(counts)
  local parts = {}
  for _, ds in ipairs({ "events", "signups", "orders", "votes", "chars", "recipes", "goals", "gifts", "meta" }) do
    local n = counts and tonumber(counts[ds])
    if n and n > 0 then
      parts[#parts + 1] = n .. " " .. (n > 1 and Bridge.LABELS[ds] or Bridge.LABELS_ONE[ds])
    end
  end
  return table.concat(parts, ", ")
end

local function pontDB()
  local g = DR:GetGuildDB()
  return g and g.pont
end

---------------------------------------------------------------------------
-- Codage
---------------------------------------------------------------------------
function Bridge.Encode(payload)
  return Bridge.MAGIC .. Base64.Encode(Json.Encode(payload, true))
end

-- Rend la table, ou nil et un message clair.
function Bridge.Decode(code)
  code = (code or ""):gsub("%s+", "")
  if code == "" then return nil, "Colle d'abord le code du site." end
  local magic = code:sub(1, 4)
  if magic == "DR1:" then
    return nil, "Ce code DR1 sert à la fiche perso sur le site, pas ici. Prends le code « Pont jeu » du site (DR2)."
  end
  if magic ~= Bridge.MAGIC then return nil, "Ce n'est pas un code du Pont (il doit commencer par DR2:)." end
  local raw = Base64.Decode(code:sub(5))
  if not raw then return nil, "Le code est abîmé : recopie-le en entier depuis le site." end
  local payload, err = Json.Decode(raw)
  if type(payload) ~= "table" then
    return nil, "Le code est incomplet ou abîmé (" .. tostring(err) .. "). Recopie-le en entier."
  end
  if tonumber(payload.v) ~= Bridge.FORMAT then
    return nil, "Version du code inconnue (" .. tostring(payload.v) .. "). Mets l'add-on à jour."
  end
  return payload
end

---------------------------------------------------------------------------
-- Site -> jeu
---------------------------------------------------------------------------
-- Ce qui vient du site est signé "site", et les sorties marquées comme telles.
local function fromSite(ds, rec)
  if type(rec) ~= "table" then return nil end
  local r = {}
  for k, v in pairs(rec) do r[k] = v end
  r.by = r.by or "site"
  if ds == "events" then r.src = r.src or "site" end
  return r
end

-- Aperçu : ce qui changerait, sans rien écrire.
function Bridge:Preview(payload)
  local report = { total = 0, lines = {}, newer = 0, same = 0, older = 0, rejected = 0 }
  for _, ds in ipairs(Bridge.FROM_SITE) do
    local list = payload[ds]
    if type(list) == "table" then
      local add, upd, del = 0, 0, 0
      for _, rec in ipairs(list) do
        local clean = Store.Sanitize(ds, fromSite(ds, rec))
        if not clean then
          report.rejected = report.rejected + 1
        else
          local old = Store:GetRaw(ds, Store.KeyOf(ds, clean))
          if old and Store.Canon(old) == Store.Canon(clean) then
            report.same = report.same + 1
          elseif old and not Store.Newer(clean, old) then
            report.older = report.older + 1
          else
            report.newer = report.newer + 1
            if clean.del then del = del + 1 elseif old and not old.del then upd = upd + 1 else add = add + 1 end
          end
        end
      end
      if add + upd + del > 0 then
        local parts = {}
        if add > 0 then parts[#parts + 1] = add .. " nouvelle(s)" end
        if upd > 0 then parts[#parts + 1] = upd .. " modifiée(s)" end
        if del > 0 then parts[#parts + 1] = del .. " supprimée(s)" end
        report.lines[#report.lines + 1] = Bridge.LABELS[ds] .. " : " .. table.concat(parts, ", ")
        report.total = report.total + add + upd + del
      end
    end
  end
  report.at = tonumber(payload.at)
  return report
end

-- via : "manuel" (code collé) ou "relais" (programme sur le PC d'un officier).
function Bridge:Import(payload, via)
  if not DR.Guild:IAmOfficer() then return nil, "Le pont est réservé aux officiers." end
  if not Store:IsReady() then return nil, "Pas de guilde chargée." end
  local counts = { taken = 0 }
  for _, ds in ipairs(Bridge.FROM_SITE) do
    local list = payload[ds]
    if type(list) == "table" then
      for _, raw in ipairs(list) do
        local rec = fromSite(ds, raw)
        if rec then
          if Store:Merge(ds, rec, "import") == "new" then
            counts.taken = counts.taken + 1
            counts[ds] = (counts[ds] or 0) + 1
          end
        end
      end
    end
  end
  local siteAt = tonumber(payload.at) or Util.Now()
  local meta = Store:Get("meta", "site")
  if not meta or (meta.at or 0) < siteAt then
    Store:Put("meta", { id = "site", at = siteAt, imp = DR.playerName })
  end
  local p = pontDB()
  if p then
    p.lastImportAt = Util.Now()
    p.lastApply = { at = siteAt, done = Util.Now(), counts = Util.Copy(counts), via = via or "manuel" }
  end
  DR:Emit("BRIDGE_IMPORTED", counts)
  DR:Emit("EVENTS_CHANGED")
  return counts
end

---------------------------------------------------------------------------
-- Jeu -> site
---------------------------------------------------------------------------
function Bridge:PendingCount(all)
  local p = pontDB()
  local since = all and 0 or (p and p.lastExportAt or 0)
  local n, others = 0, 0
  for _, ds in ipairs(Bridge.TO_SITE) do
    for _, rec in ipairs(Store:ChangedSince(ds, since)) do
      if rec.by ~= "site" then
        n = n + 1
        if rec.by ~= DR.playerName and not DR.Profile:IsMine(rec.by) then others = others + 1 end
      end
    end
  end
  return n, others
end

-- since : à partir de quand (sinon : depuis le dernier code, ou tout si `all`).
function Bridge:BuildExport(all, sinceOverride)
  local p = pontDB()
  local since = sinceOverride or (all and 0 or (p and p.lastExportAt or 0))
  local payload = {
    v = Bridge.FORMAT,
    src = "jeu",
    g = DR.Guild.name,
    by = DR.playerName,
    av = DR.version,
    at = Util.Now(),
    since = since,
  }
  local n = 0
  for _, ds in ipairs(Bridge.TO_SITE) do
    local list = {}
    for _, rec in ipairs(Store:ChangedSince(ds, since)) do
      if rec.by ~= "site" then
        local c = {}
        for k, v in pairs(rec) do
          if type(k) ~= "string" or k:sub(1, 1) ~= "_" then c[k] = v end
        end
        list[#list + 1] = c
      end
    end
    if #list > 0 then
      payload[ds] = list
      n = n + #list
    end
  end
  return payload, n
end

function Bridge:Export(all)
  if not DR.Guild:IAmOfficer() then return nil, "Le pont est réservé aux officiers." end
  local payload, n = self:BuildExport(all)
  local code = Bridge.Encode(payload)
  local p = pontDB()
  if p then
    p.lastExportAt = payload.at
    p.lastExportCount = n
  end
  -- Gardé dans la sauvegarde : un relais automatique pourra le lire plus tard.
  DR.db.outbox = { code = code, at = payload.at, guild = DR.guildKey, n = n }
  return code, n
end

---------------------------------------------------------------------------
-- Relais automatique (programme sur le PC d'un officier, voir docs/RELAIS.md)
---------------------------------------------------------------------------
-- Le programme lit la sauvegarde de l'add-on (champ outbox), envoie au site,
-- et dépose en retour un mini add-on « DernierRempart_Data » avec ce que le
-- site a de nouveau :
--   DernierRempartData = { v = 1, at = <heure des données du site>,
--     code = "DR2:…", sent = { at = <heure du code accepté par le site>,
--     when = <heure d'envoi>, counts = { signups = 3 } } }
-- Le jeu n'écrit sa sauvegarde qu'à la déconnexion ou au /reload : rien n'est
-- instantané, et c'est pour ça que le copier-coller reste.
local MAX_RELAY_CODE = 800000
local RELAY_META = "relay:"

-- Les données déposées par le relais, si elles ont la bonne forme.
function Bridge:RelayData()
  local d = _G.DernierRempartData
  if type(d) ~= "table" then return nil end
  if tonumber(d.v) ~= 1 then return nil end
  local out = { at = tonumber(d.at), sent = nil }
  if type(d.code) == "string" and #d.code <= MAX_RELAY_CODE then out.code = d.code end
  if type(d.sent) == "table" and tonumber(d.sent.at) then
    out.sent = { at = tonumber(d.sent.at), when = tonumber(d.sent.when), counts = {} }
    if type(d.sent.counts) == "table" then
      for ds in pairs(Bridge.LABELS) do
        local n = tonumber(d.sent.counts[ds])
        if n and n >= 0 and n < 1000000 then out.sent.counts[ds] = math.floor(n) end
      end
    end
  end
  return out
end

-- Prend ce que le relais a déposé : applique le code du site (officiers
-- seulement) et retient ce que le site a bien reçu. Rend vrai si quelque chose
-- a été fait.
function Bridge:ApplyRelay()
  local p = pontDB()
  if not p or not Store:IsReady() then return false end
  local d = self:RelayData()
  if not d then return false end
  p.relayEver = true
  local did = false
  if d.sent and d.sent.at > (p.relayAck or 0) then
    p.relayAck = d.sent.at
    p.lastSent = d.sent
    did = true
  end
  if d.code and d.at and d.at > (p.relayDataAt or 0) and DR.Guild:IAmOfficer() then
    local payload = Bridge.Decode(d.code)
    if payload then
      local counts = Bridge:Import(payload, "relais")
      if counts then
        p.relayDataAt = d.at
        self:NoteRelayer()
        did = true
      end
    else
      p.relayDataAt = d.at -- code abîmé : on ne le réessaie pas à chaque connexion
    end
  end
  if did then DR:Emit("BRIDGE_RELAY") end
  return did
end

-- « Cet officier assure le relais » : visible de tous, pour savoir qui est en secours.
function Bridge:NoteRelayer()
  local id = RELAY_META .. tostring(DR.playerName)
  local m = Store:Get("meta", id)
  local now = Util.Now()
  if m and now - (m.at or 0) < 6 * 3600 then return end
  Store:Put("meta", { id = id, at = now })
end

-- Officiers qui assurent le relais, le plus récent d'abord : { name, at, me }.
function Bridge:Relayers()
  local out = {}
  for _, m in ipairs(Store:List("meta", function(r) return r.id:sub(1, #RELAY_META) == RELAY_META end)) do
    local name = m.id:sub(#RELAY_META + 1)
    if (m.at or 0) > Util.Now() - 30 * 86400 then
      out[#out + 1] = { name = name, at = m.at or 0, me = DR.Profile:IsMine(name) or name == DR.playerName }
    end
  end
  table.sort(out, function(a, b) return a.at > b.at end)
  return out
end

-- État du relais pour l'onglet Pont.
--   level : "none" (pas de relais), "ok" (connecté), "late" (en retard), "stopped"
function Bridge:RelayStatus()
  local p = pontDB() or {}
  local present = type(_G.DernierRempartData) == "table" or p.relayEver
  local status = { present = present, lastApply = p.lastApply, lastSent = p.lastSent, relayers = self:Relayers() }
  if not present then
    status.level = "none"
    return status
  end
  local d = self:RelayData()
  local at = (d and d.at) or (p.lastApply and p.lastApply.at) or 0
  local age = Util.Now() - at
  if at == 0 then status.level = "late"
  elseif age < 12 * 3600 then status.level = "ok"
  elseif age < 72 * 3600 then status.level = "late"
  else status.level = "stopped" end
  status.dataAt = at
  return status
end

-- Avant la déconnexion (et le /reload) : prépare ce que le relais enverra au
-- site. Tout ce qui a changé depuis ce que le site a déjà reçu : le code ne
-- dépend pas du copier-coller.
function Bridge:RefreshOutbox()
  if not (DR.Guild:IAmOfficer() and Store:IsReady()) then return end
  local p = pontDB()
  local payload, n = self:BuildExport(false, p and p.relayAck or 0)
  DR.db.outbox = { code = Bridge.Encode(payload), at = payload.at, guild = DR.guildKey, n = n, relay = true }
end

function Bridge:OnLogin()
  DR:On("PLAYER_LOGOUT", function() pcall(self.RefreshOutbox, self) end)
  local function apply() pcall(self.ApplyRelay, self) end
  -- Le rang d'officier n'est connu qu'une fois la liste de guilde lue.
  DR:Listen("GUILD_READY", function() DR.After(4, apply) end)
  DR:Listen("ROSTER_UPDATED", function()
    if not self.relayChecked and DR.Guild.myRankIndex then
      self.relayChecked = true
      DR.After(2, apply)
    end
  end)
end

-- Fraîcheur des données venues du site : "vert", "orange" ou "rouge".
function Bridge:Freshness()
  local meta = Store:Get("meta", "site")
  if not meta or not meta.at then return "rouge", nil end
  local age = Util.Now() - meta.at
  if age < 24 * 3600 then return "vert", meta.at end
  if age < 72 * 3600 then return "orange", meta.at end
  return "rouge", meta.at
end
