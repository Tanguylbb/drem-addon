-- Messages entre add-ons, sur le canal de guilde.
--
-- Un message d'add-on fait 255 octets au plus : les messages plus longs sont
-- découpés puis recollés à l'arrivée. Le jeu limite le débit par préfixe, on
-- répartit donc l'envoi sur trois préfixes et on garde une file d'attente.
-- Pendant un combat de boss (règles de Midnight, reprises par Forever) les
-- messages sont bloqués : la file attend la fin du combat.

local _, DR = ...
local Comm = DR:NewModule("Comm")
local Json = DR.Json

Comm.DATA_PREFIXES = { "DRem1", "DRem2", "DRem3" }
Comm.POS_PREFIX = "DRemP"
Comm.MAX = 255
Comm.CHUNK = 250

local BUCKET_MAX = 8      -- messages d'avance par préfixe
local REFILL = 1.1        -- secondes pour regagner un message
local POS_INTERVAL = 4    -- un message de position au plus toutes les 4 s

local queues = {}         -- préfixe -> { high = {}, bulk = {} }
local tokens = {}         -- préfixe -> jetons disponibles
local nextPrefix = 1
local msgCounter = 0
local partial = {}        -- morceaux en cours de réception
local isOurPrefix = {}

Comm.sent, Comm.received = 0, 0

local function now() return GetTime() end

function Comm:OnInit()
  for _, p in ipairs(self.DATA_PREFIXES) do
    queues[p] = { high = {}, bulk = {} }
    tokens[p] = BUCKET_MAX
    isOurPrefix[p] = "data"
  end
  isOurPrefix[self.POS_PREFIX] = "pos"
  tokens[self.POS_PREFIX] = 1
  queues[self.POS_PREFIX] = { high = {}, bulk = {} }
  local register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
  for p in pairs(isOurPrefix) do register(p) end
end

function Comm:OnLogin()
  DR:On("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if isOurPrefix[prefix] then self:OnMessage(prefix, text, channel, sender) end
  end)
  local last = now()
  local ticker = CreateFrame("Frame")
  ticker:SetScript("OnUpdate", function(_, elapsed)
    local t = now()
    if t - last < 0.1 then return end
    local dt = t - last
    last = t
    self:Refill(dt)
    self:Pump()
  end)
  DR.Every(30, function() self:CleanPartial() end)
end

---------------------------------------------------------------------------
-- Peut-on envoyer ?
---------------------------------------------------------------------------
function Comm:Locked()
  if not IsInGuild() then return true, "pas de guilde" end
  if DR.Guard.ChatLocked() then return true, "combat" end
  return false
end

function Comm:Pending()
  local n = 0
  for _, p in ipairs(self.DATA_PREFIXES) do
    n = n + #queues[p].high + #queues[p].bulk
  end
  return n
end

---------------------------------------------------------------------------
-- Envoi
---------------------------------------------------------------------------
function Comm:Refill(dt)
  for p in pairs(tokens) do
    local max, rate = BUCKET_MAX, REFILL
    if p == self.POS_PREFIX then max, rate = 1, POS_INTERVAL end
    tokens[p] = math.min(max, tokens[p] + dt / rate)
  end
end

local function rawSend(prefix, text)
  local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  local ok, res = pcall(send, prefix, text, "GUILD")
  if not ok then return false, "erreur" end
  if res == false then return false, "refusé" end
  if type(res) == "number" and res ~= 0 then
    local throttle = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.AddonMessageThrottle
    return false, (res == throttle) and "débit" or ("code " .. res)
  end
  return true
end

