-- Version 0.4 : navigation à icônes, pastilles, réponse d'abord, relancer, réglages
-- des officiers, fiche de l'effort de guerre. Ce que l'écran dessine est contrôlé à
-- part avec tests/preview.lua.
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
  A.DR.db.settings.debug = true
  B.DR.db.settings.debug = true
  net:Advance(8)
  local now = net:ServerTime()
  local ev1 = A.DR.Calendar:SaveEvent({ t = "Cœur du Magma", k = "raid", d = now + 3 * 86400, nt = 2, nh = 3, nd = 5 })
  local ev2 = A.DR.Calendar:SaveEvent({ t = "Soirée pêche", k = "soiree", d = now + 5 * 86400 })
  net:Advance(5)

  H.test("Les onglets sont des icônes à droite : cinq pour un officier, quatre pour un membre", function()
    A:Slash("sorties")
    B:Slash("sorties")
    local a, b = A.DR.UI.sideTabs, B.DR.UI.sideTabs
    H.ok(a.buttons.officiers:IsShown(), "l'officier voit l'accès Officiers")
    H.ok(not b.buttons.officiers:IsShown(), "le membre ne le voit pas")
    for _, key in ipairs({ "sorties", "artisans", "carte", "effort" }) do
      H.ok(b.buttons[key]:IsShown(), key)
    end
    H.eq(b.selected, "sorties")
    B:Slash("carte")
    H.eq(b.selected, "carte", "l'onglet choisi s'allume")
  end)

  H.test("Pastille de l'onglet Sorties : le nombre de sorties qui attendent ma réponse", function()
    B:Slash("sorties")
    B.DR.UI:RefreshBadges()
    local badge = B.DR.UI.sideTabs.buttons.sorties.badge
    H.ok(badge:IsShown(), "pastille visible")
    H.eq(badge.text:GetText(), "2")
    local tab = B.DR.UI.tabs.sorties
    tab.selected = ev1.id
    tab:Refresh()
    tab.detail.answers.yes:Click()
    net:Advance(3)
    B.DR.UI:RefreshBadges()
    H.eq(badge.text:GetText(), "1", "une réponse de moins")
  end)

  H.test("Sorties : « Présent » est le bouton rouge tant qu'on n'a pas répondu, et la recherche filtre", function()
    local tab = B.DR.UI.tabs.sorties
    tab.selected = ev2.id
    tab.answerFor = nil
    tab:Refresh()
    H.ok(tab.detail.answers.yes.active, "Présent rouge avant la réponse")
    H.ok(not tab.detail.answers.no.active)
    tab.detail.answers.no:Click()
    net:Advance(3)
    H.ok(tab.detail.answers.no.active and not tab.detail.answers.yes.active, "la réponse choisie devient rouge")
    tab.searchBox:SetText("zzz")
    H.eq(#tab.list.items, 0, "rien ne correspond")
    tab.searchBox:SetText("magma")
    H.eq(#tab.list.items, 1, "recherche sans accent ni majuscule")
    tab.searchBox:SetText("")
    H.eq(#tab.list.items, 2)
  end)

  H.test("Sorties : le rôle choisi dans la réponse devient celui proposé ensuite", function()
    local tab = B.DR.UI.tabs.sorties
    tab.selected = ev1.id
    tab.answerFor = nil
    tab:Refresh()
    tab.detail.change:Click()
    H.ok(tab.editing, "« Modifier » ouvre le choix du perso et du rôle")
    tab.detail.roleBtns.T:Click()
    tab.detail.answers.maybe:Click()
    net:Advance(3)
    H.eq(B.DR.Profile:PreferredRole(B.DR.playerName), "T")
    H.ok(not tab.editing, "le choix se referme après la réponse")
  end)

  H.test("Relancer : l'officier voit qui n'a pas répondu, sans erreur", function()
    local tab = A.DR.UI.tabs.sorties
    A:Slash("sorties")
    tab.selected = ev1.id
    tab:Refresh()
    H.ok(tab.detail.seen:IsShown(), "la ligne des officiers est là")
    local seen = A.DR.Calendar:SeenBy(ev1.id)
    H.ok(#seen.pendingNames >= 1, "au moins un membre n'a pas répondu")
    tab:RemindMenu(tab.detail.remind)
    H.eq(chatHas(A, "Erreur"), false)
  end)

  H.test("Pied de page : un point de couleur dit où en est la synchro", function()
    A.DR.UI:RefreshHeader()
    H.ok(A.DR.UI.freshText:GetText() ~= "", A.DR.UI.freshText:GetText())
    local lines = A.DR.UI:FooterLines()
    H.ok(#lines >= 3, "le détail est dans l'infobulle")
  end)

  H.test("Officiers : lecture de la banque, qui voit les montants, seuil", function()
    A:Slash("officiers")
    local tab = A.DR.UI.tabs.officiers
    tab:Refresh()
    local before = A.DR.db.settings.readBank
    tab.readBtn:Click()
    H.ok(A.DR.db.settings.readBank ~= before, "le réglage change")
    tab.readBtn:Click()
    tab.visChips:Select("officers", true)
    H.eq(A.DR.Effort:Visibility(), "officers")
    tab.visChips:Select("all", true)
    H.eq(A.DR.Effort:Visibility(), "all")
    tab.pasteHeader:Click()
    H.ok(tab.pasteOpen, "le copier-coller se déplie")
    H.eq(chatHas(A, "Erreur"), false)
  end)

  H.test("Un membre n'arrive pas sur l'écran Officiers", function()
    B:Slash("officiers")
    H.eq(B.DR.UI.current, "sorties")
  end)

  H.test("Effort de guerre : la fiche de l'objectif choisi, ma part, mes dons seulement", function()
    local goal = assert(A.DR.Effort:SaveGoal({ t = "Coffre de guilde", k = "or", amt = "200 po",
      to = os.date("%d/%m/%Y", now + 10 * 86400) }))
    A.DR.Effort:SaveGoal({ t = "Tabards", k = "or", amt = "100 po", from = os.date("%d/%m/%Y", now - 40 * 86400),
      to = os.date("%d/%m/%Y", now - 30 * 86400) })
    net:Advance(5)
    A.DR.Effort:Declare(goal.id, "20 po", "")
    net:Advance(3)
    A:Slash("effort")
    local tab = A.DR.UI.tabs.effort
    tab.selected = nil
    tab:Refresh()
    H.ok(tab.selected, "un objectif est choisi d'office")
    H.ok(tab.fiche.body:IsShown())
    H.ok(tab.fiche.title:GetText():find("Coffre", 1, true) or tab.fiche.title:GetText():find("Tabards", 1, true))
    tab.selected = goal.id
    tab:Refresh()
    H.ok(tab.fiche.mine:GetText():find("20 po", 1, true), tab.fiche.mine:GetText())
    H.ok(#tab.fiche.moves.items >= 1, "mon don est listé")
    tab.fiche.onlyMine:Click()
    H.ok(tab.onlyMine, "Seulement mes dons")
    tab.fiche.onlyMine:Click()
    H.ok(not tab.onlyMine)
    H.eq(chatHas(A, "Erreur"), false)
  end)

  H.test("/rempart fiche relit la fiche", function()
    A:Slash("fiche")
    H.ok(chatHas(A, "fiche relue"))
  end)

  H.test("Carte : une phrase, et la liste ne montre que ceux qu'on ne voit pas", function()
    A:Slash("carte")
    local tab = A.DR.UI.tabs.carte
    tab:Refresh()
    H.ok(tab.phrase:GetText():find("en ligne", 1, true), tab.phrase:GetText())
    H.ok(tab.phrase:GetText():find("sur la carte", 1, true))
    H.eq(chatHas(A, "Erreur"), false)
  end)

  H.test("Pikvol (sans écran ouvert) ne produit aucune erreur", function()
    H.eq(chatHas(P, "Erreur"), false)
  end)
end
