-- Version 0.3 : présence et synchro, carte, recettes par type et +1, métiers à
-- lire, effort de guerre lu dans la banque, relais automatique.
return function(H)
  local function chatHas(client, text)
    for _, m in ipairs(client.chat) do if m:find(text, 1, true) then return true end end
    return false
  end

  ---------------------------------------------------------------------------
  -- Outils
  ---------------------------------------------------------------------------
  H.test("Util : montants en or lus et écrits", function()
    local net, cl = H.Guild({ clients = { { name = "Shenryu", rankIndex = 1 } } })
    local U = cl[1].DR.Util
    H.eq(U.Money(2000000), "200 po")
    H.eq(U.Money(124000), "12 po 40 pa")
    H.eq(U.Money(3000), "30 pa")
    H.eq(U.Money(0), "0 po")
    H.eq(U.ParseGold("25"), 250000)
    H.eq(U.ParseGold("25 po"), 250000)
    H.eq(U.ParseGold("12 po 40 pa"), 124000)
    H.eq(U.ParseGold("25,5"), 255000)
    H.eq(U.ParseGold("abc"), nil)
    H.eq(U.ParseGold(""), nil)
    local now = net:ServerTime()
    H.eq(U.WhenText(now - 3600, now):find("Aujourd'hui", 1, true) ~= nil, true)
    H.eq(U.WhenText(now - 86400, now):find("Hier", 1, true) ~= nil, true)
    H.eq(U.WhenText(now - 3 * 86400, now), "Il y a 3 jours")
  end)

  ---------------------------------------------------------------------------
  -- Qui a l'add-on, état de la synchro, qui a vu la sortie
  ---------------------------------------------------------------------------
  do
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    net:Advance(40)

    H.test("Présence : les membres qui écrivent ont l'add-on", function()
      H.ok(A.DR.Guild:HasAddon("Brumelune-Rempart"), "Brumelune a l'add-on")
      H.ok(not A.DR.Guild:HasAddon("Pikvol-Rempart"), "Pikvol n'a rien envoyé")
      H.eq(A.DR.Guild:OnlineWithAddon(), 2)
    end)

    H.test("Synchro : un membre qui n'a rien de plus le dit, et l'état passe au vert", function()
      H.ok(A.DR.Sync.lastReply, "une réponse est arrivée")
      H.eq(A.DR.Sync.lastReply.by, "Brumelune-Rempart")
      local s = A.DR.Sync:Status()
      H.eq(s.level, "ok")
      H.ok(s.text:find("À jour", 1, true) and s.text:find("2 membres", 1, true), s.text)
    end)

    H.test("Synchro : seul, on le dit au lieu de promettre", function()
      local net2, c2 = H.Guild({ clients = { { name = "Shenryu", rankIndex = 1 } } })
      net2:Advance(40)
      local s = c2[1].DR.Sync:Status()
      H.eq(s.level, "alone")
      H.ok(s.text:find("Personne d'autre", 1, true), s.text)
    end)

    H.test("Sorties : qui l'a vue", function()
      local ev = assert(A.DR.Calendar:SaveEvent({ t = "Sac de couchage", k = "soiree", d = net:ServerTime() + 86400, nt = 0, nh = 0, nd = 0 }))
      net:Advance(5)
      H.ok(B.DR.Calendar:SetSignup(ev.id, "Brumelune-Rempart", "yes", "D"))
      net:Advance(5)
      local seen = A.DR.Calendar:SeenBy(ev.id)
      H.eq(seen.answered, 1)
      H.eq(seen.pending, 1, "Shenryu n'a pas répondu")
      H.eq(seen.noAddon, 2, "Pikvol et Galdrin n'ont pas l'add-on")
    end)

    H.test("Sorties : la ligne de synchro et le bouton « Redemander » s'affichent", function()
      A.DR.db.settings.debug = true
      A:Slash("sorties")
      local tab = A.DR.UI.tabs.sorties
      tab:Refresh()
      H.ok(tab.syncText:GetText():find("À jour", 1, true), tab.syncText:GetText())
      local before = #A.sent
      tab.syncBtn:Click()
      net:Advance(3)
      H.ok(#A.sent > before, "la demande est partie")
      H.ok(tab.detail.seenText:GetText():find("ont répondu", 1, true), "ligne « Qui l'a vue »")
      H.eq(chatHas(A, "Erreur"), false, "aucune erreur")
    end)
  end

  ---------------------------------------------------------------------------
  -- Carte : pourquoi on ne voit pas un membre
  ---------------------------------------------------------------------------
  do
    local net, cl = H.Guild({ clients = {
      { name = "Shenryu", rankIndex = 1, map = { m = 1453, x = 0.52, y = 0.61 } },
      { name = "Brumelune", map = { m = 1453, x = 0.30, y = 0.40 } },
    } })
    local A, B = cl[1], cl[2]
    A.DR.GuildMap:SetWatching("onglet", true)
    net:Advance(12)

    H.test("Carte : la raison pour chaque membre", function()
      local M = A.DR.GuildMap
      H.eq(M:Reason("Brumelune-Rempart"), "pos")
      H.eq(M:Reason("Shenryu-Rempart"), "pos")
      H.eq(M:Reason("Pikvol-Rempart"), "sans")
      B.inInstance = true
      net:Advance(8)
      H.eq(M:Reason("Brumelune-Rempart"), "instance")
      B.inInstance = false
      net:Advance(8)
      H.eq(M:Reason("Brumelune-Rempart"), "pos")
      B:Slash("position")
      net:Advance(8)
      H.eq(M:Reason("Brumelune-Rempart"), "coupe")
    end)

    H.test("Carte : une ancienne version envoie « H » seul, sans raison", function()
      local M = A.DR.GuildMap
      M:OnPosition("Pikvol-Rempart", "H")
      H.eq(M:Reason("Pikvol-Rempart"), "cache")
      M:OnPosition("Pikvol-Rempart", "P:1453:5000:2500")
      H.eq(M:Reason("Pikvol-Rempart"), "pos")
    end)

    H.test("Carte : compteurs et liste sans erreur", function()
      A.DR.db.settings.debug = true
      A:Slash("carte")
      local tab = A.DR.UI.tabs.carte
      tab:Refresh()
      H.eq(tab.stats[1].num:GetText(), "2", "en ligne")
      H.eq(tab.stats[2].num:GetText(), "2", "avec l'add-on")
      H.ok(#tab.members.items == 2)
      H.eq(chatHas(A, "Erreur"), false)
    end)
  end

  ---------------------------------------------------------------------------
  -- Recettes : tout le métier par type, +1, métiers à lire
  ---------------------------------------------------------------------------
  do
    local net, cl = H.Guild({ clients = {
      { name = "Shenryu", rankIndex = 1,
        profs = { { name = "Alchimie", rank = 300, max = 300, id = 171 }, { name = "Herboristerie", rank = 288, max = 300, id = 182 } } },
      { name = "Brumelune" },
    } })
    local A, B = cl[1], cl[2]
    A.DR.db.settings.debug = true
    B.DR.db.settings.debug = true
    net:Advance(25)

    H.test("Métiers à lire : une seule ligne à la connexion", function()
      H.ok(chatHas(A, "il te reste 1 métier à ouvrir : Alchimie"), "ligne dans le chat")
      local n = 0
      for _, m in ipairs(A.chat) do if m:find("à ouvrir", 1, true) then n = n + 1 end end
      H.eq(n, 1)
      local st = A.DR.Profile:ProfessionStates()
      H.eq(#st, 2)
      H.ok(st[1].needs and not st[1].read, "Alchimie à ouvrir")
      H.ok(not st[2].needs, "la cueillette n'a rien à lire")
    end)

    A.tradeskill = { id = 171, name = "Alchimie", all = { 3451, 17556, 17635, 11450 },
      learned = { [3451] = true, [11450] = true },
      types = { [3451] = "Potions", [17556] = "Potions", [11450] = "Élixirs", [17635] = "Flacons" } }
    A:Fire("TRADE_SKILL_SHOW")
    net:Advance(5)

    H.test("Métiers à lire : lu, avec l'heure, et la relecture de la fiche n'efface rien", function()
      local st = A.DR.Profile:ProfessionStates()
      H.ok(st[1].read and st[1].n == 2 and st[1].at, "Alchimie lue")
      H.eq(#A.DR.Profile:ToOpen(), 0)
      A.DR.Profile:Scan("manuel")
      H.ok(A.DR.Profile:ProfessionStates()[1].read, "toujours lue après relecture de la fiche")
    end)

    H.test("Recettes rangées par type de craft, tout le métier", function()
      local groups = B.DR.Crafts:Tree(171, "all", "")
      local names = {}
      for _, g in ipairs(groups) do names[#names + 1] = g.name .. ":" .. #g.entries .. "/" .. g.nobody end
      H.eq(table.concat(names, ","), "Élixirs:1/0,Flacons:1/1,Potions:2/1")
      H.eq(#B.DR.Crafts:Tree(171, "nobody", ""), 2, "Flacons et Potions")
      H.eq(#B.DR.Crafts:Tree(171, "lacking", "")[1].entries + #B.DR.Crafts:Tree(171, "lacking", "")[2].entries
        + #B.DR.Crafts:Tree(171, "lacking", "")[3].entries, 4, "Brumelune n'en a aucune")
      local mine = 0
      for _, g in ipairs(A.DR.Crafts:Tree(171, "lacking", "")) do mine = mine + #g.entries end
      H.eq(mine, 2, "il manque 2 recettes à Shenryu")
      local found = B.DR.Crafts:Tree(171, "all", "flacon")
      H.eq(#found, 1, "la recherche garde le type qui contient le Flacon des Titans")
      H.eq(found[1].entries[1].id, 17635)
    end)

    H.test("Catalogue : combien de recettes, lu par combien de membres", function()
      local info = B.DR.Crafts:CatalogInfo(171)
      H.eq(info.recipes, 4); H.eq(info.readers, 1); H.eq(info.members, 1)
      H.eq(#B.DR.Crafts:Unshared(171), 0)
    end)

    H.test("+1 sur une recette que personne ne sait : créée, comptée, retirée", function()
      local entry
      for _, e in ipairs(B.DR.Crafts:Entries(171)) do if e.id == 17635 then entry = e end end
      H.ok(entry and #entry.crafters == 0, "17635 : personne")
      local order, on = B.DR.Crafts:ToggleWant(entry)
      H.ok(order and on, "+1 posé")
      net:Advance(5)
      local want = A.DR.Crafts:WantMap()[17635]
      H.ok(want and want.n == 1 and not want.mine, "Shenryu voit le +1 de Brumelune")
      A.DR.Crafts:ToggleWant(entry)
      net:Advance(5)
      H.eq(B.DR.Crafts:WantMap()[17635].n, 2)
      H.eq(#B.DR.Crafts:Wanters(order.id), 2)
      B.DR.Crafts:ToggleWant(entry)
      net:Advance(5)
      H.eq(A.DR.Crafts:WantMap()[17635].n, 1, "Brumelune retire son +1")
    end)

    H.test("+1 : où la trouver, et qui pourrait l'apprendre", function()
      local order = A.DR.Crafts:WantMap()[17635].order
      H.ok(B.DR.Crafts:SetWhere(order.id, "Marchand de patrons, Hurlevent"))
      net:Advance(5)
      local o = A.DR.Store:Get("orders", order.id)
      H.eq(o.wh, "Marchand de patrons, Hurlevent")
      H.eq(o.wb, "Brumelune-Rempart")
      local entry
      for _, e in ipairs(A.DR.Crafts:Entries(171)) do if e.id == 17635 then entry = e end end
      local learn = A.DR.Crafts:CouldLearn(entry)
      H.eq(#learn, 1)
      H.eq(learn[1].name, "Shenryu-Rempart")
    end)

    H.test("Onglet Artisans : l'arbre, les dossiers, le +1 et la fiche", function()
      B:Slash("artisans")
      local tab = B.DR.UI.tabs.artisans
      tab:RefreshQui()
      H.eq(tab.prof, 171, "le métier est choisi d'office")
      local cats, recs = 0, 0
      for _, it in ipairs(tab.quiItems) do if it.kind == "cat" then cats = cats + 1 else recs = recs + 1 end end
      H.eq(cats, 3); H.eq(recs, 4)
      -- Un clic sur un dossier le ferme.
      tab.recipes.opts.click(tab.quiItems[1])
      recs = 0
      for _, it in ipairs(tab.quiItems) do if it.kind == "rec" then recs = recs + 1 end end
      H.eq(recs, 3, "Élixirs fermé")
      tab.modeChips:Select("nobody", true)
      H.eq(#tab.quiEntries, 2)
      tab.selectedRecipe = 17635
      tab:RefreshQuiDetail()
      H.ok(tab.quiDetail.lost:IsShown() and not tab.quiDetail.known:IsShown(), "fiche « personne ne sait »")
      tab.quiDetail.want:Click()
      net:Advance(5)
      H.ok(B.DR.Crafts:WantMap()[17635].mine, "mon +1")
      H.eq(tab.quiDetail.want.label:GetText(), "Retirer mon +1")
      tab.modeChips:Select("all", true)
      tab.selectedRecipe = 3451
      tab:RefreshQuiDetail()
      H.ok(tab.quiDetail.known:IsShown(), "fiche avec artisans")
      tab.chips:Select("recherches", true)
      tab.chips:Select("qui", true)
      H.eq(chatHas(B, "Erreur"), false)
    end)

    H.test("Onglet Mes persos : métiers lus et à ouvrir", function()
      A:Slash("persos")
      local tab = A.DR.UI.tabs.persos
      tab:Refresh()
      H.ok(tab.progress:GetText():find("1 sur 1", 1, true), tab.progress:GetText())
      H.eq(chatHas(A, "Erreur"), false)
    end)
  end

  ---------------------------------------------------------------------------
  -- Effort de guerre : objectifs, banque de guilde, dons
  ---------------------------------------------------------------------------
  do
    local net = H.NewNetwork()
    net:SetRoster({
      { name = "Shenryu", rankIndex = 1, rankName = "Officier", class = "PALADIN" },
      { name = "Brumelune", rankIndex = 2, class = "MAGE" },
      { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
    })
    local bank = {
      tabs = 1,
      money = {
        { "deposit", "Pikvol", 250000, 0, 0, 0, 3 },    -- 25 po il y a 3 h
        { "deposit", "Brumelune", 100000, 0, 0, 1, 2 }, -- 10 po hier
        { "withdraw", "Shenryu", 50000, 0, 0, 1, 0 },   -- un retrait : ne compte pas
        { "repair", "Pikvol", 300, 0, 0, 0, 2 },        -- une réparation : ne compte pas
      },
      items = { [1] = {
        { "deposit", "Pikvol", "|cff1eff00|Hitem:3451:0|h[Potion de soins majeure]|h|r", 5, 0, 0, 0, 0, 0, 1 },
        { "withdraw", "Brumelune", "|Hitem:3451:0|h[Potion de soins majeure]|h", 2, 0, 0, 0, 0, 0, 5 },
      } },
    }
    local A = net:AddClient({ name = "Shenryu", rankIndex = 1, guild = "Dernier Rempart", bank = bank })
    local B = net:AddClient({ name = "Brumelune", guild = "Dernier Rempart", bank = bank })
    net:Advance(5)
    local E = A.DR.Effort
    local fromDay = os.date("%d/%m/%Y", net:ServerTime() - 5 * 86400)
    local goal

    H.test("Objectif : seul un officier en crée un, il est partagé", function()
      local r, err = B.DR.Effort:SaveGoal({ t = "Coffre", k = "or", amt = "200 po" })
      H.eq(r, nil); H.ok(err:find("officiers", 1, true))
      local bad, why = E:SaveGoal({ t = "Coffre", k = "or", amt = "beaucoup" })
      H.eq(bad, nil); H.ok(why:find("Montant invalide", 1, true))
      goal = assert(E:SaveGoal({ t = "Coffre de guilde, onglet 2", k = "or", amt = "200 po", from = fromDay,
        to = os.date("%d/%m/%Y", net:ServerTime() + 35 * 86400), tag = "Onglet 2" }))
      H.eq(goal.amt, 2000000)
      net:Advance(5)
      H.ok(B.DR.Store:Get("goals", goal.id), "arrivé chez Brumelune")
    end)

    H.test("Banque : ouvrir la banque lit les dépôts, pas les retraits ni les réparations", function()
      B:Fire("GUILDBANKFRAME_OPENED")
      net:Advance(6)
      local gifts = B.DR.Store:List("gifts")
      H.eq(#gifts, 3, "deux dépôts d'or et un dépôt d'objets")
      local gold, items = 0, 0
      for _, g in ipairs(gifts) do
        if g.k == "or" then gold = gold + g.a else items = items + g.a; H.eq(g.it, 3451) end
        H.eq(g.src, "bank"); H.eq(g.rd, "Brumelune-Rempart")
      end
      H.eq(gold, 350000); H.eq(items, 5)
      H.ok(chatHas(B, "banque de guilde lue"), "message dans le chat")
    end)

    H.test("Banque : lue par un seul membre, les autres la voient", function()
      net:Advance(5)
      local snap = E:Snapshot()
      local p = snap.progress[goal.id]
      H.eq(p.total, 350000)
      H.eq(p.donors, 2)
      H.eq(p.status, "going")
      local st = E:BankStatus()
      H.ok(st and st.by == "Brumelune-Rempart" and st.nw == 3, "dernière lecture visible de tous")
      H.eq(#E:Recent(), 3)
    end)

    H.test("Banque : deux membres qui lisent le même journal ne comptent pas deux fois", function()
      A:Fire("GUILDBANKFRAME_OPENED")
      net:Advance(6)
      net:Advance(5)
      H.ok(#A.DR.Store:List("gifts") > 3, "Shenryu a aussi gardé ses propres lignes")
      E.snap = nil
      B.DR.Effort.snap = nil
      H.eq(E:Snapshot().progress[goal.id].total, 350000, "toujours 35 po")
      H.eq(#E:Recent(), 3, "toujours trois dons")
      H.eq(B.DR.Effort:Snapshot().progress[goal.id].total, 350000)
    end)

    H.test("Banque : relire le même journal ne crée rien de nouveau", function()
      local before = #A.DR.Store:List("gifts")
      A:Fire("GUILDBANKFRAME_OPENED")
      net:Advance(6)
      H.eq(#A.DR.Store:List("gifts"), before)
    end)

    H.test("Deux dépôts identiques dans le journal restent deux dons", function()
      local twice = { tabs = 1, money = {
        { "deposit", "Pikvol", 50000, 0, 0, 0, 1 },
        { "deposit", "Pikvol", 50000, 0, 0, 0, 1 },
      } }
      local before = E:Snapshot().progress[goal.id].total
      A.env.GetNumGuildBankMoneyTransactions = function() return 2 end
      A.env.GetGuildBankMoneyTransaction = function(i) return unpack(twice.money[i]) end
      A.env.GetNumGuildBankTransactions = function() return 0 end
      A:Fire("GUILDBANKFRAME_OPENED")
      net:Advance(6)
      net:Advance(5)
      E.snap = nil
      H.eq(E:Snapshot().progress[goal.id].total, before + 100000)
    end)

    H.test("Objectif en objets : se remplit tout seul avec l'objet attendu", function()
      local link = "|cff1eff00|Hitem:3451:0|h[Potion de soins majeure]|h|r"
      local g = assert(E:SaveGoal({ t = "Potions", k = "objet", amt = "40", item = link, from = fromDay, tag = "Cœur du Magma" }))
      E.snap = nil
      local p = E:Snapshot().progress[g.id]
      H.eq(p.total, 5)
      H.eq(p.donors, 1)
      local bad = E:SaveGoal({ t = "Potions", k = "objet", amt = "40", item = "pas de lien" })
      H.eq(bad, nil)
    end)

    H.test("Plusieurs objectifs en or : « à classer », l'officier choisit", function()
      local g2 = assert(E:SaveGoal({ t = "Tabards", k = "or", amt = "150 po", from = fromDay }))
      E.snap = nil
      H.ok(E:ToSort() >= 3, "les dépôts d'or hésitent entre deux objectifs")
      local target
      for _, gift in ipairs(E:Snapshot().gifts) do
        if gift.k == "or" and gift.a == 100000 then target = gift end
      end
      H.eq(target.why, "classer")
      H.ok(E:Classify(target, g2.id))
      E.snap = nil
      H.eq(E:Snapshot().progress[g2.id].total, 100000)
      -- Un membre ne classe pas.
      H.ok(not B.DR.Effort:Classify(target, goal.id))
      -- Ne compte pour aucun.
      H.ok(E:Classify(target, "-"))
      E.snap = nil
      H.eq(E:Snapshot().progress[g2.id].total, 0)
      E:DeleteGoal(g2.id)
      E.snap = nil
    end)

    H.test("Déclarer à la main : compté, et un officier peut le retirer", function()
      net:Advance(5)
      local before = B.DR.Effort:Snapshot().progress[goal.id].total
      local rec, err = B.DR.Effort:Declare(goal.id, "abc", "")
      H.eq(rec, nil); H.ok(err:find("Montant invalide", 1, true))
      assert(B.DR.Effort:Declare(goal.id, "25 po", "en main propre"))
      net:Advance(5)
      E.snap = nil
      B.DR.Effort.snap = nil
      H.eq(E:Snapshot().progress[goal.id].total, before + 250000)
      local gift
      for _, g in ipairs(E:Snapshot().gifts) do if g.src == "hand" then gift = g end end
      H.ok(gift and gift.n == "en main propre")
      H.ok(not B.DR.Effort:Remove(gift), "un membre ne retire pas")
      H.ok(E:Remove(gift))
      net:Advance(5)
      E.snap = nil
      H.eq(E:Snapshot().progress[goal.id].total, before)
    end)

    H.test("Visibilité : les officiers peuvent ne montrer que les totaux", function()
      H.ok(B.DR.Effort:CanSeeDetails())
      H.ok(E:SetVisibility("officers"))
      net:Advance(5)
      H.ok(not B.DR.Effort:CanSeeDetails(), "Brumelune ne voit plus le détail")
      H.ok(E:CanSeeDetails(), "Shenryu si")
      H.ok(not B.DR.Effort:SetVisibility("all"), "un membre ne peut pas changer ça")
      E:SetVisibility("all")
    end)

    H.test("Objectif atteint, en retard, fermé", function()
      local small = assert(E:SaveGoal({ t = "Petit", k = "or", amt = "10 po", from = fromDay }))
      assert(E:Declare(small.id, "10 po", ""))
      E.snap = nil
      H.eq(E:Snapshot().progress[small.id].status, "done")
      local late = assert(E:SaveGoal({ t = "Trop tard", k = "or", amt = "9000 po", from = os.date("%d/%m/%Y", net:ServerTime() - 10 * 86400),
        to = os.date("%d/%m/%Y", net:ServerTime() + 3 * 86400) }))
      E.snap = nil
      H.eq(E:Snapshot().progress[late.id].status, "late")
      H.ok(E:SetGoalStatus(late.id, "closed"))
      E.snap = nil
      H.eq(#E:Goals("closed") >= 2, true)
      for _, g in ipairs({ small, late }) do E:DeleteGoal(g.id) end
      E.snap = nil
    end)

    H.test("Onglet Effort de guerre : formulaire, liste, mouvements, sans erreur", function()
      A.DR.db.settings.debug = true
      A:Slash("effort")
      local tab = A.DR.UI.tabs.effort
      tab:Refresh()
      H.ok(tab.bankText:GetText():find("Banque de guilde lue", 1, true), tab.bankText:GetText())
      H.ok(#tab.moves.items >= 3, "les mouvements sont listés")
      tab.newBtn:Click()
      H.ok(tab.form:IsShown(), "formulaire ouvert")
      tab.form.t:SetText("Tabards de guilde")
      tab.form.amt:SetText("150 po")
      tab.form.save:Click()
      H.ok(not tab.form:IsShown(), "fermé : " .. tab.form.error:GetText())
      H.eq(#A.DR.Effort:Goals("open"), 3)
      tab.declareBtn:Click()
      H.ok(tab.declare:IsShown(), "déclaration ouverte")
      tab.declare.goal = goal.id
      tab.declare.amt:SetText("1 po")
      tab.declare.save:Click()
      H.ok(not tab.declare:IsShown())
      tab.chips:Select("closed", true)
      tab.chips:Select("open", true)
      H.eq(chatHas(A, "Erreur"), false, "aucune erreur")
    end)

    H.test("Un dépôt fait dans l'heure de la création de l'objectif compte", function()
      -- Le journal arrondit l'heure vers le bas : « il y a moins d'une heure »
      -- tombe au début de l'heure, avant la création de l'objectif.
      local now = net:ServerTime()
      local fresh = assert(E:SaveGoal({ t = "Tout juste créé", k = "or", amt = "100 po" }))
      A.env.GetNumGuildBankMoneyTransactions = function() return 1 end
      A.env.GetGuildBankMoneyTransaction = function() return "deposit", "Pikvol", 123400, 0, 0, 0, 0 end
      A.env.GetNumGuildBankTransactions = function() return 0 end
      A:Fire("GUILDBANKFRAME_OPENED")
      net:Advance(6)
      net:Advance(5)
      E.snap = nil
      local gift
      for _, g in ipairs(E:Snapshot().gifts) do if g.a == 123400 then gift = g end end
      H.ok(gift and gift.at <= now, "estimé au début de l'heure")
      H.ok(gift.goal or gift.why == "classer", "attribué, ou à classer s'il y a d'autres objectifs en or ouverts")
      E:DeleteGoal(fresh.id)
      E.snap = nil
    end)

    H.test("Onglet Banque : le journal lu, membre par membre", function()
      A.DR.db.settings.debug = true
      A:Slash("banque")
      H.eq(A.DR.UI.current, "banque")
      local tab = A.DR.UI.tabs.banque
      tab:Refresh()
      H.ok(#tab.moves.items >= 3, "les mouvements sont listés, même hors objectif")
      H.ok(#tab.members.items >= 2, "les membres aussi")
      tab.chips:Select("all", true)
      H.eq(chatHas(A, "Erreur"), false)
    end)

    H.test("/rempart banque dit ce que le jeu rend", function()
      A:Slash("banque test")
      H.ok(chatHas(A, "Journal d'or : 1"), "ligne du journal d'or")
      H.ok(chatHas(A, "Fonctions du journal : présentes"))
    end)

    H.test("Sans les fonctions de banque, rien ne casse", function()
      local net2, c2 = H.Guild({ clients = { { name = "Shenryu", rankIndex = 1 } } })
      c2[1]:Fire("GUILDBANKFRAME_OPENED")
      net2:Advance(5)
      c2[1]:Slash("banque test")
      H.ok(chatHas(c2[1], "absentes"))
    end)

    H.test("Lecture coupée : rien n'est lu", function()
      local function mine()
        return #B.DR.Store:List("gifts", function(g) return g.rd == "Brumelune-Rempart" end)
      end
      B.DR.db.settings.readBank = false
      local before = mine()
      B.env.GetNumGuildBankMoneyTransactions = function() return 1 end
      B.env.GetGuildBankMoneyTransaction = function() return "deposit", "Pikvol", 777000, 0, 0, 0, 1 end
      B:Fire("GUILDBANKFRAME_OPENED")
      net:Advance(6)
      H.eq(mine(), before, "rien n'est lu quand la lecture est coupée")
      B.DR.db.settings.readBank = true
      B:Fire("GUILDBANKFRAME_OPENED")
      net:Advance(6)
      H.eq(mine(), before + 1, "et la lecture reprend quand on la rallume")
    end)
  end

  ---------------------------------------------------------------------------
  -- Relais automatique
  ---------------------------------------------------------------------------
  do
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    A.DR.db.settings.debug = true
    net:Advance(10)
    local now = net:ServerTime()
    local code = A.DR.Bridge.Encode({ v = 2, src = "site", at = now - 600,
      events = { { id = "s9", t = "Hyjal", k = "raid", d = now + 86400, u = now - 700 } } })
    local data = { v = 1, at = now - 600, code = code,
      sent = { at = now - 1200, when = now - 240, counts = { signups = 3, orders = 1, chars = 2 } } }

    H.test("Relais : sans mini add-on de données, pas de relais", function()
      local st = A.DR.Bridge:RelayStatus()
      H.eq(st.level, "none")
      H.eq(A.DR.Bridge:ApplyRelay(), false)
    end)

    H.test("Relais : le code du site est appliqué, l'envoi au site est noté", function()
      A.env.DernierRempartData = data
      H.ok(A.DR.Bridge:ApplyRelay())
      H.ok(A.DR.Calendar:Get("s9"), "sortie du site importée")
      local st = A.DR.Bridge:RelayStatus()
      H.eq(st.level, "ok")
      H.eq(st.lastApply.via, "relais")
      H.eq(st.lastSent.counts.signups, 3)
      H.eq(A.DR.Bridge.CountsText(st.lastSent.counts), "3 inscriptions, 1 commande, 2 fiches perso")
      H.eq(#st.relayers, 1)
      H.ok(st.relayers[1].me)
      net:Advance(5)
      H.ok(B.DR.Calendar:Get("s9"), "diffusée à la guilde")
      H.ok(B.DR.Store:Get("meta", "relay:Shenryu-Rempart"), "tout le monde sait qui assure le relais")
    end)

    H.test("Relais : appliqué une seule fois par dépôt", function()
      local again = A.DR.Bridge:ApplyRelay()
      H.eq(again, false)
    end)

    H.test("Relais : un membre ne passe pas le code du site, mais retient l'envoi", function()
      B.env.DernierRempartData = data
      B.DR.Bridge:ApplyRelay()
      local st = B.DR.Bridge:RelayStatus()
      H.eq(st.lastSent.counts.orders, 1)
      H.eq(st.lastApply, nil, "rien appliqué")
    end)

    H.test("Relais : des données abîmées sont ignorées", function()
      A.env.DernierRempartData = { v = 2, code = code }
      H.eq(A.DR.Bridge:RelayData(), nil)
      A.env.DernierRempartData = { v = 1, at = now, code = string.rep("x", 900000) }
      H.eq(A.DR.Bridge:RelayData().code, nil)
      A.env.DernierRempartData = { v = 1, at = now + 5, code = "DR2:abîmé" }
      H.eq(A.DR.Bridge:ApplyRelay(), false)
      A.env.DernierRempartData = data
    end)

    H.test("Relais : à la déconnexion, ce que le relais enverra est prêt", function()
      H.ok(A.DR.Calendar:SetSignup("s9", "Shenryu-Rempart", "yes", "H"))
      net:Advance(3)
      A:Logout()
      local out = A.saved.outbox
      H.ok(out and out.relay, "outbox préparée pour le relais")
      local payload = A.DR.Bridge.Decode(out.code)
      H.ok(payload and payload.signups and #payload.signups == 1, "l'inscription y est")
      -- Depuis le retour du site (ack à l'heure du code), seul le nouveau repart.
      A:Login()
      A.env.DernierRempartData = { v = 1, at = now - 600, sent = { at = out.at + 1, when = out.at + 2, counts = { signups = 1 } } }
      net:Advance(3)
      A.DR.Bridge:ApplyRelay()
      A.DR.Bridge:RefreshOutbox()
      local again = A.DR.Bridge.Decode(A.env.DernierRempartDB.outbox.code)
      H.eq(again.signups, nil, "rien de nouveau depuis ce que le site a reçu")
    end)

    H.test("Les pastilles ont une largeur : sans elle le client Forever ne les affiche pas", function()
      A:Slash("artisans")
      local arts = A.DR.UI.tabs.artisans
      H.ok(arts.chips:GetWidth() > 100, "pastilles de l'onglet Artisans")
      H.ok(arts.modeChips:GetWidth() > 100)
      A:Slash("effort")
      H.ok(A.DR.UI.tabs.effort.chips:GetWidth() > 60)
      H.ok(A.DR.UI.tabs.effort.visChips:GetWidth() > 60)
    end)

    H.test("Navigation : de la liste d'achat on revient à la liste", function()
      A:Slash("artisans")
      local arts = A.DR.UI.tabs.artisans
      arts.chips:Select("recherches", true)
      H.eq(arts.view, "recherches")
      arts.backFromWishes:Click()
      H.eq(arts.view, "qui")
      arts.chips:Select("commandes", true)
      arts.backFromOrders:Click()
      H.eq(arts.view, "qui")
    end)

    H.test("Onglet Pont : l'état du relais s'affiche", function()
      A:Slash("pont")
      local tab = A.DR.UI.tabs.pont
      tab:Refresh()
      H.ok(tab.relayText:GetText():find("Relais", 1, true), tab.relayText:GetText())
      H.ok(tab.boxes[1].when:GetText():find("Envoyé", 1, true), tab.boxes[1].when:GetText())
      H.eq(chatHas(A, "Erreur"), false)
    end)
  end
end
