-- Lecture du journal de la banque de guilde.
--
-- Quand un membre ouvre la banque, l'add-on demande les journaux (or et
-- objets) au jeu, garde les dépôts et les confie à Effort, qui les rattache aux
-- objectifs. Le jeu ne laisse lire le journal que banque ouverte, et il ne
-- garde que les derniers mouvements : plus il y a de membres qui ouvrent la
-- banque, moins il en manque.
--
-- À vérifier en jeu sur Forever (voir docs/TEST-EN-JEU.md) : /rempart banque
-- dit ce que le jeu rend.

local _, DR = ...
local Bank = DR:NewModule("Bank")
local Util = DR.Util

local HOUR, DAY = 3600, 86400
local MAX_AGE = 90 * DAY

Bank.last = nil -- { at, n, new } : ma dernière lecture

local function call(fn, ...)
  if type(fn) ~= "function" then return false end
  return pcall(fn, ...)
end

-- Les fonctions du journal, si le client les a.
local function api()
  return {
    query = QueryGuildBankLog,
    tabs = GetNumGuildBankTabs,
    tabInfo = GetGuildBankTabInfo,
    moneyCount = GetNumGuildBankMoneyTransactions,
    money = GetGuildBankMoneyTransaction,
    itemCount = GetNumGuildBankTransactions,
    item = GetGuildBankTransaction,
  }
end

function Bank.Available()
  local a = api()
  return type(a.query) == "function" and type(a.money) == "function" and type(a.item) == "function"
end

-- Le jeu donne l'âge d'une ligne (années, mois, jours, heures) : on en fait
-- une heure du serveur, arrondie à l'heure.
function Bank.AgeToTime(now, years, months, days, hours)
  local age = ((tonumber(years) or 0) * 365 + (tonumber(months) or 0) * 30 + (tonumber(days) or 0)) * DAY
    + (tonumber(hours) or 0) * HOUR
  local at = now - age
  return at - at % HOUR, age
end

local function donorName(name)
  if type(name) ~= "string" or Util.IsSecret(name) or name == "" then return nil end
  return Util.FullName(name) or Util.Trim(name)
end

---------------------------------------------------------------------------
-- Demander puis lire
---------------------------------------------------------------------------
function Bank:OnLogin()
  self.ReadSoon = DR.Debounce(1.2, function() self:Read() end)
  pcall(DR.On, DR, "GUILDBANKFRAME_OPENED", function() self:Opened() end)
  pcall(DR.On, DR, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
    local types = Enum and Enum.PlayerInteractionType
    if types and types.GuildBanker and kind == types.GuildBanker then self:Opened() end
  end)
  pcall(DR.On, DR, "GUILDBANKLOG_UPDATE", function() self.ReadSoon() end)
end

function Bank:Opened()
  if not DR.db.settings.readBank or not DR.Store:IsReady() then return end
  DR.After(0.8, function() self:Query() end)
end

function Bank:Query()
  local a = api()
  if type(a.query) ~= "function" then return end
  local nTabs = tonumber(select(2, call(a.tabs))) or 0
  call(a.query, (MAX_GUILDBANK_TABS or 8) + 1) -- l'onglet du journal d'or
  for tab = 1, nTabs do
    local ok, _, _, viewable = call(a.tabInfo, tab)
    if not ok or viewable ~= false then call(a.query, tab) end
  end
end

-- Les dépôts du journal, sans les retraits ni les réparations.
-- Rend la liste, ou nil et la raison.
function Bank:Collect()
  local a = api()
  if not Bank.Available() then return nil, "le jeu n'a pas les fonctions du journal de banque" end
  local now = Util.Now()
  local out, seen = {}, { money = 0, items = 0 }
  local okc, nMoney = call(a.moneyCount)
  for i = 1, (okc and tonumber(nMoney) or 0) do
    local ok, kind, name, amount, y, mo, d, h = call(a.money, i)
    local who = ok and donorName(name)
    if ok and kind == "deposit" and who and type(amount) == "number" and amount > 0 then
      local at, age = Bank.AgeToTime(now, y, mo, d, h)
      if age <= MAX_AGE then
        out[#out + 1] = { c = who, k = "or", a = amount, at = at }
      end
    end
    seen.money = seen.money + 1
  end
  local okt, nTabs = call(a.tabs)
  for tab = 1, (okt and tonumber(nTabs) or 0) do
    local okn, nItems = call(a.itemCount, tab)
    for i = 1, (okn and tonumber(nItems) or 0) do
      local ok, kind, name, link, count, _, _, y, mo, d, h = call(a.item, tab, i)
      local who = ok and donorName(name)
      if ok and kind == "deposit" and who and type(link) == "string" and not Util.IsSecret(link) then
        local lk, id = Util.LinkInfo(link)
        if lk == "item" and id and type(count) == "number" and count > 0 then
          local at, age = Bank.AgeToTime(now, y, mo, d, h)
          if age <= MAX_AGE then
            out[#out + 1] = { c = who, k = "objet", a = count, it = id, nm = Util.LinkName(link), at = at, tab = tab }
          end
        end
      end
      seen.items = seen.items + 1
    end
  end
  return out, seen
end

function Bank:Read()
  if not DR.db.settings.readBank or not DR.Store:IsReady() then return end
  local entries, seen = self:Collect()
  if not entries then return end
  -- Aucune ligne lue : le journal n'est pas encore revenu, on n'en dit rien.
  if type(seen) == "table" and seen.money + seen.items == 0 then return end
  local new = DR.Effort:RecordBank(entries)
  self.last = { at = Util.Now(), n = #entries, new = new }
  DR.Effort:NoteBankRead(#entries, new)
  if new > 0 then
    DR:Print(string.format("banque de guilde lue : %d nouveau%s dépôt%s pris en compte pour l'effort de guerre.",
      new, new > 1 and "x" or "", new > 1 and "s" or ""))
  end
  DR:Emit("BANK_READ")
end

---------------------------------------------------------------------------
-- /rempart banque : ce que le jeu rend (pour vérifier sur Forever)
---------------------------------------------------------------------------
function Bank:Diagnose()
  local lines = {}
  local a = api()
  lines[#lines + 1] = "Fonctions du journal : " .. (Bank.Available() and "présentes" or "absentes")
  lines[#lines + 1] = "Lecture à l'ouverture de la banque : " .. (DR.db.settings.readBank and "oui" or "non")
  if not Bank.Available() then return lines end
  local okc, nMoney = call(a.moneyCount)
  lines[#lines + 1] = "Journal d'or : " .. (okc and tostring(nMoney) or "illisible") .. " ligne(s)"
  local okt, nTabs = call(a.tabs)
  lines[#lines + 1] = "Onglets : " .. (okt and tostring(nTabs) or "illisible")
  for tab = 1, (okt and tonumber(nTabs) or 0) do
    local okn, nItems = call(a.itemCount, tab)
    lines[#lines + 1] = "  onglet " .. tab .. " : " .. (okn and tostring(nItems) or "illisible") .. " ligne(s)"
  end
  local entries = self:Collect()
  lines[#lines + 1] = "Dépôts lisibles : " .. (entries and #entries or 0)
    .. " (ouvre la banque, puis retape la commande si c'est 0)"
  if self.last then
    lines[#lines + 1] = "Dernière lecture : " .. Util.Ago(self.last.at) .. ", " .. self.last.new .. " nouveau(x)"
  end
  return lines
end
