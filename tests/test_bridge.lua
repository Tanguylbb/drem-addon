-- Pont avec le site : codes DR2.
return function(H)
  local net, cl = H.Guild()
  local A, B = cl[1], cl[2]
  local Bridge = A.DR.Bridge

  local function siteCode(payload)
    payload.v = payload.v or 2
    payload.src = "site"
    return Bridge.Encode(payload)
  end

  H.test("Erreurs claires sur un mauvais code", function()
    local _, err = Bridge.Decode("")
    H.ok(err:find("Colle"))
    _, err = Bridge.Decode("DR1:eyJjIjpbXX0=")
    H.ok(err:find("DR1"), "code DR1 reconnu")
    _, err = Bridge.Decode("bonjour")
    H.ok(err:find("DR2"))
    _, err = Bridge.Decode("DR2:" .. A.DR.Base64.Encode('{"v":2,"events":[') )
    H.ok(err:find("incomplet"))
    _, err = Bridge.Decode(Bridge.Encode({ v = 9 }))
    H.ok(err:find("Version"))
  end)

  local now = net:ServerTime()
  local payload = {
    at = now - 3600,
    events = {
      { id = "s42", t = "Repaire d’Onyxia", k = "raid", d = now + 5 * 86400, nt = 4, nh = 10, nd = 26, cap = 40,
        st = "open", u = now - 7200 },
    },
    signups = {
      { e = "s42", c = "Galdrin-Rempart", cl = "PALADIN", r = "T", s = "yes", u = now - 7000, by = "Galdrin-Rempart" },
    },
  }

  H.test("Aperçu avant import : ce qui va changer", function()
    local decoded = assert(Bridge.Decode(siteCode(payload)))
    local p = Bridge:Preview(decoded)
    H.eq(p.total, 2)
    H.eq(p.lines[1], "sorties : 1 nouvelle(s)")
    H.eq(p.lines[2], "inscriptions : 1 nouvelle(s)")
  end)

  H.test("Import : pris, partagé avec la guilde, fraîcheur mise à jour", function()
    local decoded = assert(Bridge.Decode(siteCode(payload)))
    local counts = assert(Bridge:Import(decoded))
    H.eq(counts.taken, 2)
    net:Advance(5)
    local ev = B.DR.Calendar:Get("s42")
    H.ok(ev, "la sortie du site est arrivée chez Brumelune")
    H.eq(ev.src, "site")
    H.eq(B.DR.Calendar:Counts("s42").T, 1)
    local level, at = B.DR.Bridge:Freshness()
    H.eq(level, "vert")
    H.eq(at, now - 3600)
  end)

  H.test("Coller deux fois le même code ne compte rien deux fois", function()
    local decoded = assert(Bridge.Decode(siteCode(payload)))
    H.eq(Bridge:Preview(decoded).total, 0)
    H.eq(Bridge:Import(decoded).taken, 0)
    H.eq(A.DR.Calendar:Counts("s42").total, 1)
  end)

  H.test("Le site ne remplace pas plus récent que lui", function()
    A.DR.Calendar:SetSignup("s42", nil, "yes", "H")
    net:Advance(2)
    local old = { at = now, signups = { { e = "s42", c = "Shenryu-Rempart", s = "no", r = "H", u = now - 99999 } } }
    local p = Bridge:Preview(assert(Bridge.Decode(siteCode(old))))
    H.eq(p.older, 1)
    H.eq(p.total, 0)
  end)

  H.test("Un membre ne peut pas importer", function()
    local _, err = B.DR.Bridge:Import(payload)
    H.ok(err:find("officiers"))
  end)

  H.test("Export : ce qui a changé depuis le dernier code, sans ce qui vient du site", function()
    B.DR.Calendar:SetSignup("s42", nil, "maybe", "D", "si je finis tôt")
    net:Advance(5)
    local code, n = assert(Bridge:Export(false))
    H.ok(code:sub(1, 4) == "DR2:", "commence par DR2:")
    local back = assert(Bridge.Decode(code))
    H.eq(back.src, "jeu")
    H.eq(back.by, "Shenryu-Rempart")
    H.ok(n >= 3, "fiches perso et inscriptions dedans (" .. n .. ")")
    local found
    for _, s in ipairs(back.signups or {}) do if s.c == "Brumelune-Rempart" then found = s end end
    H.ok(found and found.m == "si je finis tôt", "inscription de Brumelune exportée")
    for _, e in ipairs(back.events or {}) do H.ok(e.by ~= "site", "rien de ce qui vient du site") end
    for _, list in pairs(back) do
      if type(list) == "table" then
        for _, r in ipairs(list) do H.eq(r._r, nil, "aucun champ local exporté") end
      end
    end
    H.eq((Bridge:PendingCount()), 0, "plus rien en attente après le code")
    H.eq(A.DR.db.outbox.code, code, "gardé pour un relais")
  end)

  H.test("Export « tout renvoyer »", function()
    local _, n = Bridge:Export(true)
    H.ok(n >= 3)
  end)
end
