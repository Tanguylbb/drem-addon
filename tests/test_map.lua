-- Carte de la guilde : positions partagées à la demande.
return function(H)
  local net, cl = H.Guild({ clients = {
    { name = "Shenryu", rankIndex = 1, map = { m = 1453, x = 0.52, y = 0.61 } },
    { name = "Brumelune", map = { m = 1453, x = 0.30, y = 0.40 } },
  } })
  local A, B = cl[1], cl[2]

  H.test("Personne ne regarde : aucune position ne circule", function()
    local before = #B.sent
    net:Advance(30)
    local pos = 0
    for i = before + 1, #B.sent do if B.sent[i].prefix == "DRemP" then pos = pos + 1 end end
    H.eq(pos, 0)
  end)

  H.test("Ouvrir la carte demande les positions ; elles arrivent", function()
    A.DR.GuildMap:SetWatching("onglet", true)
    net:Advance(12)
    local p = A.DR.GuildMap:Positions()["Brumelune-Rempart"]
    H.ok(p, "position de Brumelune reçue")
    H.eq(p.m, 1453)
    H.ok(math.abs(p.x - 0.30) < 0.001)
    H.ok(A.DR.GuildMap:Positions()["Shenryu-Rempart"].me, "ma position, en local")
  end)

  H.test("Bouger renvoie la position, rester immobile non", function()
    B.map.x = 0.35
    net:Advance(8)
    H.ok(math.abs(A.DR.GuildMap:Positions()["Brumelune-Rempart"].x - 0.35) < 0.001, "nouvelle position")
  end)

  H.test("En donjon, la position disparaît", function()
    B.inInstance = true
    net:Advance(8)
    H.eq(A.DR.GuildMap:Positions()["Brumelune-Rempart"], nil)
    B.inInstance = false
  end)

  H.test("Couper le partage cache la position", function()
    net:Advance(8)
    H.ok(A.DR.GuildMap:Positions()["Brumelune-Rempart"], "revenue")
    B:Slash("position")
    net:Advance(8)
    H.eq(A.DR.GuildMap:Positions()["Brumelune-Rempart"], nil)
  end)

  H.test("Message de position abîmé ignoré", function()
    H.eq(A.DR.GuildMap.Parse("P:12:x:3"), nil)
    H.eq(A.DR.GuildMap.Parse("P:12:20000:3"), nil)
    local m, x, y = A.DR.GuildMap.Parse("P:1453:5000:2500")
    H.eq(m, 1453); H.eq(x, 0.5); H.eq(y, 0.25)
  end)
end
