-- Artisans : lecture des recettes, recherche, recettes recherchées, commandes.
return function(H)
  local net, cl = H.Guild()
  local A, B = cl[1], cl[2]

  -- Shenryu, alchimiste, ouvre sa fenêtre de métier.
  A.tradeskill = { id = 171, name = "Alchimie", all = { 3451, 17556, 17635, 11450 },
    learned = { [3451] = true, [11450] = true } }
  A:Fire("TRADE_SKILL_SHOW")
  net:Advance(5)

  H.test("Les recettes apprises sont lues et partagées", function()
    local r = B.DR.Store:Get("recipes", "Shenryu-Rempart|171")
    H.ok(r, "liste arrivée chez Brumelune")
    H.eq(table.concat(r.l, ","), "3451,11450")
    H.eq(r.pn, "Alchimie")
    local said = false
    for _, m in ipairs(A.chat) do if m:find("2 recettes lues", 1, true) then said = true end end
    H.ok(said, "message dans le chat")
  end)

  H.test("Le catalogue montre ce que personne ne sait faire", function()
    local missing = B.DR.Crafts:Search("", nil, "missing")
    local ids = {}
    for _, e in ipairs(missing) do ids[#ids + 1] = e.id end
    table.sort(ids)
    H.eq(table.concat(ids, ","), "17556,17635")
  end)

  H.test("Chercher « potion de soins » trouve Shenryu", function()
    local res = B.DR.Crafts:Search("potion de soins", nil, "known")
    H.eq(#res, 1)
    H.eq(res[1].id, 3451)
    local crafters = B.DR.Crafts:CraftersOf(3451)
    H.eq(crafters[1].name, "Shenryu-Rempart")
    H.ok(crafters[1].online, "en ligne")
  end)

  H.test("Rouvrir la fenêtre sans changement ne renvoie rien", function()
    net:Advance(30) -- laisse passer la synchro de connexion
    local before = #A.sent
    A:Fire("TRADE_SKILL_LIST_UPDATE")
    net:Advance(5)
    H.eq(#A.sent, before)
  end)

  H.test("Commande de fabrication : demandée, acceptée, faite", function()
    local o = assert(B.DR.Crafts:RequestCraft(3451, "Shenryu-Rempart", "j'ai les herbes"))
    net:Advance(5)
    local mine = A.DR.Crafts:Orders("craft", "forme")
    H.eq(#mine, 1)
    local told = false
    for _, m in ipairs(A.chat) do if m:find("te demande", 1, true) then told = true end end
    H.ok(told, "Shenryu est prévenu dans le chat")
    H.ok(A.DR.Crafts:SetOrderStatus(o.id, "acceptee"))
    net:Advance(5)
    H.eq(B.DR.Store:Get("orders", o.id).s, "acceptee")
    A.DR.Crafts:SetOrderStatus(o.id, "faite")
    net:Advance(5)
    H.eq(B.DR.Store:Get("orders", o.id).s, "faite")
    H.eq(B.DR.Store:Get("orders", o.id).who, "Shenryu-Rempart")
  end)

  local wish
  H.test("Recette recherchée par lien : créée avec un soutien", function()
    local link = "|cff71d5ff|Hspell:17635:0|h[Flacon des Titans]|h|r"
    wish = assert(B.DR.Crafts:Wish(link, { id = 171, name = "Alchimie" }))
    H.eq(wish.sp, 17635)
    H.eq(wish.nm, "Flacon des Titans")
    net:Advance(5)
    local n, mine = A.DR.Crafts:Votes(wish.id)
    H.eq(n, 1); H.eq(mine, false)
  end)

  H.test("« Moi aussi » ajoute un soutien, une deuxième demande aussi", function()
    A.DR.Crafts:Vote(wish.id, true)
    net:Advance(5)
    H.eq((B.DR.Crafts:Votes(wish.id)), 2)
    A.DR.Crafts:Vote(wish.id, false)
    net:Advance(5)
    H.eq((B.DR.Crafts:Votes(wish.id)), 1)
    local again, msg = A.DR.Crafts:Wish("|Hspell:17635|h[Flacon des Titans]|h")
    H.eq(again.id, wish.id, "pas de doublon")
    H.ok(msg:find("Déjà recherchée"))
    net:Advance(5)
    H.eq((B.DR.Crafts:Votes(wish.id)), 2)
  end)

  H.test("Une recette déjà connue n'est pas « recherchée »", function()
    local r, msg = B.DR.Crafts:Wish("|Hspell:3451|h[Potion de soins majeure]|h")
    H.eq(r, nil)
    H.ok(msg:find("sait déjà"))
  end)

  H.test("Apprendre la recette ferme la demande toute seule", function()
    A.tradeskill.learned[17635] = true
    A:Fire("TRADE_SKILL_LIST_UPDATE")
    net:Advance(5)
    local w = B.DR.Store:Get("orders", wish.id)
    H.eq(w.s, "apprise")
    H.eq(w.who, "Shenryu-Rempart")
  end)

  H.test("Recette recherchée par simple nom", function()
    local r = assert(B.DR.Crafts:Wish("Enchanter arme - Croisé", { id = 333, name = "Enchantement" }))
    H.eq(r.sp, nil)
    H.eq(r.nm, "Enchanter arme - Croisé")
    H.eq(r.pn, "Enchantement")
  end)

  H.test("Lecture d'un lien collé", function()
    local p = A.DR.Crafts.ParseWishInput("  |cffffffff|Hitem:13518:0|h[Formule : Enchanter arme - Croisé]|h|r ")
    H.eq(p.it, 13518)
    H.eq(p.nm, "Formule : Enchanter arme - Croisé")
    H.eq(A.DR.Crafts.ParseWishInput("   "), nil)
  end)
end
