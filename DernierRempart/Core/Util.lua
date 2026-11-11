-- Petits outils partagés : noms, heures en français, couleurs, tables, recherche.

local _, DR = ...
local Util = {}
DR.Util = Util

local floor, format = math.floor, string.format

---------------------------------------------------------------------------
-- Temps
---------------------------------------------------------------------------
function Util.Now()
  if GetServerTime then return GetServerTime() end
  return time()
end

local JOURS = { "Dim.", "Lun.", "Mar.", "Mer.", "Jeu.", "Ven.", "Sam." }
local JOURS_LONG = { "Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi" }
local MOIS = { "janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc." }
local MOIS_LONG = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
  "septembre", "octobre", "novembre", "décembre" }

Util.JOURS, Util.JOURS_LONG, Util.MOIS, Util.MOIS_LONG = JOURS, JOURS_LONG, MOIS, MOIS_LONG

function Util.DateParts(t)
  local d = date("*t", t)
  return {
    jour = JOURS[d.wday], jourLong = JOURS_LONG[d.wday],
    num = d.day, mois = MOIS[d.month], moisLong = MOIS_LONG[d.month],
    annee = d.year, heure = format("%02d:%02d", d.hour, d.min),
    dm = format("%02d/%02d", d.day, d.month),
  }
end

-- "Mer. 10/12 · 21:00"
function Util.ShortDate(t)
  local p = Util.DateParts(t)
  return format("%s %s · %s", p.jour, p.dm, p.heure)
end

-- "mercredi 10 décembre à 21:00"
function Util.LongDate(t)
  local p = Util.DateParts(t)
  return format("%s %d %s à %s", p.jourLong:lower(), p.num, p.moisLong, p.heure)
end

-- Durée lisible : "3 h", "2 j 20 h", "12 min", "à l'instant".
function Util.Duration(seconds)
  seconds = math.abs(seconds)
  if seconds < 60 then return nil end
  local min = floor(seconds / 60)
  if min < 60 then return min .. " min" end
  local h = floor(min / 60)
  if h < 24 then
    local rest = min % 60
    if h < 6 and rest >= 5 then return format("%d h %02d", h, rest) end
    return h .. " h"
  end
  local j = floor(h / 24)
  local rh = h % 24
  if j < 7 and rh > 0 then return format("%d j %d h", j, rh) end
  if j >= 60 then return floor(j / 30) .. " mois" end
  return j .. " j"
end

function Util.Ago(t, now)
  if not t or t == 0 then return "jamais" end
  now = now or Util.Now()
  local d = Util.Duration(now - t)
  if not d then return "à l'instant" end
  return "il y a " .. d
end

function Util.Until(t, now)
  now = now or Util.Now()
  if t <= now then return "maintenant" end
  local d = Util.Duration(t - now)
  if not d then return "dans un instant" end
  return "dans " .. d
end

-- Lit "10/12/2026" ou "10/12" et "21:00" (heure locale), rend un horodatage.
function Util.ParseDateTime(dateText, timeText, now)
  local d, m, y = (dateText or ""):match("^%s*(%d%d?)/(%d%d?)/?(%d*)%s*$")
  local hh, mm = (timeText or ""):match("^%s*(%d%d?)[:hH]?(%d*)%s*$")
  if not d or not hh then return nil end
  d, m, hh = tonumber(d), tonumber(m), tonumber(hh)
  mm = tonumber(mm) or 0
  local nowT = date("*t", now or Util.Now())
  y = tonumber(y)
  if not y then
    y = nowT.year
    -- Une date déjà passée de plus de 2 mois vise l'an prochain.
    if m < nowT.month - 2 then y = y + 1 end
  elseif y < 100 then
    y = 2000 + y
  end
  if m < 1 or m > 12 or d < 1 or d > 31 or hh > 23 or mm > 59 then return nil end
  local t = time({ year = y, month = m, day = d, hour = hh, min = mm, sec = 0 })
  local check = date("*t", t)
  if check.day ~= d or check.month ~= m then return nil end
  return t
end

