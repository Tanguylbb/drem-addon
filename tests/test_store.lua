-- Magasin : fusion « le plus récent gagne », pierres tombales, empreintes.
return function(H)
  local net, cl = H.Guild()
  local A, B = cl[1], cl[2]
  local SA, SB = A.DR.Store, B.DR.Store

  H.test("Le magasin est branché sur la guilde", function()
    H.ok(SA:IsReady(), "magasin prêt chez Shenryu")
    H.eq(A.DR.guildKey, "Dernier Rempart-Rempart")
  end)

  H.test("Put date et signe l'enregistrement, ignore une écriture identique", function()
    local r = SA:Put("orders", { id = "o1", k = "recette", nm = "Flacon", s = "cherchee", req = "Shenryu-Rempart" })
    H.ok(r and r.u and r.by == "Shenryu-Rempart", "date et auteur posés")
    H.eq(SA:Put("orders", { id = "o1", k = "recette", nm = "Flacon", s = "cherchee", req = "Shenryu-Rempart" }), nil)
    local r2 = SA:Put("orders", { id = "o1", k = "recette", nm = "Flacon", s = "trouvee", req = "Shenryu-Rempart" })
    H.ok(r2.u > r.u, "la nouvelle version est strictement plus récente")
  end)

  H.test("Merge : le plus récent gagne, l'ancien est refusé", function()
    local key, t = "o9", net:ServerTime() - 1000
    H.eq(SB:Merge("orders", { id = key, k = "craft", s = "demandee", u = t + 100, by = "X" }), "new")
    H.eq(SB:Merge("orders", { id = key, k = "craft", s = "faite", u = t + 200, by = "X" }), "new")
    H.eq(SB:Merge("orders", { id = key, k = "craft", s = "acceptee", u = t + 150, by = "X" }), "older")
    H.eq(SB:Get("orders", key).s, "faite")
    H.eq(SB:Merge("orders", { id = key, k = "craft", s = "faite", u = t + 200, by = "X" }), "same")
  end)

  H.test("Merge : à égalité de date, tout le monde garde la même version", function()
    local t = net:ServerTime() - 500
    local a = { id = "t1", k = "craft", s = "acceptee", u = t, by = "A" }
    local b = { id = "t1", k = "craft", s = "faite", u = t, by = "B" }
    SA:Merge("orders", a); SA:Merge("orders", b)
    SB:Merge("orders", b); SB:Merge("orders", a)
    H.eq(SA:Get("orders", "t1").s, SB:Get("orders", "t1").s)
  end)

  H.test("Merge : refuse ce qui n'a pas de clé ou de date", function()
    H.eq(SB:Merge("orders", { k = "craft", u = 5 }), "rejected")
    H.eq(SB:Merge("orders", { id = "x", k = "craft" }), "rejected")
    H.eq(SB:Merge("inconnu", { id = "x", u = 5 }), "rejected")
    H.eq(SB:Merge("orders", { id = "x", u = net:ServerTime() + 7200 }), "rejected", "date dans le futur")
  end)

  H.test("Merge : textes trop longs coupés", function()
    SB:Merge("orders", { id = "long", k = "recette", nm = string.rep("a", 1000), u = net:ServerTime(), by = "X" })
    H.eq(#SB:Get("orders", "long").nm, 120)
  end)

  H.test("Delete pose une pierre tombale qui l'emporte", function()
    SA:Put("votes", { o = "o1", c = "Shenryu-Rempart" })
    local tomb = SA:Delete("votes", "o1|Shenryu-Rempart")
    H.ok(tomb.del == 1 and tomb.o == "o1" and tomb.c == "Shenryu-Rempart", "pierre tombale avec la clé")
    H.eq(SA:Get("votes", "o1|Shenryu-Rempart"), nil)
    H.ok(SA:GetRaw("votes", "o1|Shenryu-Rempart"), "la pierre tombale reste en mémoire")
  end)

  H.test("Empreintes : mêmes données, même empreinte, quel que soit l'ordre", function()
    local net2 = H.NewNetwork()
    net2:SetRoster({ { name = "X", rankIndex = 2 }, { name = "Y", rankIndex = 2 } })
    local x = net2:AddClient({ name = "X", guild = "G" })
    local y = net2:AddClient({ name = "Y", guild = "G" })
    net2:Advance(1)
    local recs, t = {}, net2:ServerTime() - 5000
    for i = 1, 40 do recs[i] = { id = "o" .. i, k = "craft", s = "demandee", u = t + i, by = "X" } end
    for i = 1, 40 do x.DR.Store:Merge("orders", recs[i]) end
    for i = 40, 1, -1 do y.DR.Store:Merge("orders", recs[i]) end
    local dx = x.DR.Store.DigestToString(x.DR.Store:Digest("orders"))
    local dy = y.DR.Store.DigestToString(y.DR.Store:Digest("orders"))
    H.eq(dx, dy)
    H.ok(x.DR.Store:Count("orders") == 40, "40 commandes chez X")
    y.DR.Store:Merge("orders", { id = "o7", k = "craft", s = "faite", u = t + 4000, by = "Y" })
    local theirs = x.DR.Store.DigestFromString(y.DR.Store.DigestToString(y.DR.Store:Digest("orders")))
    local diff = x.DR.Store:DiffBuckets("orders", theirs)
    H.eq(#diff, 1, "un seul seau diffère")
    H.eq(diff[1], x.DR.Store.BucketOf("o7"))
  end)

  H.test("Ménage : les vieilles pierres tombales et sorties disparaissent", function()
    local now = net:ServerTime()
    SB:Merge("events", { id = "vieux", t = "Vieux raid", d = now - 90 * 86400, u = now - 90 * 86400, by = "site" })
    H.eq(SB:GetRaw("events", "vieux"), nil, "une sortie expirée n'est même pas prise")
    SB.data.events.vieux2 = { id = "vieux2", t = "x", d = now - 90 * 86400, u = 1, by = "site" }
    SB.data.orders.mort = { id = "mort", del = 1, u = now - 40 * 86400, by = "X" }
    H.ok(SB:Purge() >= 2, "deux enregistrements purgés")
    H.eq(SB:GetRaw("orders", "mort"), nil)
  end)
end
