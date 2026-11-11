-- La guilde vue par le jeu : liste des membres, rangs, qui est officier,
-- qui est en ligne et où. Relie aussi la base de sauvegarde à la bonne guilde.

local _, DR = ...
local Guild = DR:NewModule("Guild")
local Util = DR.Util

Guild.members = {}      -- nom complet -> fiche du roster
Guild.online = 0
Guild.DEFAULT_OFFICER_RANK = 1 -- rangs 0 (chef) et 1 (officiers)

local function requestRoster()
  -- Les membres hors ligne doivent être dans la liste : sans eux, une sortie
  -- créée par un officier déconnecté serait refusée (rang inconnu).
  if GetGuildRosterShowOffline and SetGuildRosterShowOffline and not GetGuildRosterShowOffline() then
    pcall(SetGuildRosterShowOffline, true)
  end
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
  elseif GuildRoster then
    GuildRoster()
  end
end

function Guild:OnLogin()
  DR:On("GUILD_ROSTER_UPDATE", function() self:ScheduleRebuild() end)
  DR:On("PLAYER_GUILD_UPDATE", function() self:CheckGuild() end)
  -- La liste n'est pas relue en combat (noms « secrets ») : on rattrape après.
  DR:On("PLAYER_REGEN_ENABLED", function()
    if self.rebuildPending then self.rebuildPending = nil; self:ScheduleRebuild() end
  end)
  self.ScheduleRebuild = DR.Debounce(1, function() self:Rebuild() end)
  -- Après le démarrage de tous les modules, pour qu'ils entendent GUILD_READY.
  DR.After(0.5, function() self:CheckGuild() end)
  requestRoster()
  DR.Every(60, function() if IsInGuild() then requestRoster() end end)
end

-- Détermine la guilde courante et branche le magasin sur sa base.
function Guild:CheckGuild()
  if not IsInGuild() then
    if self.key then
      self.key = nil
      DR.guildKey = nil
      DR.Store:Bind(nil)
      DR:Emit("GUILD_LEFT")
    end
    return
  end
  local name, rankName, rankIndex, realm = GetGuildInfo("player")
  if not name then
    -- Le nom arrive parfois quelques secondes après la connexion.
    DR.After(2, function() self:CheckGuild() end)
    return
  end
  self.myRankName, self.myRankIndex = rankName, rankIndex
  -- Les royaumes liés de Forever ne diffèrent que par leurs numéros : sans
  -- eux, tous les persos de la guilde retrouvent la même base.
  local key = name .. "-" .. Util.RealmFamily((realm and realm ~= "") and realm or Util.MyRealm())
  if key ~= self.key then
    self.key = key
    self.name = name
    DR.guildKey = key
    DR.Store:Bind(DR:GetGuildDB(key))
    DR:Emit("GUILD_READY", key)
  end
end

-- Nom complet d'une ligne de la liste : "Prénom Nom" sur Forever (le royaume
-- éventuel derrière est retiré), "Nom-Royaume" ailleurs.
local function rosterName(name)
  local head = name:match("^([^%-]+)")
  if head and head:find(" ", 1, true) then return (head:gsub("%s+", " "):match("^%s*(.-)%s*$")) end
  return Util.FullName(name)
end

function Guild:Rebuild()
  if not IsInGuild() then return end
  if InCombatLockdown and InCombatLockdown() then
    self.rebuildPending = true
    return
  end
  local n = GetNumGuildMembers()
  local members, online, names = {}, 0, {}
  local myGuid = UnitGUID and UnitGUID("player")
  if Util.IsSecret(myGuid) then myGuid = nil end
  local mine
  for i = 1, n do
    local name, rankName, rankIndex, level, classLocal, zone, note, _, isOnline,
      status, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(i)
    if type(name) == "string" and not Util.IsSecret(name) then
      local full = rosterName(name)
      if full then
        members[full] = {
          name = full, rank = rankName, rankIndex = rankIndex, level = level,
          className = classLocal, class = classFile, zone = zone, online = isOnline and true or false,
          status = status, note = note,
        }
        names[#names + 1] = full
        if isOnline then online = online + 1 end
        if myGuid and guid == myGuid then mine = full end
      end
    end
  end
  self.members = members
  self.online = online
  self.count = #names
  Util.SetKnownNames(names)
  -- Mon vrai nom dans la guilde : par l'identifiant du perso, sinon par le nom
  -- (le jeu ne donne parfois que le prénom du perso connecté).
  if not mine and DR.playerName and not members[DR.playerName] then
    local resolved = Util.FullName(DR.playerName)
    if resolved and members[resolved] then mine = resolved end
  end
  if mine and mine ~= DR.playerName then DR:SetPlayerName(mine) end
  -- Mon rang peut avoir changé.
  local me = members[DR.playerName]
  if me then self.myRankIndex, self.myRankName = me.rankIndex, me.rank end
  DR:Emit("ROSTER_UPDATED")
end

function Guild:Get(name)
  return self.members[Util.FullName(name) or ""]
end

function Guild:IsMember(name)
  return self:Get(name) ~= nil
end

function Guild:IsOnline(name)
  local m = self:Get(name)
  return m and m.online or false
end

-- Seuil des rangs officiers : réglé par le chef de guilde, partagé à tous.
function Guild:OfficerRank()
  local cfg = DR.Store:Get("meta", "config")
  if cfg and type(cfg.officerRank) == "number" then return cfg.officerRank end
  return self.DEFAULT_OFFICER_RANK
end

function Guild:IsOfficer(name)
  if not name then return false end
  if name == "site" then return true end
  local m = self:Get(name)
  if m then return m.rankIndex <= self:OfficerRank() end
  return false
end

function Guild:IAmOfficer()
  if self.myRankIndex then return self.myRankIndex <= self:OfficerRank() end
  return false
end

function Guild:IAmLeader()
  return self.myRankIndex == 0
end

function Guild:SetOfficerRank(n)
  if not self:IAmLeader() then return false end
  n = Util.Clamp(math.floor(n), 0, 9)
  DR.Store:Put("meta", { id = "config", officerRank = n }) -- diffusé tout seul
  return true
end

-- Membres en ligne, triés par nom.
function Guild:OnlineMembers()
  local out = {}
  for _, m in pairs(self.members) do
    if m.online then out[#out + 1] = m end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function Guild:RankName(index)
  if GuildControlGetRankName and index then
    local n = GuildControlGetRankName(index + 1)
    if n and n ~= "" then return n end
  end
  return "rang " .. tostring(index)
end