function Comm:Pump()
  if self:Locked() then return end
  for prefix, q in pairs(queues) do
    while tokens[prefix] >= 1 do
      local list = (#q.high > 0) and q.high or q.bulk
      local item = list[1]
      if not item then break end
      local ok, why = rawSend(prefix, item.text)
      if ok then
        table.remove(list, 1)
        tokens[prefix] = tokens[prefix] - 1
        self.sent = self.sent + 1
      else
        -- Débit dépassé ou refus : on réessaie un peu plus tard.
        tokens[prefix] = -1
        item.tries = (item.tries or 0) + 1
        if item.tries > 20 then
          table.remove(list, 1)
          DR:Debug("message abandonné (" .. tostring(why) .. ")")
        end
        break
      end
    end
  end
  local pending = self:Pending()
  if pending ~= self.lastPending then
    self.lastPending = pending
    DR:Emit("COMM_QUEUE", pending)
  end
end

local function nextId()
  msgCounter = (msgCounter + 1) % 1296
  local id = DR.Util.ToBase36(msgCounter)
  if #id < 2 then id = "0" .. id end
  return id
end

-- Découpe un texte en morceaux de 255 octets au plus.
function Comm.Split(text)
  local chunk = Comm.CHUNK
  if #text <= Comm.MAX - 1 then return { "S" .. text } end
  local id = nextId()
  local parts, i, n = {}, 1, #text
  while i <= n do
    local e = math.min(i + chunk - 1, n)
    -- Ne jamais couper au milieu d'un caractère UTF-8 (accents).
    while e < n and e > i do
      local b = text:byte(e + 1)
      if b < 0x80 or b >= 0xC0 then break end
      e = e - 1
    end
    parts[#parts + 1] = text:sub(i, e)
    i = e + 1
  end
  for k = 1, #parts do
    local tag = (k == 1) and "F" or ((k == #parts) and "L" or "M")
    parts[k] = tag .. id .. parts[k]
  end
  return parts
end

-- Choisit le prochain préfixe (tour à tour). Les messages qui doivent
-- arriver dans l'ordre partagent le même préfixe.
function Comm:PickPrefix()
  local prefix = self.DATA_PREFIXES[nextPrefix]
  nextPrefix = nextPrefix % #self.DATA_PREFIXES + 1
  return prefix
end

-- Envoie une table (encodée en JSON) à toute la guilde.
-- priority : "high" pour les changements en direct, "bulk" pour la synchro.
function Comm:Send(msg, priority, prefix)
  if not IsInGuild() then return false end
  msg.v = DR.PROTOCOL
  local text = Json.Encode(msg)
  prefix = prefix or self:PickPrefix()
  local q = queues[prefix][priority == "high" and "high" or "bulk"]
  for _, part in ipairs(Comm.Split(text)) do q[#q + 1] = { text = part } end
  return true
end

-- Position : un seul message en attente, le plus récent remplace l'ancien.
function Comm:SendPosition(text)
  local q = queues[self.POS_PREFIX].high
  q[1] = { text = "S" .. text }
end

---------------------------------------------------------------------------
-- Réception
---------------------------------------------------------------------------
function Comm.Reassemble(store, key, text)
  local tag = text:sub(1, 1)
  if tag == "S" then return text:sub(2) end
  local id, body = text:sub(2, 3), text:sub(4)
  local k = key .. ":" .. id
  if tag == "F" then
    store[k] = { parts = { body }, t = GetTime() }
  elseif tag == "M" or tag == "L" then
    local buf = store[k]
    if not buf then return nil end
    buf.parts[#buf.parts + 1] = body
    buf.t = GetTime()
    if tag == "L" then
      store[k] = nil
      return table.concat(buf.parts)
    end
  end
  return nil
end

function Comm:CleanPartial()
  local limit = GetTime() - 120
  for k, buf in pairs(partial) do
    if buf.t < limit then partial[k] = nil end
  end
end

function Comm:OnMessage(prefix, text, channel, sender)
  if channel ~= "GUILD" then return end
  -- En combat le jeu peut livrer des valeurs « secrètes » : ne pas y toucher.
  local Util = DR.Util
  if Util.IsSecret(text) or Util.IsSecret(sender) or type(sender) ~= "string" then return end
  sender = Util.FullName(sender)
  if not sender or Util.SameName(sender, DR.playerName) then return end
  if DR.Guild and DR.Guild.MarkAddon then DR.Guild:MarkAddon(sender) end
  local full = Comm.Reassemble(partial, sender .. prefix, text)
  if not full then return end
  self.received = self.received + 1
  if isOurPrefix[prefix] == "pos" then
    DR:Emit("COMM_POSITION", sender, full)
    return
  end
  local msg = Json.Decode(full)
  if type(msg) ~= "table" or type(msg.t) ~= "string" then
    DR:Debug("message illisible de " .. tostring(sender))
    return
  end
  DR:Emit("COMM_MESSAGE", msg, sender)
end
