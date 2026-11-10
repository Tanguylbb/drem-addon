-- La guilde vue par le jeu : liste des membres, rangs, qui est officier,
-- qui est en ligne et où. Relie aussi la base de sauvegarde à la bonne guilde.

local _, DR = ...
local Guild = DR:NewModule("Guild")
local Util = DR.Util

Guild.members = {}      -- nom complet -> fiche du roster
Guild.online = 0
Guild.DEFAULT_OFFICER_RANK = 1 -- rangs 0 (chef) et 1 (officiers)

local function requestRoster()
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
  elseif GuildRoster then
    GuildRoster()
  end
end

function Guild:OnLogin()
  DR:On("GUILD_ROSTER_UPDATE", function() self:ScheduleRebuild() end)
  DR:On("PLAYER_GUILD_UPDATE", function() self:CheckGuild() end)
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
  local key = name .. "-" .. ((realm and realm ~= "") and realm or Util.MyRealm())
  if key ~= self.key then
    self.key = key
    self.name = name
    DR.guildKey = key
    DR.Store:Bind(DR:GetGuildDB(key))
    DR:Emit("GUILD_READY", key)
  end
end

function Guild:Rebuild()
  if not IsInGuild() then return end
  local n = GetNumGuildMembers()
  local members, online = {}, 0
  for i = 1, n do
    local name, rankName, rankIndex, level, classLocal, zone, note, _, isOnline,
      status, classFile = GetGuildRosterInfo(i)
    if name then
      local full = Util.FullName(name)
      members[full] = {
        name = full, rank = rankName, rankIndex = rankIndex, level = level,
        className = classLocal, class = classFile, zone = zone, online = isOnline and true or false,
        status = status, note = note,
      }
      if isOnline then online = online + 1 end
    end
  end
  self.members = members
  self.online = online
  self.count = n
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
