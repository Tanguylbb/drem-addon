-- Dernier Rempart : point d'entrée.
-- Espace de noms partagé, bus d'événements du jeu, bus de messages internes,
-- minuteurs, base de sauvegarde et commande /rempart.

local ADDON, DR = ...
_G.DernierRempart = DR

DR.name = ADDON
DR.PROTOCOL = 1
DR.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
DR.SITE = "dernier-rempart.eu"

local function readVersion()
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local v = getMeta and getMeta(ADDON, "Version")
  if not v or v == "" or v:find("@", 1, true) then v = "0.2.0" end
  return v
end
DR.version = readVersion()

---------------------------------------------------------------------------
-- Événements du jeu
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local gameHandlers = {}

function DR:On(event, fn)
  local list = gameHandlers[event]
  if not list then
    list = {}
    gameHandlers[event] = list
    eventFrame:RegisterEvent(event)
  end
  list[#list + 1] = fn
end

local function safeCall(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then DR:Debug("Erreur : " .. tostring(err)) end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = gameHandlers[event]
  if not list then return end
  for i = 1, #list do safeCall(list[i], event, ...) end
end)

---------------------------------------------------------------------------
-- Messages internes (entre modules et interface)
---------------------------------------------------------------------------
local listeners = {}

function DR:Listen(name, fn)
  local list = listeners[name]
  if not list then list = {}; listeners[name] = list end
  list[#list + 1] = fn
end

function DR:Emit(name, ...)
  local list = listeners[name]
  if not list then return end
  for i = 1, #list do safeCall(list[i], ...) end
end

---------------------------------------------------------------------------
-- Minuteurs
---------------------------------------------------------------------------
function DR.After(seconds, fn)
  C_Timer.After(seconds, function() safeCall(fn) end)
end

function DR.Every(seconds, fn)
  return C_Timer.NewTicker(seconds, function() safeCall(fn) end)
end

-- Regroupe les appels rapprochés : fn ne part qu'une fois, `delay` secondes
-- après le dernier appel.
function DR.Debounce(delay, fn)
  local lastCall, scheduled = 0, false
  local function fire()
    local wait = lastCall + delay - GetTime()
    if wait > 0.01 then
      C_Timer.After(wait, fire)
    else
      scheduled = false
      safeCall(fn)
    end
  end
  return function()
    lastCall = GetTime()
    if not scheduled then
      scheduled = true
      C_Timer.After(delay, fire)
    end
  end
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------
DR.modules = {}

function DR:NewModule(name)
  local mod = { name = name }
  self.modules[#self.modules + 1] = mod
  self[name] = mod
  return mod
end

---------------------------------------------------------------------------
-- Messages dans la fenêtre de discussion
---------------------------------------------------------------------------
local PREFIX = "|cffD4A72C[Dernier Rempart]|r "

function DR:Print(msg)
  local chat = DEFAULT_CHAT_FRAME or ChatFrame1
  if chat then chat:AddMessage(PREFIX .. tostring(msg)) end
end

function DR:Debug(msg)
  if self.db and self.db.settings and self.db.settings.debug then
    self:Print("|cff9AA6BA" .. tostring(msg) .. "|r")
  end
end

---------------------------------------------------------------------------
-- Base de sauvegarde (commune au compte)
---------------------------------------------------------------------------
local DEFAULT_SETTINGS = {
  sharePosition = true,
  showMapPins = true,
  minimap = { angle = 215, hide = false },
  window = nil,
  scale = 1,
  debug = false,
}

local function fill(target, defaults)
  for k, v in pairs(defaults) do
    if target[k] == nil then
      if type(v) == "table" then
        target[k] = {}
        fill(target[k], v)
      else
        target[k] = v
      end
    elseif type(v) == "table" and type(target[k]) == "table" then
      fill(target[k], v)
    end
  end
end

function DR:InitDB()
  local db = _G.DernierRempartDB
  if type(db) ~= "table" then db = {} end
  db.schema = db.schema or 1
  if not db.accountId then db.accountId = DR.Util.RandomId(10) end
  db.settings = db.settings or {}
  fill(db.settings, DEFAULT_SETTINGS)
  db.guilds = db.guilds or {}
  db.myChars = db.myChars or {}   -- persos du compte, lus en jeu
  db.prefs = db.prefs or {}       -- préférences par perso (rôle par défaut)
  _G.DernierRempartDB = db
  self.db = db
end

-- Base propre à la guilde du perso connecté.
function DR:GetGuildDB(key)
  key = key or self.guildKey
  if not key then return nil end
  local g = self.db.guilds[key]
  if not g then
    g = {}
    self.db.guilds[key] = g
  end
  g.data = g.data or {}
  g.pont = g.pont or { lastExportAt = 0, lastImportAt = 0 }
  return g
end

---------------------------------------------------------------------------
-- Démarrage
---------------------------------------------------------------------------
DR:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  DR:InitDB()
  for _, mod in ipairs(DR.modules) do
    if mod.OnInit then safeCall(mod.OnInit, mod) end
  end
end)

DR:On("PLAYER_LOGIN", function()
  DR.playerName = DR.Util.FullName(UnitName("player"))
  for _, mod in ipairs(DR.modules) do
    if mod.OnLogin then safeCall(mod.OnLogin, mod) end
  end
  DR:Print("chargé. |cffFFFFFF/rempart|r pour ouvrir.")
end)

---------------------------------------------------------------------------
-- Commande /rempart
---------------------------------------------------------------------------
local HELP = {
  "/rempart : ouvrir ou fermer la fenêtre",
  "/rempart sorties | artisans | carte | persos | pont : ouvrir un onglet",
  "/rempart synchro : demander les dernières données à la guilde",
  "/rempart position : partager ou non ta position avec la guilde",
  "/rempart minimap : afficher ou cacher le bouton de la minicarte",
  "/rempart version : version de l'add-on",
}

function DR:HandleSlash(input)
  local cmd = (input or ""):lower():match("^%s*(%S*)") or ""
  if cmd == "" then
    if DR.UI and DR.UI.Toggle then DR.UI:Toggle() end
  elseif cmd == "sorties" or cmd == "artisans" or cmd == "carte" or cmd == "persos" or cmd == "pont" then
    if DR.UI and DR.UI.Open then DR.UI:Open(cmd) end
  elseif cmd == "synchro" or cmd == "sync" then
    if DR.Sync then DR.Sync:Request("manuel") end
    DR:Print("demande de synchro envoyée à la guilde.")
  elseif cmd == "position" then
    local s = DR.db.settings
    s.sharePosition = not s.sharePosition
    DR:Emit("SETTINGS_CHANGED", "sharePosition")
    DR:Print(s.sharePosition and "ta position est partagée avec la guilde." or "ta position n'est plus partagée.")
  elseif cmd == "minimap" then
    local m = DR.db.settings.minimap
    m.hide = not m.hide
    DR:Emit("SETTINGS_CHANGED", "minimap")
  elseif cmd == "version" then
    DR:Print("version " .. DR.version .. " (protocole " .. DR.PROTOCOL .. ").")
  elseif cmd == "debug" then
    DR.db.settings.debug = not DR.db.settings.debug
    DR:Print("mode débogage : " .. (DR.db.settings.debug and "oui" or "non"))
  else
    for _, line in ipairs(HELP) do DR:Print(line) end
  end
end

SLASH_DERNIERREMPART1 = "/rempart"
SLASH_DERNIERREMPART2 = "/drem"
SlashCmdList.DERNIERREMPART = function(input) DR:HandleSlash(input) end

-- Boîte des add-ons (menu de la minicarte du client moderne).
function DernierRempart_OnAddonCompartmentClick()
  if DR.UI and DR.UI.Toggle then DR.UI:Toggle() end
end

function DernierRempart_OnAddonCompartmentEnter(_, button)
  if DR.MinimapButton and DR.MinimapButton.ShowTooltip then
    DR.MinimapButton:ShowTooltip(button)
  end
end

function DernierRempart_OnAddonCompartmentLeave()
  if GameTooltip then GameTooltip:Hide() end
end
