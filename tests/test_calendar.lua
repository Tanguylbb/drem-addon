-- Sorties et inscriptions.
return function(H)
  local net, cl = H.Guild()
  local A, B = cl[1], cl[2]
  local Cal = A.DR.Calendar

  local ev = Cal:SaveEvent({ t = "Barrow Deeps", k = "raid", d = net:ServerTime() + 2 * 86400,
    nt = 2, nh = 3, nd = 5, cap = 10, lead = "Brannoc" })
  net:Advance(5)

  H.test("Compter les présents par rôle et dire ce qui manque", function()
    Cal:SetSignup(ev.id, nil, "yes", "T")
    B.DR.Calendar:SetSignup(ev.id, nil, "yes", "H")
    net:Advance(5)
    local c = Cal:Counts(ev.id)
    H.eq(c.yes, 2); H.eq(c.T, 1); H.eq(c.H, 1); H.eq(c.D, 0)
    H.eq(Cal:MissingText(ev), "Manque 1 tank, 2 soins, 5 DPS")
  end)

  H.test("Changer de réponse remplace l'ancienne", function()
    B.DR.Calendar:SetSignup(ev.id, nil, "maybe", "H", "après 22 h")
    net:Advance(5)
    local c = Cal:Counts(ev.id)
    H.eq(c.yes, 1); H.eq(c.maybe, 1)
    H.eq(Cal:MySignup(ev.id).s, "yes")
    H.eq(B.DR.Calendar:MySignup(ev.id).m, "après 22 h")
  end)

  H.test("Un seul perso par compte et par sortie", function()
    -- Un reroll de Brumelune, sur le même compte.
    local acc = B.DR.db.accountId
    B.DR.db.myChars["Brumalt-Rempart"] = { n = "Brumalt-Rempart", cl = "PRIEST", lv = 58, acc = acc, g = "Dernier Rempart" }
    B.DR.Calendar:SetSignup(ev.id, "Brumalt-Rempart", "yes", "H")
    net:Advance(5)
    local names = {}
    for _, s in ipairs(Cal:Signups(ev.id)) do names[#names + 1] = s.c end
    table.sort(names)
    H.eq(table.concat(names, ","), "Brumalt-Rempart,Shenryu-Rempart")
  end)

  H.test("On n'inscrit pas le perso d'un autre", function()
    local ok, err = B.DR.Calendar:SetSignup(ev.id, "Pikvol-Rempart", "yes", "D")
    H.eq(ok, false)
    H.ok(err:find("tes propres persos"))
  end)

  H.test("Inscriptions fermées : les membres ne changent plus, l'officier si", function()
    H.ok(Cal:SetStatus(ev.id, "closed"))
    net:Advance(5)
    local ok, err = B.DR.Calendar:SetSignup(ev.id, nil, "no", "H")
    H.eq(ok, false)
    H.ok(err:find("fermées"))
    H.ok(Cal:SetSignup(ev.id, nil, "bench", "T"), "l'officier peut encore")
    Cal:SetStatus(ev.id, "open")
    net:Advance(5)
  end)

  H.test("Sortie annulée : visible, hors des « prochaines »", function()
    local ev2 = Cal:SaveEvent({ t = "Soirée pêche", k = "soiree", d = net:ServerTime() + 3600 })
    Cal:SetStatus(ev2.id, "cancelled")
    net:Advance(5)
    H.eq(B.DR.Calendar:Get(ev2.id).st, "cancelled")
    H.ok(B.DR.Calendar:Next().id ~= ev2.id, "la prochaine sortie n'est pas l'annulée")
  end)

  H.test("Sorties qui attendent ma réponse", function()
    local ev3 = Cal:SaveEvent({ t = "Scholomance", k = "donjon", d = net:ServerTime() + 5 * 86400 })
    net:Advance(5)
    local waiting = B.DR.Calendar:AwaitingAnswer()
    local found = false
    for _, e in ipairs(waiting) do if e.id == ev3.id then found = true end end
    H.ok(found, "Scholomance attend la réponse de Brumelune")
  end)

  H.test("Formulaire : titre et date obligatoires", function()
    local r, err = Cal:SaveEvent({ t = "", d = net:ServerTime() })
    H.eq(r, nil); H.ok(err:find("titre"))
    r, err = Cal:SaveEvent({ t = "Sans date" })
    H.eq(r, nil); H.ok(err:find("Date"))
  end)

  H.test("Supprimer une sortie la retire partout", function()
    local ev4 = Cal:SaveEvent({ t = "Erreur", d = net:ServerTime() + 3600 })
    net:Advance(5)
    H.ok(B.DR.Calendar:Get(ev4.id))
    Cal:Delete(ev4.id)
    net:Advance(5)
    H.eq(B.DR.Calendar:Get(ev4.id), nil)
  end)
end
