-- Interface : construction de la fenêtre et parcours des onglets, sans erreur.
return function(H)
  local net, cl = H.Guild({ clients = {
    { name = "Shenryu", rankIndex = 1, map = { m = 1453, x = 0.5, y = 0.5 },
      profs = { { name = "Alchimie", rank = 300, max = 300, id = 171 }, { name = "Herboristerie", rank = 288, max = 300, id = 182 } } },
    { name = "Brumelune" },
  } })
  local A, B = cl[1], cl[2]
  local UI = A.DR.UI

  local function errors(client)
    local out = {}
    for _, m in ipairs(client.chat) do if m:find("Erreur", 1, true) then out[#out + 1] = m end end
    return out
  end

  A.DR.db.settings.debug = true
  B.DR.db.settings.debug = true

  H.test("La fenêtre s'ouvre sur les sorties", function()
    A:Slash("")
    H.ok(UI.frame and UI.frame:IsShown(), "fenêtre visible")
    H.eq(UI.current, "sorties")
    H.eq(#errors(A), 0, table.concat(errors(A), "\n"))
  end)

  H.test("L'officier crée une sortie avec le formulaire", function()
    local tab = UI.tabs.sorties
    tab.newBtn:Click()
    H.ok(tab.form:IsShown(), "formulaire ouvert")
    tab.form.t:SetText("Barrow Deeps")
    tab.form.kinds.raid:Click()
    tab.form.date:SetText(os.date("%d/%m/%Y", net:ServerTime() + 3 * 86400))
    tab.form.time:SetText("21:00")
    tab.form.needs.T:SetText("2")
    tab.form.needs.H:SetText("3")
    tab.form.needs.D:SetText("5")
    tab.form.save:Click()
    H.ok(not tab.form:IsShown(), "formulaire fermé : " .. tab.form.error:GetText())
    H.eq(#A.DR.Calendar:Upcoming(), 1)
    net:Advance(5)
    H.eq(#B.DR.Calendar:Upcoming(), 1, "partagée")
  end)

  H.test("Le membre répond en un clic depuis son onglet", function()
    B:Slash("sorties")
    local tab = B.DR.UI.tabs.sorties
    H.ok(tab.selected, "la sortie est choisie d'office")
    tab.detail.roleBtns.H:Click()
    tab.detail.answers.yes:Click()
    net:Advance(5)
    local s = A.DR.Calendar:Signups(tab.selected)[1]
    H.ok(s and s.s == "yes" and s.r == "H", "inscription Présent en soins")
    H.eq(#errors(B), 0, table.concat(errors(B), "\n"))
  end)

  H.test("Tous les onglets s'affichent sans erreur", function()
    A.tradeskill = { id = 171, name = "Alchimie", all = { 3451, 17556 }, learned = { [3451] = true } }
    A:Fire("TRADE_SKILL_SHOW")
    net:Advance(5)
    for _, key in ipairs({ "artisans", "carte", "effort", "persos", "pont", "sorties" }) do
      A:Slash(key)
      H.eq(UI.current, key)
    end
    net:Advance(3)
    H.eq(#errors(A), 0, table.concat(errors(A), "\n"))
  end)

  H.test("Artisans : chercher, choisir, demander", function()
    B:Slash("artisans")
    local tab = B.DR.UI.tabs.artisans
    tab.search:SetText("soins")
    tab:RefreshQui()
    H.eq(#tab.quiEntries, 1)
    tab.selectedRecipe = tab.quiEntries[1].id
    tab:RefreshQui()
    H.eq(tab.selectedCrafter, "Shenryu-Rempart")
    tab.quiDetail.ask:Click()
    net:Advance(5)
    H.eq(#A.DR.Crafts:Orders("craft", "forme"), 1)
    tab.chips:Select("recherches", true)
    tab.wishInput:SetText("Flacon des Titans")
    tab:AddWish()
    net:Advance(5)
    H.eq(#A.DR.Crafts:Orders("recette", "all"), 1)
    tab.chips:Select("commandes", true)
    H.eq(#errors(B), 0, table.concat(errors(B), "\n"))
  end)

  H.test("Pont : un membre ne voit pas l'onglet", function()
    B:Slash("pont")
    H.eq(B.DR.UI.current, "sorties")
  end)

  H.test("Pont : générer puis importer un code", function()
    A:Slash("pont")
    local tab = UI.tabs.pont
    tab:Generate()
    local code = tab.outBox:GetText()
    H.ok(code:sub(1, 4) == "DR2:", "code affiché")
    local now = net:ServerTime()
    local site = A.DR.Bridge.Encode({ v = 2, src = "site", at = now,
      events = { { id = "s1", t = "Onyxia", k = "raid", d = now + 86400, u = now - 10 } } })
    tab.inBox.edit:SetText(site)
    tab.check:Click()
    H.ok(tab.import:IsEnabled(), "Importer possible après vérification")
    tab.import:Click()
    H.ok(A.DR.Calendar:Get("s1"), "sortie du site importée")
    H.eq(#errors(A), 0, table.concat(errors(A), "\n"))
  end)

  H.test("Bouton de la minicarte : infobulle sans erreur", function()
    A.DR.MinimapButton:ShowTooltip(A.DR.MinimapButton.button)
    H.eq(#errors(A), 0, table.concat(errors(A), "\n"))
  end)

  H.test("Fermer puis rouvrir", function()
    A:Slash("")
    H.ok(not UI.frame:IsShown(), "fermée")
    A:Slash("")
    H.ok(UI.frame:IsShown(), "rouverte")
  end)
end
