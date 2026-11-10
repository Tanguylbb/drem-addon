-- Synchro entre plusieurs joueurs connectés.
return function(H)
  local function digests(client)
    local S, out = client.DR.Store, {}
    for _, ds in ipairs(S.DATASETS) do out[ds] = S.DigestToString(S:Digest(ds)) end
    return out
  end

  local function sameData(a, b)
    local da, db = digests(a), digests(b)
    for ds, d in pairs(da) do
      if db[ds] ~= d then return false, ds end
    end
    return true
  end

  H.test("Une sortie créée par l'officier arrive chez les membres connectés", function()
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    H.ok(A.DR.Guild:IAmOfficer(), "Shenryu est officier")
    H.ok(not B.DR.Guild:IAmOfficer(), "Brumelune ne l'est pas")
    local ev = assert(A.DR.Calendar:SaveEvent({
      t = "Barrow Deeps", k = "raid", d = net:ServerTime() + 2 * 86400, nt = 2, nh = 3, nd = 5, cap = 10,
    }))
    net:Advance(5)
    local got = B.DR.Calendar:Get(ev.id)
    H.ok(got, "la sortie est arrivée")
    H.eq(got.t, "Barrow Deeps")
    H.eq(got.nh, 3)
  end)

  H.test("L'inscription d'un membre arrive chez l'officier", function()
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    local ev = A.DR.Calendar:SaveEvent({ t = "Onyxia", k = "raid", d = net:ServerTime() + 86400, nt = 1, nh = 1, nd = 1 })
    net:Advance(5)
    H.ok(B.DR.Calendar:SetSignup(ev.id, nil, "yes", "H", "je ramène des fioles"))
    net:Advance(5)
    local signups = A.DR.Calendar:Signups(ev.id)
    H.eq(#signups, 1)
    H.eq(signups[1].c, "Brumelune-Rempart")
    H.eq(signups[1].m, "je ramène des fioles")
    H.eq(A.DR.Calendar:Counts(ev.id).H, 1)
  end)

  H.test("Un membre ne peut pas créer de sortie, et une sortie forgée est refusée", function()
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    local rec, err = B.DR.Calendar:SaveEvent({ t = "Pirate", d = net:ServerTime() + 3600 })
    H.eq(rec, nil)
    H.ok(err:find("officiers"), "message clair")
    -- Brumelune trafique un message à la main.
    B.DR.Comm:Send({ t = "up", ds = "events", r = { { id = "faux", t = "Faux", d = net:ServerTime() + 3600,
      u = net:ServerTime(), by = "Brumelune-Rempart" } } }, "high")
    net:Advance(5)
    H.eq(A.DR.Calendar:Get("faux"), nil, "refusée par l'officier")
  end)

  H.test("Un membre qui se connecte plus tard rattrape tout, et renvoie ce qu'il avait en plus", function()
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    for i = 1, 6 do
      A.DR.Calendar:SaveEvent({ t = "Sortie " .. i, k = "donjon", d = net:ServerTime() + i * 3600 })
    end
    net:Advance(10)
    -- Pikvol se connecte avec une commande faite hors ligne (dans sa sauvegarde).
    local C = net:AddClient({ name = "Pikvol", guild = "Dernier Rempart", class = "ROGUE" })
    C.DR.Store:Bind(C.DR:GetGuildDB("Dernier Rempart-Rempart"))
    C.DR.Store:Merge("orders", { id = "horsligne", k = "recette", nm = "Flacon des Titans", s = "cherchee",
      req = "Pikvol-Rempart", u = net:ServerTime() - 60, by = "Pikvol-Rempart" })
    net:Advance(60)
    H.eq(#C.DR.Calendar:Upcoming(), 6, "les 6 sorties sont arrivées")
    H.ok(A.DR.Store:Get("orders", "horsligne"), "la commande hors ligne est remontée chez Shenryu")
    H.ok(B.DR.Store:Get("orders", "horsligne"), "et chez Brumelune")
    local same, ds = sameData(A, C)
    H.ok(same, "données identiques (diffère sur " .. tostring(ds) .. ")")
  end)

  H.test("Une seule réponse par demande de synchro", function()
    local net, cl = H.Guild({ clients = {
      { name = "Shenryu", rankIndex = 1 }, { name = "Brumelune" }, { name = "Pikvol" },
    } })
    local A = cl[1]
    for i = 1, 3 do A.DR.Calendar:SaveEvent({ t = "S" .. i, d = net:ServerTime() + i * 3600 }) end
    net:Advance(10)
    local D = net:AddClient({ name = "Galdrin", guild = "Dernier Rempart", rankIndex = 0 })
    local claims = 0
    for _, c in ipairs(cl) do
      c.DR:Listen("COMM_MESSAGE", function(msg) if msg.t == "sc" then claims = claims + 1 end end)
    end
    net:Advance(40)
    H.eq(#D.DR.Calendar:Upcoming(), 3)
    -- Chaque client voit les réservations des autres : au plus une par demande.
    H.ok(claims <= 2 * 2, "réservations multiples : " .. claims)
  end)

  H.test("Les changements faits pendant un combat partent après", function()
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    local ev = A.DR.Calendar:SaveEvent({ t = "Hyjal", d = net:ServerTime() + 7200 })
    net:Advance(5)
    B.lockdown = true
    B.DR.Calendar:SetSignup(ev.id, nil, "maybe", "D")
    net:Advance(10)
    H.eq(#A.DR.Calendar:Signups(ev.id), 0, "rien pendant le combat")
    B.lockdown = false
    net:Advance(5)
    H.eq(#A.DR.Calendar:Signups(ev.id), 1, "arrivé après le combat")
  end)

  H.test("Deux modifications croisées finissent pareilles partout", function()
    local net, cl = H.Guild()
    local A, B = cl[1], cl[2]
    local ev = A.DR.Calendar:SaveEvent({ t = "Base", d = net:ServerTime() + 7200 })
    net:Advance(5)
    -- Les deux changent la même commande au même moment, sans se voir.
    local o = A.DR.Store:Put("orders", { id = "x", k = "recette", nm = "A", s = "cherchee", req = "Shenryu-Rempart" })
    net:Advance(5)
    A.lockdown, B.lockdown = true, true
    local ra = A.DR.Util.Copy(A.DR.Store:Get("orders", "x")); ra.s = "trouvee"; A.DR.Store:Put("orders", ra)
    local rb = B.DR.Util.Copy(B.DR.Store:Get("orders", "x")); rb.s = "abandonnee"; B.DR.Store:Put("orders", rb)
    A.lockdown, B.lockdown = false, false
    net:Advance(20)
    H.eq(A.DR.Store:Get("orders", "x").s, B.DR.Store:Get("orders", "x").s)
    H.ok(o and ev, "préparation")
  end)

  H.test("Une version plus récente de l'add-on est signalée", function()
    local net, cl = H.Guild()
    local E = net:AddClient({ name = "Pikvol", guild = "Dernier Rempart", version = "0.9.0" })
    net:Advance(20)
    local seen = false
    for _, m in ipairs(cl[1].chat) do if m:find("0.9.0", 1, true) then seen = true end end
    H.ok(seen, "message de mise à jour")
    H.ok(E, "client lancé")
  end)
end
