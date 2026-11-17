-- Version 0.5 : sorties créées par tous les membres (sauf les raids), créateur,
-- plafond, places et liste d'attente.
return function(H)
  local net, cl = H.Guild({ clients = {
    { name = "Shenryu", rankIndex = 1, class = "PALADIN" },
    { name = "Brumelune", rankIndex = 2, class = "MAGE" },
    { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
  } })
  local A, B, P = cl[1], cl[2], cl[3]
  local Cal = {
    A = A.DR.Calendar, B = B.DR.Calendar, P = P.DR.Calendar,
  }
  local day = 86400
  local function when(days) return net:ServerTime() + days * day end

  H.test("Un membre crée un donjon : il arrive chez tout le monde, avec son nom de créateur", function()
    local ev, err = Cal.B:SaveEvent({ t = "Barrow Deeps", k = "donjon", d = when(2), cap = 5 })
    H.ok(ev, err)
    net:Advance(6)
    local got = A.DR.Calendar:Get(ev.id)
    H.ok(got, "l'officier l'a reçue")
    H.eq(got.own, B.DR.playerName, "le créateur est écrit sur la sortie")
    H.ok(P.DR.Calendar:Get(ev.id), "un autre membre aussi")
  end)

  H.test("Les raids restent réservés aux officiers", function()
    local ev, err = Cal.B:SaveEvent({ t = "Cœur du Magma", k = "raid", d = when(3) })
    H.eq(ev, nil)
    H.ok(err:find("raids"), err)
    H.ok(select(1, Cal.A:CanCreate("raid")), "l'officier le peut")
    local ok, why = Cal.B:CanCreate("raid")
    H.eq(ok, false); H.ok(why:find("officiers"))
  end)

  H.test("Un membre ne peut pas faire d'un donjon un raid", function()
    local mine = Cal.B:SaveEvent({ t = "Sac de couchage", k = "soiree", d = when(2) })
    net:Advance(4)
    local ev, err = Cal.B:SaveEvent({ id = mine.id, t = "Sac de couchage", k = "raid", d = when(2) })
    H.eq(ev, nil); H.ok(err:find("raids"), err)
  end)

  H.test("Un raid forgé par un membre est refusé par les autres add-ons", function()
    B.DR.Store:Put("events", { id = "gforge1", t = "Faux raid", k = "raid", d = when(2), own = B.DR.playerName })
    net:Advance(8)
    H.eq(A.DR.Calendar:Get("gforge1"), nil, "l'officier l'ignore")
    H.eq(P.DR.Calendar:Get("gforge1"), nil, "l'autre membre aussi")
  end)

  H.test("Chacun gère les siennes : modifier, annuler, supprimer", function()
    local mine = Cal.B:SaveEvent({ t = "Soirée jeux", k = "soiree", d = when(1) })
    net:Advance(4)
    H.ok(Cal.B:CanEdit(mine), "le créateur peut")
    H.ok(not Cal.P:CanEdit(A.DR.Calendar:Get(mine.id)), "un autre membre ne peut pas")
    H.ok(Cal.A:CanEdit(mine), "l'officier peut")
    local ev, err = Cal.P:SaveEvent({ id = mine.id, t = "Piratée", k = "soiree", d = when(1) })
    H.eq(ev, nil); H.ok(err:find("propres"), err)
    H.eq(Cal.P:SetStatus(mine.id, "cancelled"), false)
    H.eq(Cal.P:Delete(mine.id), false)
    H.ok(Cal.B:SetStatus(mine.id, "cancelled"), "le créateur annule")
    net:Advance(4)
    H.eq(A.DR.Calendar:Get(mine.id).st, "cancelled")
    H.ok(Cal.A:SetStatus(mine.id, "open"), "l'officier rétablit")
    net:Advance(4)
    H.eq(B.DR.Calendar:Get(mine.id).st, "open")
    H.ok(Cal.B:Delete(mine.id), "le créateur supprime")
    net:Advance(4)
    H.eq(A.DR.Calendar:Get(mine.id), nil, "supprimée partout")
  end)

  H.test("Une modification d'un non-créateur, forgée, est refusée", function()
    local mine = Cal.B:SaveEvent({ t = "Donjon de Brumelune", k = "donjon", d = when(2) })
    net:Advance(4)
    local old = A.DR.Calendar:Get(mine.id)
    local forged = A.DR.Util.Copy(old)
    forged.t = "Volée"
    forged.own = P.DR.playerName
    P.DR.Store:Put("events", forged)
    net:Advance(8)
    H.eq(A.DR.Calendar:Get(mine.id).t, "Donjon de Brumelune", "l'officier garde la version du créateur")
    H.eq(B.DR.Calendar:Get(mine.id).t, "Donjon de Brumelune")
    -- Un officier, lui, peut modifier : le créateur reste inscrit.
    local edited = Cal.A:SaveEvent({ id = mine.id, t = "Donjon (corrigé)", k = "donjon", d = old.d })
    H.ok(edited)
    H.eq(edited.own, B.DR.playerName, "le créateur ne change pas quand un officier modifie")
    net:Advance(6)
    H.eq(B.DR.Calendar:Get(mine.id).t, "Donjon (corrigé)")
  end)

  H.test("Un membre ne touche pas aux sorties des officiers", function()
    local off = Cal.A:SaveEvent({ t = "Raid de l'officier", k = "raid", d = when(3), nt = 2, nh = 4, nd = 10 })
    net:Advance(4)
    H.ok(not Cal.B:CanEdit(off))
    local ev, err = Cal.B:SaveEvent({ id = off.id, t = "Autre", k = "donjon", d = off.d })
    H.eq(ev, nil); H.ok(err:find("propres"), err)
    H.eq(Cal.B:Delete(off.id), false)
  end)

  H.test("Plafond : 5 sorties à venir par membre, les officiers n'en ont pas", function()
    local net2, cl2 = H.Guild({ clients = {
      { name = "Shenryu", rankIndex = 1, class = "PALADIN" },
      { name = "Brumelune", rankIndex = 2, class = "MAGE" },
    } })
    local M, O = cl2[2].DR.Calendar, cl2[1].DR.Calendar
    local t0 = net2:ServerTime()
    for i = 1, 5 do
      H.ok(M:SaveEvent({ t = "Sortie " .. i, k = "autre", d = t0 + i * 86400 }), "la sortie " .. i)
    end
    local ev, err = M:SaveEvent({ t = "Sortie 6", k = "autre", d = t0 + 6 * 86400 })
    H.eq(ev, nil); H.ok(err:find("5 sorties"), err)
    -- Annuler une sortie libère une place.
    local first = M:Upcoming(60)[1]
    H.ok(M:SetStatus(first.id, "cancelled"))
    H.ok(M:SaveEvent({ t = "Sortie 6", k = "autre", d = t0 + 6 * 86400 }), "une annulée ne compte plus")
    for i = 1, 8 do
      H.ok(O:SaveEvent({ t = "Officier " .. i, k = "donjon", d = t0 + i * 3600 }), "l'officier n'est pas limité")
    end
  end)

  H.test("Un membre ne programme pas à plus de 60 jours", function()
    local ev, err = Cal.P:SaveEvent({ t = "Dans longtemps", k = "autre", d = when(90) })
    H.eq(ev, nil); H.ok(err:find("60 jours"), err)
    H.ok(Cal.A:SaveEvent({ t = "L'officier peut", k = "donjon", d = when(90) }), "l'officier peut")
  end)

  H.test("Places : 0 ou vide veut dire sans limite", function()
    local free = Cal.A:SaveEvent({ t = "Soirée libre", k = "soiree", d = when(2), cap = "0" })
    H.eq(free.cap, nil)
    local five = Cal.A:SaveEvent({ t = "Donjon à cinq", k = "donjon", d = when(2), cap = "5" })
    H.eq(five.cap, 5)
    H.eq(Cal.A.Capacity(free), nil)
    H.eq(Cal.A.Capacity(five), 5)
    H.ok(not Cal.A.WantsRoles(free), "sans rôle")
    local comp = Cal.A:SaveEvent({ t = "Avec rôles", k = "donjon", d = when(2), nt = 1, nh = 1, nd = 3 })
    H.ok(Cal.A.WantsRoles(comp), "composition")
  end)

  ---------------------------------------------------------------------------
  -- Liste d'attente
  ---------------------------------------------------------------------------
  local qnet, qcl = H.Guild({ clients = {
    { name = "Shenryu", rankIndex = 1, class = "PALADIN" },
    { name = "Brumelune", rankIndex = 2, class = "MAGE" },
    { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
  } })
  local QA, QB, QP = qcl[1], qcl[2], qcl[3]
  local qev = QA.DR.Calendar:SaveEvent({ t = "Donjon à deux", k = "donjon", d = qnet:ServerTime() + 2 * day, cap = 2 })
  qnet:Advance(4)

  H.test("Liste d'attente : les suivants attendent, dans l'ordre d'inscription", function()
    QA.DR.Calendar:SetSignup(qev.id, nil, "yes", "T")
    qnet:Advance(2)
    QB.DR.Calendar:SetSignup(qev.id, nil, "yes", "H")
    qnet:Advance(2)
    local ok, state, rank = QP.DR.Calendar:SetSignup(qev.id, nil, "yes", "D")
    H.ok(ok)
    H.eq(state, "wait", "le troisième est en attente")
    H.eq(rank, 1)
    qnet:Advance(6)
    local c = QA.DR.Calendar:Counts(qev.id)
    H.eq(c.yes, 2); H.eq(c.wait, 1)
    H.eq(c.D, 0, "celui qui attend ne compte pas dans la composition")
    local waiting
    for _, e in ipairs(QA.DR.Calendar:Entries(qev.id)) do
      if e.state == "wait" then waiting = e.s.c end
    end
    H.eq(waiting, QP.DR.playerName)
  end)

  H.test("Liste d'attente : une place libérée monte le suivant sans rien faire", function()
    QB.DR.Calendar:SetSignup(qev.id, nil, "no", "H")
    qnet:Advance(6)
    local c = QA.DR.Calendar:Counts(qev.id)
    H.eq(c.yes, 2); H.eq(c.wait, 0, "plus personne en attente")
    H.eq(c.D, 1, "Pikvol est monté")
    H.eq(QP.DR.Calendar:MyState(qev.id), "in", "il le voit aussi chez lui")
  end)

  H.test("Liste d'attente : changer de rôle garde sa place, partir et revenir la perd", function()
    -- Brumelune revient : il passe derrière Pikvol.
    local _, state, rank = QB.DR.Calendar:SetSignup(qev.id, nil, "yes", "H")
    H.eq(state, "wait"); H.eq(rank, 1)
    -- Pikvol change de rôle : sa place ne bouge pas.
    QP.DR.Calendar:SetSignup(qev.id, nil, "yes", "T")
    qnet:Advance(6)
    H.eq(QP.DR.Calendar:MyState(qev.id), "in", "il reste devant")
    H.eq(QB.DR.Calendar:MyState(qev.id), "wait")
  end)

  H.test("Liste d'attente : « Peut-être » et « Remplaçant » ne prennent pas de place", function()
    local qev2 = QA.DR.Calendar:SaveEvent({ t = "Donjon à un", k = "donjon", d = qnet:ServerTime() + 3 * day, cap = 1 })
    qnet:Advance(3)
    QA.DR.Calendar:SetSignup(qev2.id, nil, "yes", "T")
    QB.DR.Calendar:SetSignup(qev2.id, nil, "maybe", "H")
    QP.DR.Calendar:SetSignup(qev2.id, nil, "bench", "D")
    qnet:Advance(6)
    local c = QA.DR.Calendar:Counts(qev2.id)
    H.eq(c.yes, 1); H.eq(c.maybe, 1); H.eq(c.bench, 1); H.eq(c.wait, 0)
  end)

  H.test("Sans limite de places, personne n'attend", function()
    local free = QA.DR.Calendar:SaveEvent({ t = "Soirée", k = "soiree", d = qnet:ServerTime() + 3 * day })
    qnet:Advance(3)
    for _, c in ipairs({ QA, QB, QP }) do c.DR.Calendar:SetSignup(free.id, nil, "yes", "D") end
    qnet:Advance(6)
    H.eq(QA.DR.Calendar:Counts(free.id).wait, 0)
    H.eq(QA.DR.Calendar:Counts(free.id).yes, 3)
  end)

  H.test("Une sortie sans rôle ne demande pas de rôle", function()
    local B2 = QB.DR.UI
    QB:Slash("sorties")
    local tab = B2.tabs.sorties
    local free
    for _, e in ipairs(QA.DR.Calendar:Upcoming(60)) do if e.t == "Soirée" then free = e end end
    tab.selected = free.id
    tab.answerFor = nil
    tab:Refresh()
    H.ok(not tab.detail.roleRow:IsShown(), "pas de ligne « Mon rôle »")
  end)

  ---------------------------------------------------------------------------
  -- Le formulaire pour un membre
  ---------------------------------------------------------------------------
  H.test("Formulaire : un membre voit « Nouvelle sortie », sans le raid, avec des suggestions de donjon", function()
    QB:Slash("sorties")
    local tab = QB.DR.UI.tabs.sorties
    tab:Refresh()
    H.ok(tab.newBtn:IsShown(), "le bouton est pour tous")
    tab:OpenForm(nil)
    local form = tab.form
    H.ok(form:IsShown(), "le formulaire s'ouvre")
    H.eq(form.kind, "donjon", "un membre commence par un donjon")
    H.ok(not form.kinds.raid:IsEnabled(), "le raid est grisé")
    tab:SetFormKind("raid")
    H.eq(form.kind, "donjon", "cliquer sur Raid ne change rien")
    H.eq(form.cap:GetText(), "5", "cinq places proposées")
    H.eq(form.roleMode, "comp", "un donjon demande une composition")
    H.eq(form.needs.T:GetText(), "1"); H.eq(form.needs.H:GetText(), "1"); H.eq(form.needs.D:GetText(), "3")
    form.t:SetText("Donjon de Brumelune")
    form.date:SetText(os.date("%d/%m/%Y", qnet:ServerTime() + 4 * day))
    form.time:SetText("20:30")
    tab:SaveForm()
    H.ok(not form:IsShown(), "enregistré")
    qnet:Advance(6)
    local found
    for _, e in ipairs(QA.DR.Calendar:Upcoming(60)) do if e.t == "Donjon de Brumelune" then found = e end end
    H.ok(found, "l'officier voit la sortie du membre")
    H.eq(found.own, QB.DR.playerName)
    H.eq(found.cap, 5); H.eq(found.nt, 1); H.eq(found.nd, 3)
  end)

  H.test("Formulaire : une soirée est sans rôle, et « Sans rôle » enregistre des zéros", function()
    local tab = QB.DR.UI.tabs.sorties
    tab:OpenForm(nil)
    local form = tab.form
    tab:SetFormKind("soiree")
    H.eq(form.roleMode, "none", "une soirée n'a pas de rôle par défaut")
    tab:SetFormRoleMode("comp")
    form.needs.T:SetText("2")
    tab:SetFormRoleMode("none")
    form.t:SetText("Soirée pêche")
    form.date:SetText(os.date("%d/%m/%Y", qnet:ServerTime() + 5 * day))
    form.time:SetText("21:00")
    tab:SaveForm()
    local found
    for _, e in ipairs(QB.DR.Calendar:Upcoming(60)) do if e.t == "Soirée pêche" then found = e end end
    H.ok(found, "créée")
    H.eq(found.nt, 0, "pas de rôle demandé")
    H.ok(not QB.DR.Calendar.WantsRoles(found))
  end)

  H.test("Formulaire : au-delà de cinq sorties, le membre est prévenu et le formulaire ne s'ouvre pas", function()
    local tab = QB.DR.UI.tabs.sorties
    local t0 = qnet:ServerTime()
    local n = QB.DR.Calendar:MyActiveCount()
    for i = n + 1, 5 do
      H.ok(QB.DR.Calendar:SaveEvent({ t = "Rempli " .. i, k = "autre", d = t0 + (6 + i) * day }))
    end
    tab.form:Hide()
    tab:OpenForm(nil)
    H.ok(not tab.form:IsShown(), "pas de formulaire quand le plafond est atteint")
  end)

  H.test("Détail : le créateur a Modifier et Fermer, un autre membre non, et la barre des places est là", function()
    local tab = QB.DR.UI.tabs.sorties
    local mine
    for _, e in ipairs(QA.DR.Calendar:Upcoming(60)) do if e.t == "Donjon de Brumelune" then mine = e end end
    tab.selected = mine.id
    tab.answerFor = nil
    tab:Refresh()
    H.ok(tab.detail.editBtn:IsShown() and tab.detail.lockBtn:IsShown(), "boutons du créateur")
    H.ok(tab.detail.seen:IsShown(), "la bande « Organisateur »")
    QP:Slash("sorties")
    local other = QP.DR.UI.tabs.sorties
    other.selected = mine.id
    other.answerFor = nil
    other:Refresh()
    H.ok(not other.detail.editBtn:IsShown(), "un autre membre ne modifie pas")
    local full = QA.DR.Calendar:SaveEvent({ t = "Soirée à trois", k = "soiree", d = qnet:ServerTime() + 4 * day, cap = 3 })
    qnet:Advance(4)
    other.selected = full.id
    other.answerFor = nil
    other:Refresh()
    H.ok(other.detail.capBar:IsShown(), "sans rôle mais avec des places : une barre « Places »")
  end)
end
