-- Fiche perso lue toute seule : classe, race, niveau, spé, rôle, métiers.
-- Relue à la connexion, au changement de niveau, de métier ou de spé.
-- Partagée avec la guilde (et donc le site) seulement si le perso est dans
-- la guilde.

local _, DR = ...
local Profile = DR:NewModule("Profile")
local Util, Store = DR.Util, DR.Store

-- Lignes de métier principales et secondaires (identifiants de compétence).
Profile.PROFESSIONS = {
  [164] = "Forge", [165] = "Travail du cuir", [171] = "Alchimie", [182] = "Herboristerie",
  [186] = "Minage", [197] = "Couture", [202] = "Ingénierie", [333] = "Enchantement",
  [393] = "Dépeçage", [755] = "Joaillerie", [773] = "Calligraphie",
  [129] = "Secourisme", [185] = "Cuisine", [356] = "Pêche", [794] = "Archéologie",
}

local function readSpec()
  -- Client moderne : spécialisations.
  if GetSpecialization and GetSpecializationInfo then
    local idx = GetSpecialization()
    if idx and idx > 0 then
      local _, name, _, _, role = GetSpecializationInfo(idx)
      if name then return name, Util.RoleFromBlizzard(role) end
    end
  end
  -- Arbres de talents à l'ancienne : l'arbre le plus rempli.
  if GetNumTalentTabs and GetTalentTabInfo then
    local best, bestPoints = nil, 0
    for tab = 1, (GetNumTalentTabs() or 0) do
      local a, b, c = GetTalentTabInfo(tab)
      local name, points
      if type(b) == "string" then name, points = b, c else name, points = a, c end
      if type(points) == "number" and points > bestPoints then best, bestPoints = name, points end
    end
    if best then return best, nil end
  end
  return nil, nil
end

local function readProfessions()
  local list = {}
  if GetProfessions and GetProfessionInfo then
    local p1, p2, arch, fish, cook = GetProfessions()
    for _, idx in ipairs({ p1 or 0, p2 or 0, cook or 0, fish or 0, arch or 0 }) do
      if idx and idx > 0 then
        local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
        if name then
          list[#list + 1] = { id = skillLine, nm = name, lv = rank, mx = maxRank }
        end
      end
    end
  elseif GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
      if name and not isHeader then
        for id, label in pairs(Profile.PROFESSIONS) do
          if label == name then list[#list + 1] = { id = id, nm = name, lv = rank, mx = maxRank } end
        end
      end
    end
  end
  table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
  return list
end

-- Rôle par défaut : celui choisi par le joueur, sinon celui de la spé.
function Profile:PreferredRole(name)
  local pref = DR.db.prefs[name or DR.playerName]
  if pref and pref.role then return pref.role end
  local c = DR.db.myChars[name or DR.playerName]
  return c and c.r or nil
end

function Profile:SetPreferredRole(role)
  local name = DR.playerName
  DR.db.prefs[name] = DR.db.prefs[name] or {}
  DR.db.prefs[name].role = role
  self:Scan("rôle")
end

function Profile:Read()
  local _, classFile = UnitClass("player")
  local _, raceFile = UnitRace("player")
  local raceName = UnitRace("player")
  local spec, specRole = readSpec()
  local guildName, rankName = GetGuildInfo("player")
  local pref = DR.db.prefs[DR.playerName]
  local rec = {
    n = DR.playerName,
    cl = classFile,
    ra = raceName or raceFile,
    lv = UnitLevel("player"),
    sp = spec,
    r = (pref and pref.role) or specRole,
    p = readProfessions(),
    g = guildName,
    rk = rankName,
    acc = DR.db.accountId,
  }
  return rec
end

function Profile:Scan(reason)
  if not DR.playerName then return end
  local rec = self:Read()
  local mine = Util.Copy(rec)
  mine.seen = Util.Now()
  DR.db.myChars[DR.playerName] = mine
  if IsInGuild() and Store:IsReady() then
    Store:Put("chars", rec)
  end
  DR:Emit("PROFILE_UPDATED", reason)
end

function Profile:OnLogin()
  self.ScanSoon = DR.Debounce(2, function() self:Scan("jeu") end)
  for _, ev in ipairs({ "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_GUILD_UPDATE" }) do
    pcall(DR.On, DR, ev, function() self.ScanSoon() end)
  end
  DR:Listen("GUILD_READY", function() self.ScanSoon() end)
  DR:Listen("PLAYER_RENAMED", function(old) self:Forget(old); self.ScanSoon() end)
  DR:Listen("ROSTER_UPDATED", function() self:ForgetShortNames() end)
  DR.After(5, function() self:Scan("connexion") end)
end

-- Retire un perso enregistré sous un nom incomplet (le prénom seul, lu avant
-- que la liste de guilde ne donne le vrai nom), ici et chez les autres.
function Profile:Forget(name)
  if not name or name == DR.playerName then return end
  local pref = DR.db.prefs[name]
  if pref and DR.playerName and not DR.db.prefs[DR.playerName] then DR.db.prefs[DR.playerName] = pref end
  DR.db.prefs[name] = nil
  DR.db.myChars[name] = nil
  if not Store:IsReady() then return end
  local c = Store:Get("chars", name)
  if c and c.acc == DR.db.accountId then Store:Delete("chars", name) end
  for _, r in ipairs(Store:List("recipes", function(rec) return rec.c == name end)) do
    Store:Delete("recipes", Store.KeyOf("recipes", r))
  end
end

-- Sur Forever un nom complet a toujours un espace : une fiche de ce compte
-- sans espace vient d'une version qui ne lisait que le prénom.
function Profile:ForgetShortNames()
  if not Util.forever or self.cleaned then return end
  self.cleaned = true
  for name in pairs(Util.Copy(DR.db.myChars)) do
    if not name:find(" ", 1, true) then self:Forget(name) end
  end
end

-- Persos de mon compte (lus en jeu), du plus récent au plus ancien.
function Profile:MyChars()
  local out = {}
  for _, c in pairs(DR.db.myChars) do out[#out + 1] = c end
  table.sort(out, function(a, b)
    if a.n == DR.playerName then return true end
    if b.n == DR.playerName then return false end
    return (a.seen or 0) > (b.seen or 0)
  end)
  return out
end

-- Est-ce un perso de mon compte ?
function Profile:IsMine(name)
  if not name then return false end
  if DR.db.myChars[name] then return true end
  local c = Store:Get("chars", name)
  return c ~= nil and c.acc == DR.db.accountId
end

-- Persos (de la guilde) du même compte que `name`.
function Profile:Alts(name)
  local c = Store:Get("chars", name)
  local out = {}
  if not c or not c.acc then return out end
  for _, other in ipairs(Store:List("chars", function(r) return r.acc == c.acc end)) do
    out[#out + 1] = other.n
  end
  return out
end

function Profile:ClassOf(name)
  local c = Store:Get("chars", name) or DR.db.myChars[name or ""]
  if c and c.cl then return c.cl end
  local m = DR.Guild:Get(name)
  return m and m.class or nil
end