---------------------------------------------------------------------------
-- Noms de persos
---------------------------------------------------------------------------
-- Sur WoW: Forever un perso s'appelle « Prénom Nom », unique dans la région,
-- et le jeu ne le donne pas partout pareil :
--   UnitName("player")      -> "Prénom"
--   UnitFullName("player")  -> "Prénom", "Nom"  (le nom à la place du royaume)
--   liste de guilde, expéditeur d'un message d'add-on -> "Prénom Nom",
--   parfois "Prénom Nom-Royaume" ou "Prénom-Nom".
-- Le nom complet d'un perso Forever est donc "Prénom Nom", sans royaume
-- (une guilde s'étale sur plusieurs royaumes liés). Sur un client à royaumes
-- classique, il reste "Nom-Royaume". Toute comparaison de noms passe par ici.
local function myRealm()
  local r = (GetNormalizedRealmName and GetNormalizedRealmName()) or nil
  if not r or r == "" then
    r = (GetRealmName and GetRealmName() or ""):gsub("[%s%-]", "")
  end
  return r
end
Util.MyRealm = myRealm

-- Vrai pour une valeur « secrète » du client Midnight (noms d'unités en
-- combat, par exemple) : la comparer ou la ranger déclenche une erreur.
function Util.IsSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end

local function squash(s)
  return (tostring(s or ""):gsub("[%s%-']", "")):lower()
end

-- Les royaumes liés de Forever ne diffèrent que par des numéros
-- ("CAM WoW EU4 Realm 7 PvE", "CAM WoW EU5 Realm 1 PvE").
function Util.RealmFamily(realm)
  return (tostring(realm or ""):gsub("[%s%-']", ""):gsub("%d+", ""))
end

local function isRealm(word)
  local w = squash(word)
  if w == "" then return false end
  if w == squash(myRealm()) or w == squash(GetRealmName and GetRealmName() or "") then return true end
  return Util.RealmFamily(w) == Util.RealmFamily(squash(myRealm()))
end

Util.forever = false       -- vrai dès qu'un nom « Prénom Nom » est vu
local known = {}           -- "prénom nom" -> "Prénom Nom" (liste de guilde)
local byFirst = {}         -- "prénom" -> "Prénom Nom", ou false si plusieurs
local myFirst, myFull

local function nameKey(s)
  return (tostring(s):gsub("%s+", " ")):lower()
end

-- La liste de guilde sert de référence pour retrouver un nom abrégé.
function Util.SetKnownNames(list)
  known, byFirst = {}, {}
  for _, full in ipairs(list) do
    if full:find(" ", 1, true) then
      Util.forever = true
      known[nameKey(full)] = full
      local first = nameKey(full):match("^(%S+)")
      if byFirst[first] == nil then byFirst[first] = full else byFirst[first] = false end
    end
  end
end

-- "Prénom" seul : mon perso, ou le seul membre de la guilde à porter ce prénom.
local function fromFirst(word)
  local k = nameKey(word)
  if myFirst and k == myFirst then return myFull end
  return byFirst[k] or nil
end

-- Nom complet du perso connecté.
function Util.PlayerName()
  local first, second
  if UnitFullName then first, second = UnitFullName("player") end
  first = first or (UnitName and UnitName("player"))
  if Util.IsSecret(first) or Util.IsSecret(second) or not first or first == "" then return nil end
  local full
  if second and second ~= "" and not isRealm(second) then
    full = first .. " " .. second
  else
    local shown = GetUnitName and GetUnitName("player", true)
    if type(shown) == "string" and not Util.IsSecret(shown) then
      local head = shown:match("^([^%-]+)")
      if head and head:find(" ", 1, true) then full = Util.Trim(head) end
    end
  end
  if full then
    Util.forever = true
    myFirst, myFull = nameKey(first), full
    return full
  end
  return Util.FullName(first)
end

-- La liste de guilde connaît le vrai nom de mon perso (voir Guild:Rebuild).
function Util.SetPlayerName(full)
  myFull = full
  myFirst = nameKey(full):match("^(%S+)")
end

-- Rend le nom complet : "Prénom Nom" sur Forever, "Nom-Royaume" ailleurs.
function Util.FullName(name, realm)
  if type(name) ~= "string" or name == "" then return nil end
  name = name:match("^%s*(.-)%s*$")
  if name == "" then return nil end
  local head, tail = name:match("^([^%-]+)%-(.+)$")
  head = head and head:match("^%s*(.-)%s*$")
  -- "Prénom Nom" ou "Prénom Nom-Royaume" : le royaume ne compte pas.
  local spaced = head or name
  if spaced:find(" ", 1, true) then
    return known[nameKey(spaced)] or (spaced:gsub("%s+", " "))
  end
  if head then
    -- "Prénom-Nom" : la forme à tiret de Forever, quand la guilde connaît ce perso.
    local two = known[nameKey(head .. " " .. tail)]
    if two then return two end
    if not Util.forever then return name end          -- "Nom-Royaume" classique
    if isRealm(tail) then return fromFirst(head) or head end
    return head .. " " .. tail
  end
  if Util.forever then return fromFirst(name) or name end
  realm = realm and realm ~= "" and realm:gsub("[%s%-]", "") or myRealm()
  if realm == "" then return name end
  return name .. "-" .. realm
end

-- Nom à afficher : sans le royaume quand c'est le mien.
function Util.ShortName(full)
  if not full then return "?" end
  if full:find(" ", 1, true) then return (full:match("^([^%-]+)")) end
  local n, r = full:match("^([^%-]+)%-(.+)$")
  if not n then return full end
  if r == myRealm() then return n end
  return n .. "-" .. r
end

function Util.SameName(a, b)
  if not a or not b then return false end
  local fa, fb = Util.FullName(a), Util.FullName(b)
  return fa ~= nil and fb ~= nil and nameKey(fa) == nameKey(fb)
end

---------------------------------------------------------------------------
-- Couleurs
---------------------------------------------------------------------------
function Util.Hex(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

function Util.ClassColor(classFile)
  local c
  if classFile and C_ClassColor and C_ClassColor.GetClassColor then
    c = C_ClassColor.GetClassColor(classFile)
  end
  if not c and classFile and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[classFile] end
  if c then return c.r, c.g, c.b end
  return 0.95, 0.93, 0.89
end

function Util.ClassHex(classFile)
  local r, g, b = Util.ClassColor(classFile)
  return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

function Util.Colorize(text, hex)
  return "|cff" .. hex:gsub("#", "") .. text .. "|r"
end

function Util.ClassName(full, classFile)
  return "|cff" .. Util.ClassHex(classFile) .. Util.ShortName(full) .. "|r"
end

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------
function Util.Copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = Util.Copy(v) end
  return c
end

function Util.Keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

function Util.Count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function Util.Wipe(t)
  for k in pairs(t) do t[k] = nil end
  return t
end

function Util.Contains(list, value)
  for i = 1, #list do if list[i] == value then return true end end
  return false
end

function Util.Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

---------------------------------------------------------------------------
-- Texte
---------------------------------------------------------------------------
function Util.Trim(s)
  return (s or ""):match("^%s*(.-)%s*$")
end

function Util.Truncate(s, n)
  s = s or ""
  if #s <= n then return s end
  -- Ne coupe pas au milieu d'un caractère UTF-8.
  local cut = n
  while cut > 0 do
    local byte = s:byte(cut + 1)
    if not byte or byte < 0x80 or byte >= 0xC0 then break end
    cut = cut - 1
  end
  return s:sub(1, cut)
end

local ACCENTS = {
  ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["á"] = "a", ["ã"] = "a",
  ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
  ["î"] = "i", ["ï"] = "i", ["í"] = "i", ["ì"] = "i",
  ["ô"] = "o", ["ö"] = "o", ["ó"] = "o", ["ò"] = "o", ["õ"] = "o",
  ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ú"] = "u",
  ["ç"] = "c", ["ñ"] = "n", ["œ"] = "oe", ["æ"] = "ae",
  ["À"] = "a", ["Â"] = "a", ["Ä"] = "a", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
  ["Î"] = "i", ["Ï"] = "i", ["Ô"] = "o", ["Ö"] = "o", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u",
  ["Ç"] = "c", ["Œ"] = "oe",
}

-- Pour chercher sans se soucier des majuscules ni des accents.
function Util.Fold(s)
  s = (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("[\195\197][\128-\191]", ACCENTS)
  return s:lower()
end

-- Extrait le nom lisible d'un lien du jeu "|cff...|Hitem:123|h[Nom]|h|r".
function Util.LinkName(link)
  if not link then return nil end
  return link:match("|h%[(.-)%]|h") or link
end

function Util.LinkInfo(link)
  if not link then return nil end
  local kind, id = link:match("|H(%a+):(%d+)")
  if kind then return kind, tonumber(id) end
  return nil
end

---------------------------------------------------------------------------
-- Identifiants
---------------------------------------------------------------------------
local ALPHA = "0123456789abcdefghijklmnopqrstuvwxyz"

function Util.RandomId(n)
  local out = {}
  for i = 1, (n or 8) do
    local r = math.random(1, 36)
    out[i] = ALPHA:sub(r, r)
  end
  return table.concat(out)
end

function Util.ToBase36(n)
  n = floor(n)
  if n == 0 then return "0" end
  local out = {}
  while n > 0 do
    local r = n % 36
    table.insert(out, 1, ALPHA:sub(r + 1, r + 1))
    n = floor(n / 36)
  end
  return table.concat(out)
end

function Util.FromBase36(s)
  return tonumber(s, 36)
end

-- Compare deux versions "1.2.3" : 1 si a > b, -1 si a < b, 0 sinon.
function Util.CompareVersions(a, b)
  local function parts(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
  end
  local pa, pb = parts(a), parts(b)
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x > y then return 1 elseif x < y then return -1 end
  end
  return 0
end

-- Propose un chuchotement : un nom à cliquer dans la discussion. Ouvrir la
-- zone de saisie depuis le code d'un add-on la « contamine » : tout ce que le
-- joueur tape ensuite est attribué à l'add-on, et le jeu peut le bloquer.
function Util.Whisper(full)
  local target = Util.ShortName(Util.FullName(full) or full)
  local link = GetPlayerLink and GetPlayerLink(target, "[" .. target .. "]")
  DR:Print("clique pour chuchoter : " .. (link or ("/w " .. target)))
end

---------------------------------------------------------------------------
-- Rôles
---------------------------------------------------------------------------
Util.ROLES = { "T", "H", "D" }
Util.ROLE_LABEL = { T = "Tank", H = "Soins", D = "DPS" }
Util.ROLE_PLURAL = { T = "tanks", H = "soins", D = "DPS" }

function Util.RoleFromBlizzard(role)
  if role == "TANK" then return "T" elseif role == "HEALER" then return "H" elseif role == "DAMAGER" then return "D" end
  return nil
end
