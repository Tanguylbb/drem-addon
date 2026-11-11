-- Le client WoW: Forever : des persos « Prénom Nom », des royaumes liés, des
-- valeurs secrètes en combat et des actions que le jeu refuse aux add-ons.
return function(H)
  H.test("Forever : mon nom complet est « Prénom Nom », sans royaume", function()
    local _, cl = H.ForeverGuild()
    local A, B = cl[1], cl[2]
    H.eq(A.DR.playerName, "Shenryu Valdor")
    H.eq(B.DR.playerName, "Brume Lune")
    H.ok(A.DR.Util.forever, "noms Forever reconnus")
    H.ok(A.DR.Guild:Get("Shenryu Valdor"), "je suis dans la liste de guilde")
    H.eq(A.DR.Guild.myRankIndex, 1)
  end)

  H.test("Forever : toutes les formes d'un nom désignent le même perso", function()
    local _, cl = H.ForeverGuild()
    local U = cl[1].DR.Util
    H.eq(U.FullName("Brume Lune"), "Brume Lune")
    H.eq(U.FullName("Brume Lune-CAMWoWEU5Realm1PvE"), "Brume Lune", "royaume lié retiré")
    H.eq(U.FullName("Brume-Lune"), "Brume Lune", "forme à tiret")
    H.eq(U.FullName("brume lune"), "Brume Lune", "casse de la liste de guilde")
    H.eq(U.FullName("Shenryu"), "Shenryu Valdor", "prénom unique dans la guilde")
    H.eq(U.FullName("Brume"), "Brume", "prénom porté par deux membres : pas de devinette")
    H.eq(U.FullName("Shenryu-CAMWoWEU4Realm7PvE"), "Shenryu Valdor", "prénom et royaume")
    H.eq(U.FullName("Inconnu-Durand"), "Inconnu Durand", "un perso hors guilde garde son nom")
    H.ok(U.SameName("Brume-Lune", "Brume Lune-CAMWoWEU5Realm1PvE"))
    H.ok(not U.SameName("Brume Lune", "Brume Argent"))
    H.eq(U.ShortName("Brume Lune"), "Brume Lune", "le chuchotement a besoin du nom entier")
  end)

  H.test("Forever : la sortie d'un officier est acceptée par les membres", function()
    local net, cl = H.ForeverGuild()
    local A, B = cl[1], cl[2]
    H.ok(A.DR.Guild:IAmOfficer(), "Shenryu Valdor est officier")
    local ev = assert(A.DR.Calendar:SaveEvent({
      t = "Cœur du Magma", k = "raid", d = net:ServerTime() + 2 * 86400, nt = 4, nh = 10, nd = 26, cap = 40,
    }))
    H.eq(ev.by, "Shenryu Valdor")
    net:Advance(5)
    local got = B.DR.Calendar:Get(ev.id)
    H.ok(got, "la sortie est arrivée chez un membre d'un autre royaume lié")
    H.ok(B.DR.Calendar:SetSignup(ev.id, nil, "yes", "D"))
    net:Advance(5)
    local signups = A.DR.Calendar:Signups(ev.id)
    H.eq(#signups, 1)
    H.eq(signups[1].c, "Brume Lune")
  end)

  H.test("Forever : une sortie envoyée par un simple membre reste refusée", function()
    local net, cl = H.ForeverGuild()
    local A, B = cl[1], cl[2]
    B.DR.Sync:Broadcast("events", { id = "gfaux", t = "Faux raid", k = "raid", d = net:ServerTime() + 86400,
      u = net:ServerTime(), by = "Brume Lune" })
    net:Advance(5)
    H.ok(not A.DR.Calendar:Get("gfaux"), "refusée : Brume Lune n'est pas officier")
  end)

  H.test("Forever : la sortie d'un officier hors ligne est acceptée à la synchro", function()
    local net, cl = H.ForeverGuild()
    local A, B = cl[1], cl[2]
    -- Galdrin Roc (chef de guilde) est hors ligne ; sa sortie est relayée par Shenryu.
    A.DR.Store:Merge("events", { id = "gchef", t = "Onyxia", k = "raid", d = net:ServerTime() + 86400,
      u = net:ServerTime() - 60, by = "Galdrin Roc" }, "remote")
    net:Advance(1)
    B.DR.Sync:Request("test")
    net:Advance(20)
    H.ok(B.DR.Calendar:Get("gchef"), "le rang d'un membre hors ligne est connu")
    H.ok(B.showOffline, "les membres hors ligne sont demandés au jeu")
  end)

  for _, form in ipairs({ "court", "tiret", "royaume" }) do
    H.test("Forever : expéditeur au format « " .. form .. " » reconnu", function()
      local net, cl = H.ForeverGuild({ senderForm = form })
      local A, B = cl[1], cl[2]
      local ev = assert(A.DR.Calendar:SaveEvent({ t = "Zul'Gurub", k = "raid", d = net:ServerTime() + 86400 }))
      net:Advance(5)
      H.ok(B.DR.Calendar:Get(ev.id), "la sortie est arrivée")
      -- Mes propres messages ne me reviennent pas comme ceux d'un autre.
      local before = A.DR.Comm.received
      A.DR.Sync:Request("test")
      net:Advance(3)
      H.ok(A.DR.Comm.received >= before, "compteur lisible")
    end)
  end

  H.test("Forever : sans le nom de famille au départ, la liste de guilde le donne", function()
    local net = H.NewNetwork()
    net.forever = true
    net:SetRoster({
      { name = "Torvi Quatre", rankIndex = 1, rankName = "Officier" },
      { name = "Torvi Cinq", rankIndex = 2 },
    })
    local c = net:AddClient({ name = "Torvi Quatre", rankIndex = 1, guild = "Dernier Rempart" })
    -- Le client ne livre que le prénom (UnitFullName et GetUnitName muets).
    c.env.UnitFullName = function() return "Torvi", nil end
    c.env.GetUnitName = function() return "Torvi" end
    c:Fire("PLAYER_LOGIN")
    net:Advance(5)
    H.eq(c.DR.playerName, "Torvi Quatre", "retrouvé par l'identifiant du perso, malgré l'homonyme")
    H.eq(c.DR.Store:Get("chars", "Torvi Quatre") and c.DR.Store:Get("chars", "Torvi Quatre").n, "Torvi Quatre")
  end)

  H.test("Forever : la fiche sous un nom incomplet est retirée", function()
    local net, cl = H.ForeverGuild()
    local A, B = cl[1], cl[2]
    -- Une version d'avant ne lisait que le prénom et le royaume.
    local old = "Shenryu-CAMWoWEU4Realm7PvE"
    A.DR.db.myChars[old] = { n = old }
    A.DR.Store:Merge("chars", { n = old, cl = "PALADIN", acc = A.DR.db.accountId, u = net:ServerTime() - 100, by = old }, "local")
    net:Advance(5)
    A.DR.Profile.cleaned = nil
    A:Fire("GUILD_ROSTER_UPDATE")
    net:Advance(8)
    H.ok(not A.DR.db.myChars[old], "retirée de mes persos")
    H.ok(not A.DR.Store:Get("chars", old), "retirée des fiches de la guilde")
    H.ok(not B.DR.Store:Get("chars", old), "et chez les autres")
    H.ok(A.DR.Store:Get("chars", "Shenryu Valdor"), "la bonne fiche reste")
  end)

  H.test("Forever : la même base pour deux royaumes liés", function()
    local _, cl = H.ForeverGuild()
    H.eq(cl[1].DR.guildKey, cl[2].DR.guildKey)
  end)

  H.test("Valeurs secrètes : un message illisible en combat est ignoré sans erreur", function()
    local net, cl = H.ForeverGuild()
    local A = cl[1]
    A:Fire("CHAT_MSG_ADDON", "DRem1", H.SECRET, "GUILD", "Brume Lune")
    A:Fire("CHAT_MSG_ADDON", "DRem1", "S01{}", "GUILD", H.SECRET)
    net:Advance(1)
    H.eq(#(A.DR.db.errors or {}), 0, "aucune erreur enregistrée")
  end)

  H.test("Valeurs secrètes : la liste de guilde n'est pas relue en combat", function()
    local net, cl = H.ForeverGuild()
    local A = cl[1]
    net.secretInCombat = true
    A.combat = true
    A:Fire("GUILD_ROSTER_UPDATE")
    net:Advance(3)
    H.ok(A.DR.Guild:Get("Brume Lune"), "la liste d'avant le combat reste")
    H.eq(#(A.DR.db.errors or {}), 0)
    A.combat = false
    A:Fire("PLAYER_REGEN_ENABLED")
    net:Advance(3)
    H.ok(A.DR.Guild:Get("Brume Lune"))
    H.ok(not A.DR.Guild.rebuildPending, "relue après le combat")
  end)

  H.test("Chuchoter : un nom à cliquer, la zone de saisie n'est pas ouverte", function()
    local _, cl = H.ForeverGuild()
    local A = cl[1]
    local opened = false
    A.env.ChatFrame_SendTell = function() opened = true end
    A.env.ChatFrameUtil = { SendTell = function() opened = true end }
    A.DR.Util.Whisper("Brume-Lune")
    H.ok(not opened, "la zone de saisie reste au joueur")
    H.ok(A.chat[#A.chat]:find("|Hplayer:Brume Lune|h", 1, true), "lien cliquable vers le bon perso")
  end)

  H.test("Rapport : refus du jeu et erreurs gardés pour /rempart rapport", function()
    local net, cl = H.ForeverGuild()
    local A = cl[1]
    A:Fire("ADDON_ACTION_FORBIDDEN", "DernierRempart", "ToggleWorldMap()")
    A:Fire("ADDON_ACTION_FORBIDDEN", "DernierRempart", "ToggleWorldMap()")
    A:Fire("ADDON_ACTION_BLOCKED", "AutreAddon", "Truc()")
    A.DR:Listen("TEST_ERREUR", function() error("boum") end)
    A.DR:Emit("TEST_ERREUR")
    net:Advance(1)
    H.eq(#A.DR.db.blocked, 1, "seuls nos refus comptent")
    H.eq(A.DR.db.blocked[1].count, 2)
    local text = table.concat(A.DR.Guard.Report(), "\n")
    H.ok(text:find("interface 16001", 1, true), "version du jeu")
    H.ok(text:find("ToggleWorldMap", 1, true), "le refus est listé")
    H.ok(text:find("boum", 1, true), "l'erreur est listée")
    H.ok(text:find("noms Forever : oui", 1, true))
    A:Slash("rapport")
    H.ok(A.chat[#A.chat]:find("Refus", 1, true))
  end)

  H.test("Carte du monde : pas ouverte en combat", function()
    local _, cl = H.ForeverGuild()
    local A = cl[1]
    H.eq(A.DR.Guard.PanelLocked(), nil)
    A.combat = true
    H.eq(A.DR.Guard.PanelLocked(), "en combat")
  end)
end
