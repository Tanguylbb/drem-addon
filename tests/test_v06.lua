-- Version 0.6 : sorties sur validation du créateur (demande, accepté, en réserve,
-- pas retenu), droits, places, notifications.
return function(H)
  local function chatHas(client, text)
    for _, m in ipairs(client.chat) do if m:find(text, 1, true) then return true end end
    return false
  end

  local net, cl = H.Guild({ clients = {
    { name = "Shenryu", rankIndex = 1, class = "PALADIN" },
    { name = "Brumelune", rankIndex = 2, class = "MAGE" },
    { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
  } })
  local A, B, P = cl[1], cl[2], cl[3]
  local day = 86400
  local function when(days) return net:ServerTime() + days * day end
  -- Brumelune organise un donjon sur validation, 3 places.
  local ev = assert(B.DR.Calendar:SaveEvent({ t = "Donjon sur validation", k = "donjon", d = when(2), cap = 3,
    nt = 1, nh = 1, nd = 1, ap = true }))
  net:Advance(6)
  local Cal = { A = A.DR.Calendar, B = B.DR.Calendar, P = P.DR.Calendar }

  H.test("Sur validation : une inscription est une demande, elle ne compte pas encore", function()
    H.eq(Cal.A:Get(ev.id).ap, 1, "le mode est partagé")
    local ok, state = Cal.P:SetSignup(ev.id, nil, "yes", "D")
    H.ok(ok)
    H.eq(state, "pending", "Pikvol est en attente de validation")
    net:Advance(6)
    local c = Cal.A:Counts(ev.id)
    H.eq(c.yes, 0, "il ne compte pas dans les présents")
    H.eq(c.pending, 1)
    H.eq(c.D, 0)
    H.eq(#Cal.B:Pending(ev.id), 1, "le créateur voit la demande")
  end)

  H.test("Le créateur accepte : le demandeur compte, partout", function()
    H.ok(Cal.B:SetVerdict(ev.id, P.DR.playerName, "a"))
    net:Advance(6)
    for _, c in ipairs({ Cal.A, Cal.B, Cal.P }) do
      H.eq(c:Counts(ev.id).yes, 1)
      H.eq(c:Counts(ev.id).D, 1)
      H.eq(c:Counts(ev.id).pending, 0)
    end
    H.eq(Cal.P:MyState(ev.id), "in")
  end)

  H.test("En réserve, pas retenu, puis remis en attente", function()
    H.ok(Cal.B:SetVerdict(ev.id, P.DR.playerName, "w"))
    net:Advance(6)
    H.eq(Cal.P:MyState(ev.id), "reserve")
    H.eq(Cal.A:Counts(ev.id).reserve, 1); H.eq(Cal.A:Counts(ev.id).yes, 0)
    H.ok(Cal.B:SetVerdict(ev.id, P.DR.playerName, "r"))
    net:Advance(6)
    H.eq(Cal.P:MyState(ev.id), "refused")
    H.ok(Cal.B:SetVerdict(ev.id, P.DR.playerName, nil))
    net:Advance(6)
    H.eq(Cal.P:MyState(ev.id), "pending", "la décision supprimée remet la demande en attente")
    H.eq(Cal.A:Counts(ev.id).pending, 1)
  end)

  H.test("Seuls le créateur et les officiers décident", function()
    local ok, why = Cal.P:SetVerdict(ev.id, P.DR.playerName, "a")
    H.eq(ok, false); H.ok(why:find("organisateur"), why)
    -- Un officier, qui n'est pas le créateur, peut.
    H.ok(Cal.A:SetVerdict(ev.id, P.DR.playerName, "a"))
    net:Advance(6)
    H.eq(Cal.P:MyState(ev.id), "in")
    Cal.A:SetVerdict(ev.id, P.DR.playerName, nil)
    net:Advance(6)
  end)

  H.test("Une décision forgée par un autre membre est refusée, et ignorée à la lecture", function()
    -- Pikvol s'accepte lui-même : il écrit la décision directement dans son magasin.
    P.DR.Store:Put("verdicts", { e = ev.id, c = P.DR.playerName, v = "a" })
    net:Advance(8)
    H.eq(A.DR.Store:Get("verdicts", ev.id .. "|" .. P.DR.playerName), nil, "l'officier ne la prend pas")
    H.eq(B.DR.Store:Get("verdicts", ev.id .. "|" .. P.DR.playerName), nil, "le créateur non plus")
    H.eq(Cal.P:MyState(ev.id), "pending", "chez Pikvol même, elle ne compte pas")
    P.DR.Store:Delete("verdicts", ev.id .. "|" .. P.DR.playerName)
    net:Advance(4)
  end)

  H.test("Le créateur qui s'inscrit est accepté d'office", function()
    local ok, state = Cal.B:SetSignup(ev.id, nil, "yes", "T")
    H.ok(ok)
    H.eq(state, "in")
    net:Advance(6)
    H.eq(Cal.A:Counts(ev.id).T, 1)
  end)

  H.test("Complet : on ne peut pas accepter de plus, mais on peut mettre en réserve", function()
    -- 3 places : Brumelune (T) + 2 autres. Pikvol (D) puis un troisième compte.
    H.ok(Cal.B:SetVerdict(ev.id, P.DR.playerName, "a"))
    local ok = A.DR.Calendar:SetSignup(ev.id, nil, "yes", "H") -- l'officier s'inscrit : accepté d'office
    H.ok(ok)
    net:Advance(6)
    H.eq(Cal.A:Counts(ev.id).yes, 3, "trois acceptés : complet")
    -- Un quatrième demande.
    local extra = "Alt-Rempart"
    P.DR.db.myChars[extra] = { n = extra, cl = "WARRIOR", lv = 60, acc = "autre-compte", g = "Dernier Rempart" }
    P.DR.Store:Put("signups", { e = ev.id, c = extra, cl = "WARRIOR", r = "T", s = "yes", acc = "autre-compte", ft = net:ServerTime() })
    net:Advance(6)
    local accepted, why = Cal.B:SetVerdict(ev.id, extra, "a")
    H.eq(accepted, false); H.ok(why:find("complète"), why)
    H.ok(Cal.B:SetVerdict(ev.id, extra, "w"), "la réserve reste possible")
    net:Advance(4)
  end)

  H.test("Passer une sortie en « sur validation » accepte ceux qui étaient déjà inscrits", function()
    local free = assert(Cal.B:SaveEvent({ t = "Soirée libre puis sur validation", k = "soiree", d = when(3) }))
    net:Advance(4)
    Cal.P:SetSignup(free.id, nil, "yes", "D")
    net:Advance(4)
    local edited = assert(Cal.B:SaveEvent({ id = free.id, t = free.t, k = "soiree", d = free.d, ap = true }))
    H.eq(edited.ap, 1)
    net:Advance(6)
    H.eq(Cal.P:MyState(free.id), "in", "il était inscrit : il reste accepté")
    Cal.P:SetSignup(free.id, nil, "no", "D")
    net:Advance(2)
    H.eq(Cal.P:MyState(free.id), "no")
  end)

  H.test("Sans validation, tout reste comme avant : pas de demande", function()
    local free = assert(Cal.B:SaveEvent({ t = "Soirée libre", k = "soiree", d = when(3) }))
    net:Advance(4)
    local _, state = Cal.P:SetSignup(free.id, nil, "yes", "D")
    H.eq(state, "in")
    H.eq(#Cal.B:Pending(free.id), 0)
  end)

  H.test("À juger : mes demandes, et pour un officier celles de moins de 24 h", function()
    local near = assert(Cal.B:SaveEvent({ t = "Ce soir sur validation", k = "donjon", d = net:ServerTime() + 5 * 3600, ap = true }))
    local far = assert(Cal.B:SaveEvent({ t = "Dans trois jours sur validation", k = "donjon", d = when(3), ap = true }))
    net:Advance(4)
    Cal.P:SetSignup(near.id, nil, "yes", "D")
    Cal.P:SetSignup(far.id, nil, "yes", "D")
    net:Advance(6)
    local function titles(list)
      local t = {}
      for _, j in ipairs(list) do t[#t + 1] = j.ev.t end
      table.sort(t)
      return table.concat(t, "|")
    end
    H.ok(titles(Cal.B:ToJudge()):find("Dans trois jours", 1, true), "le créateur voit toutes ses demandes")
    H.ok(titles(Cal.B:ToJudge()):find("Ce soir", 1, true))
    local officer = titles(Cal.A:ToJudge())
    H.ok(officer:find("Ce soir", 1, true), "l'officier voit celle de moins de 24 h")
    H.ok(not officer:find("Dans trois jours", 1, true), "mais pas celle de dans trois jours")
    H.eq(#Cal.P:ToJudge(), 0, "le demandeur n'a rien à décider")
  end)

  H.test("Une demande restée sans réponse à l'heure de la sortie est marquée sans réponse", function()
    local started = assert(Cal.A:SaveEvent({ t = "Déjà commencée", k = "donjon", d = net:ServerTime() + 60, ap = true }))
    net:Advance(4)
    Cal.P:SetSignup(started.id, nil, "yes", "D")
    net:Advance(6)
    H.eq(#Cal.A:Pending(started.id), 1, "avant le début : à décider")
    net:Advance(120)
    local entries = Cal.A:Entries(started.id)
    H.eq(entries[1].state, "pending")
    H.ok(entries[1].late, "marquée sans réponse")
    H.eq(#Cal.A:Pending(started.id), 0, "et plus à décider")
  end)

  ---------------------------------------------------------------------------
  -- Notifications
  ---------------------------------------------------------------------------
  local nnet, ncl = H.Guild({ clients = {
    { name = "Shenryu", rankIndex = 1, class = "PALADIN" },
    { name = "Brumelune", rankIndex = 2, class = "MAGE" },
    { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
  } })
  local NA, NB, NP = ncl[1], ncl[2], ncl[3]
  local nev = assert(NB.DR.Calendar:SaveEvent({ t = "Soirée à valider", k = "donjon", d = nnet:ServerTime() + 2 * day, ap = true }))
  nnet:Advance(6)

  H.test("Notifications : l'organisateur est prévenu d'une demande, une seule fois par dix minutes", function()
    NP.DR.Calendar:SetSignup(nev.id, nil, "yes", "D")
    nnet:Advance(6)
    H.ok(chatHas(NB, "Pikvol demande à rejoindre « Soirée à valider »"), "une ligne dans la discussion de l'organisateur")
    H.ok(not chatHas(NA, "demande à rejoindre"), "l'officier n'est pas dérangé")
    local before = #NB.chat
    NA.DR.Calendar:SetSignup(nev.id, nil, "yes", "H") -- l'officier est accepté d'office, pas de ligne
    nnet:Advance(6)
    H.eq(#NB.chat, before, "rien de plus tout de suite")
  end)

  H.test("Notifications : le demandeur apprend la décision", function()
    NB.DR.Calendar:SetVerdict(nev.id, NP.DR.playerName, "a")
    nnet:Advance(6)
    H.ok(chatHas(NP, "Ta demande pour « Soirée à valider » est acceptée"), "acceptée")
    NB.DR.Calendar:SetVerdict(nev.id, NP.DR.playerName, "w")
    nnet:Advance(6)
    H.ok(chatHas(NP, "en réserve"), "en réserve")
    NB.DR.Calendar:SetVerdict(nev.id, NP.DR.playerName, "r")
    nnet:Advance(6)
    H.ok(chatHas(NP, "pas retenue"), "pas retenue")
  end)

  H.test("Notifications : rien en combat", function()
    local nev2 = assert(NB.DR.Calendar:SaveEvent({ t = "Pendant le combat", k = "donjon", d = nnet:ServerTime() + 2 * day, ap = true }))
    nnet:Advance(6)
    NB.combat = true
    NP.DR.Calendar:SetSignup(nev2.id, nil, "yes", "D")
    nnet:Advance(6)
    H.ok(not chatHas(NB, "Pendant le combat"), "pas de ligne en combat")
    NB.combat = false
    H.eq(#NB.DR.Calendar:Pending(nev2.id), 1, "la demande est là, la pastille la montrera")
  end)

  H.test("Notifications : le résumé de connexion et le rappel des 24 h", function()
    local nev3 = assert(NB.DR.Calendar:SaveEvent({ t = "Ce soir à valider", k = "donjon", d = nnet:ServerTime() + 4 * 3600, ap = true }))
    nnet:Advance(6)
    NP.DR.Calendar:SetSignup(nev3.id, nil, "yes", "D")
    nnet:Advance(6)
    NB.DR.Calendar:Remind()
    H.ok(chatHas(NB, "sans réponse pour « Ce soir à valider »"), "le créateur est relancé")
    NA.DR.Calendar:Remind()
    H.ok(chatHas(NA, "Tu peux les décider à sa place"), "l'officier aussi, pour une sortie de moins de 24 h")
    NB.DR.Calendar:LoginSummary()
    H.ok(chatHas(NB, "ta réponse pour"), "résumé de connexion")
  end)

  H.test("Les décisions voyagent au site", function()
    local payload = A.DR.Bridge:BuildExport(true)
    H.ok(payload.verdicts and #payload.verdicts > 0, "le code du Pont contient les décisions")
    local v = payload.verdicts[1]
    H.ok(v.e and v.c and v.v and v.u, "forme d'une décision")
    H.eq(A.DR.Bridge.LABELS.verdicts, "décisions")
  end)

  ---------------------------------------------------------------------------
  -- Écrans
  ---------------------------------------------------------------------------
  H.test("Formulaire : un raid est sur validation par défaut, un donjon libre, et ça s'enregistre", function()
    A:Slash("sorties")
    local tab = A.DR.UI.tabs.sorties
    tab:Refresh()
    tab:OpenForm(nil)
    local form = tab.form
    H.eq(form.kind, "raid", "l'officier commence par un raid")
    H.eq(form.apMode, "val", "un raid : sur validation")
    tab:SetFormKind("donjon")
    H.eq(form.apMode, "free", "un donjon : libre")
    form.apTouched = false
    tab:SetFormKind("raid")
    form.t:SetText("Raid à valider")
    form.date:SetText(os.date("%d/%m/%Y", when(6)))
    form.time:SetText("21:00")
    tab:SaveForm()
    local found
    for _, e in ipairs(Cal.A:Upcoming(60)) do if e.t == "Raid à valider" then found = e end end
    H.ok(found and found.ap == 1, "enregistré sur validation")
    -- Choix explicite : un raid libre.
    tab:OpenForm(nil)
    tab:SetFormApMode("free"); form.apTouched = true
    form.t:SetText("Raid libre")
    form.date:SetText(os.date("%d/%m/%Y", when(6)))
    form.time:SetText("22:00")
    tab:SaveForm()
    for _, e in ipairs(Cal.A:Upcoming(60)) do if e.t == "Raid libre" then found = e end end
    H.eq(found.ap, nil, "libre")
  end)

  H.test("Fiche : le demandeur voit l'état de sa demande, l'organisateur le bouton Demandes", function()
    B:Slash("sorties")
    local mine = B.DR.UI.tabs.sorties
    mine.selected = ev.id
    mine.answerFor = nil
    mine:Refresh()
    H.ok(mine.detail.review:IsShown(), "l'organisateur a le bouton « Demandes »")
    H.ok(mine.detail.review.label:GetText():find("Demandes", 1, true))
    P:Slash("sorties")
    local other = P.DR.UI.tabs.sorties
    other.selected = ev.id
    other.answerFor = nil
    other:Refresh()
    H.ok(not other.detail.review:IsShown(), "le demandeur ne l'a pas")
    local state = other.detail.state:GetText()
    H.ok(state:find("Accepté", 1, true) or state:find("attend", 1, true) or state:find("réserve", 1, true), state)
  end)

  H.test("Panneau Demandes : on décide, les classes acceptées s'affichent, le complet bloque", function()
    local vnet, vcl = H.Guild({ clients = {
      { name = "Shenryu", rankIndex = 1, class = "PALADIN" },
      { name = "Brumelune", rankIndex = 2, class = "MAGE" },
      { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
    } })
    local VA, VB, VP = vcl[1], vcl[2], vcl[3]
    local vev = assert(VA.DR.Calendar:SaveEvent({ t = "Raid de validation", k = "raid", d = vnet:ServerTime() + 2 * day,
      cap = 1, nt = 1, nh = 1, nd = 1, ap = true }))
    vnet:Advance(4)
    VB.DR.Calendar:SetSignup(vev.id, nil, "yes", "D")
    VP.DR.Calendar:SetSignup(vev.id, nil, "yes", "D")
    vnet:Advance(6)
    VA:Slash("sorties")
    local tab = VA.DR.UI.tabs.sorties
    tab.selected = vev.id
    tab.answerFor = nil
    tab:Refresh()
    H.eq(tab.detail.review.label:GetText():find("2", 1, true) ~= nil, true, "le bouton compte les demandes")
    tab:OpenReview()
    H.ok(tab.review:IsShown(), "le panneau s'ouvre")
    local function rowsText()
      local out = {}
      for _, r in ipairs(tab.review.list.items) do out[#out + 1] = r.text end
      return table.concat(out, "\n")
    end
    H.ok(rowsText():find("À décider (2)", 1, true), rowsText())
    local first
    for _, r in ipairs(tab.review.list.items) do if r.entry and not first then first = r end end
    tab:Decide(first, "a")
    vnet:Advance(6)
    H.ok(rowsText():find("Acceptés (1)", 1, true), "un accepté")
    H.ok(tab.review.classes:GetText():find("Classes acceptées", 1, true), tab.review.classes:GetText())
    -- 1 place seulement : le second ne peut plus être accepté.
    local second
    for _, r in ipairs(tab.review.list.items) do if r.entry and r.entry.state == "pending" then second = r end end
    H.ok(second.full, "le panneau marque « complet » : Accepter est grisé")
    local before = VA.DR.Store:Get("verdicts", vev.id .. "|" .. second.entry.s.c)
    tab:Decide(second, "a")
    H.eq(VA.DR.Store:Get("verdicts", vev.id .. "|" .. second.entry.s.c), before, "refusé par le calcul")
    tab:Decide(second, "w")
    vnet:Advance(6)
    H.ok(rowsText():find("En réserve (1)", 1, true), "mis en réserve")
    VB:Slash("sorties")
    H.eq(VB.DR.UI.tabs.sorties.review:IsShown(), false, "le panneau n'existe pas pour un demandeur")
  end)

  H.test("Pastille : les demandes à décider s'ajoutent aux sorties qui attendent ma réponse", function()
    local nreq = 0
    for _, j in ipairs(Cal.B:ToJudge()) do nreq = nreq + j.n end
    H.ok(nreq > 0, "Brumelune a des demandes")
    local n, text = B.DR.UI.tabs.sorties:Badge()
    H.ok(n >= nreq, "la pastille les compte")
    H.ok(text and text:find("à décider", 1, true), text)
  end)
end
