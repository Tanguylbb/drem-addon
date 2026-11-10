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
Bridge.FROM_SITE = { "events", "signups", "orders", "votes", "meta" }
Bridge.TO_SITE = { "events", "signups", "chars", "recipes", "orders", "votes" }

Bridge.LABELS = {
  events = "sorties", signups = "inscriptions", chars = "fiches perso", recipes = "listes de recettes",
  catalog = "catalogues", orders = "commandes", votes = "soutiens", meta = "réglages",
}

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

function Bridge:Import(payload)
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
  if p then p.lastImportAt = Util.Now() end
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

function Bridge:BuildExport(all)
  local p = pontDB()
  local since = all and 0 or (p and p.lastExportAt or 0)
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

-- Fraîcheur des données venues du site : "vert", "orange" ou "rouge".
function Bridge:Freshness()
  local meta = Store:Get("meta", "site")
  if not meta or not meta.at then return "rouge", nil end
  local age = Util.Now() - meta.at
  if age < 24 * 3600 then return "vert", meta.at end
  if age < 72 * 3600 then return "orange", meta.at end
  return "rouge", meta.at
end
