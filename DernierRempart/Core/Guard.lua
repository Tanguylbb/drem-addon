-- Garde-fous du client Forever (règles de Midnight).
--
-- Un appel refusé par le jeu ne lève pas d'erreur Lua : il affiche un texte
-- rouge (ADDON_ACTION_BLOCKED) ou une fenêtre qui propose de DÉSACTIVER
-- l'add-on (ADDON_ACTION_FORBIDDEN). On demande donc avant d'agir, et on garde
-- la trace de chaque refus et de chaque erreur pour /rempart rapport.

local _, DR = ...
local Guard = {}
DR.Guard = Guard

local MAX_BLOCKED, MAX_ERRORS = 20, 30

Guard.IsSecret = DR.Util.IsSecret

local function restricted(kind)
  local types = Enum and Enum.AddOnRestrictionType
  local actions = C_RestrictedActions
  if not (types and types[kind] and actions and actions.IsAddOnRestrictionActive) then return false end
  local ok, active = pcall(actions.IsAddOnRestrictionActive, types[kind])
  return ok and active == true
end

-- Les messages entre add-ons et la discussion ferment ensemble (boss, etc.).
function Guard.ChatLocked()
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and locked == true then return true end
  end
  if restricted("Chat") or restricted("Encounter") then return true end
  if IsEncounterInProgress and IsEncounterInProgress() then return true end
  return false
end

function Guard.InCombat()
  return InCombatLockdown ~= nil and InCombatLockdown() == true
end

-- Interface manette : les panneaux de Blizzard y passent par des appels
-- protégés, interdits au code d'un add-on.
function Guard.Gamepad()
  if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then return true end
  return false
end

-- Peut-on ouvrir un panneau de Blizzard (la carte du monde) ? Rend la raison sinon.
function Guard.PanelLocked()
  if Guard.InCombat() then return "en combat" end
  if Guard.Gamepad() then return "à la manette" end
  if restricted("Encounter") or restricted("ChallengeMode") or restricted("PvPMatch") then return "ici" end
  return nil
end

---------------------------------------------------------------------------
-- Trace des refus et des erreurs
---------------------------------------------------------------------------
local told = {}

local function stamp() return date and date("%d/%m %H:%M:%S") or "" end

function Guard.RecordError(err)
  local db = DR.db
  if not db then return end
  db.errors = db.errors or {}
  local text = tostring(err)
  local first = db.errors[1]
  if first and first.err == text then
    first.count = (first.count or 1) + 1
    first.at = stamp()
    return
  end
  table.insert(db.errors, 1, { at = stamp(), err = text, count = 1 })
  while #db.errors > MAX_ERRORS do table.remove(db.errors) end
end

local function recordBlocked(kind, addon, func)
  if addon ~= DR.name or not DR.db then return end
  func = tostring(func)
  DR.db.blocked = DR.db.blocked or {}
  local list = DR.db.blocked
  for _, e in ipairs(list) do
    if e.kind == kind and e.func == func then
      e.count = e.count + 1
      e.last = stamp()
      return
    end
  end
  table.insert(list, 1, {
    kind = kind, func = func, count = 1, last = stamp(),
    combat = Guard.InCombat(), stack = debugstack and debugstack(3, 8, 0) or nil,
  })
  while #list > MAX_BLOCKED do table.remove(list) end
  if not told[func] then
    told[func] = true
    DR:Print("le jeu a refusé une action de l'add-on (" .. func .. "). Rien n'est cassé. "
      .. "Tape |cffFFFFFF/rempart rapport|r et envoie le résultat à un officier.")
  end
end

DR:On("ADDON_ACTION_FORBIDDEN", function(_, addon, func) recordBlocked("interdit", addon, func) end)
DR:On("ADDON_ACTION_BLOCKED", function(_, addon, func) recordBlocked("bloqué", addon, func) end)

-- Le rapport à envoyer quand quelque chose cloche : version du jeu, état de la
-- sauvegarde, messages en attente, erreurs et refus récents.
function Guard.Report()
  local lines = {}
  local version, build, _, toc = "?", "?", nil, "?"
  if GetBuildInfo then version, build, _, toc = GetBuildInfo() end
  lines[#lines + 1] = ("Dernier Rempart %s (protocole %d) · jeu %s.%s · interface %s")
    :format(tostring(DR.version), DR.PROTOCOL, tostring(version), tostring(build), tostring(toc))
  local meta = DR.db and DR.db.meta or {}
  lines[#lines + 1] = ("Sauvegarde : %s · %d démarrage(s)")
    :format(DR.savedLoaded and "relue" or "vide au démarrage", meta.runs or 0)
  lines[#lines + 1] = ("Perso : %s · noms Forever : %s · guilde : %s")
    :format(tostring(DR.playerName), DR.Util.forever and "oui" or "non", tostring(DR.guildKey))
  if DR.Guild then
    lines[#lines + 1] = ("Liste de guilde : %d membres, %d en ligne · mon rang : %s")
      :format(DR.Guild.count or 0, DR.Guild.online or 0, tostring(DR.Guild.myRankIndex))
  end
  if DR.Comm then
    lines[#lines + 1] = ("Messages : %d envoyés, %d reçus, %d en attente%s")
      :format(DR.Comm.sent or 0, DR.Comm.received or 0, DR.Comm:Pending(),
        Guard.ChatLocked() and " · envoi fermé par le jeu" or "")
  end
  local errors = DR.db and DR.db.errors or {}
  if #errors == 0 then lines[#lines + 1] = "Aucune erreur enregistrée." end
  for i, e in ipairs(errors) do
    if i > 8 then break end
    lines[#lines + 1] = ("Erreur %s ×%d : %s"):format(e.at or "", e.count or 1, e.err)
  end
  local blocked = DR.db and DR.db.blocked or {}
  if #blocked == 0 then lines[#lines + 1] = "Le jeu n'a refusé aucune action." end
  for _, b in ipairs(blocked) do
    lines[#lines + 1] = ("Refus %s : %s %s ×%d%s"):format(b.last or "", b.kind, b.func, b.count,
      b.combat and " (en combat)" or "")
  end
  return lines
end
