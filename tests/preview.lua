-- Dessine l'interface hors du jeu, pour la regarder avant de la mettre en ligne :
--   lua5.1 tests/preview.lua <dossier de sortie>
-- Ouvre chaque onglet d'un faux client avec des données de démonstration, calcule
-- la place de chaque cadre, texture et texte à partir des ancrages, et écrit un
-- fichier JSON par onglet. tests/preview/render.js en fait des images.
-- Ce n'est pas le rendu du jeu (polices, textures du jeu) : c'est un contrôle de
-- la mise en page (ce qui déborde, ce qui se chevauche, ce qui manque).

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/[^/]*$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path
local H = require("harness")
local OUT = arg[1] or "preview-out"
-- Deuxième argument « long » : mêmes écrans avec des noms, des titres et des
-- recettes aussi longs que dans une vraie guilde (c'est là que les textes se
-- marchent dessus).
local LONG = arg[2] == "long"
local function N(short, long) return LONG and long or short end
os.execute("mkdir -p '" .. OUT .. "'")

local CANVAS_W, CANVAS_H = 1000, 740

---------------------------------------------------------------------------
-- Données de démonstration
---------------------------------------------------------------------------
H.SPELLS[70001] = N("Sac en lin", "Sac renforcé en lin tissé des montagnes d'Alterac")
H.SPELLS[70002] = N("Sac en soie", "Sac de voyage en soie arachnéenne enchantée")
H.SPELLS[70003] = N("Sac en tisse-mage", "Sac sans fond en tisse-mage runique des anciens")
H.SPELLS[70004] = N("Robe de soie", "Robe d'érudit en soie lunaire brodée de fils d'argent")
H.SPELLS[70005] = N("Robe d'archimage", "Robe de grand archimage de la cité des Brumes")
H.SPELLS[70006] = N("Chemise blanche", "Chemise blanche de cérémonie du Dernier Rempart")
H.SPELLS[70007] = N("Chemise de soie", "Chemise de soie sauvage teinte à la main")
H.SPELLS[70008] = N("Coupe de lin", "Coupe de lin brut pour couturiers débutants")

local net = H.NewNetwork()
net.forever = true
net:SetRoster({
  { name = "Shenryu Valdor", rankIndex = 1, rankName = "Officier", class = "PALADIN" },
  { name = N("Zephira Fale", "Zéphirine Montmorency"), rankIndex = 2, class = "PRIEST" },
  { name = N("Brume Lune", "Bartholomeus Vandenberghe"), rankIndex = 2, class = "MAGE" },
  { name = N("Éowyn Varadien", "Éowyn Varadien-Lasalle"), rankIndex = 2, class = "DRUID" },
  { name = "Lustu", rankIndex = 2, class = "HUNTER" },
  { name = "PoPyTeK", rankIndex = 2, class = "ROGUE" },
  { name = "R4insid", rankIndex = 2, class = "WARRIOR" },
  { name = "Galdrin Roc", rankIndex = 2, class = "SHAMAN" },
  { name = "Pikvol", rankIndex = 2, class = "ROGUE" },
  { name = N("Alkand Lightstar", "Alkandrine Lightstarsong"), rankIndex = 2, class = "PRIEST", online = false },
})

local bank = {
  tabs = 1,
  money = {
    { "deposit", "Shenryu Valdor", 250000, 0, 0, 0, 3 },
    { "deposit", N("Brume Lune", "Bartholomeus Vandenberghe"), 120000, 0, 0, 1, 2 },
    { "deposit", N("Éowyn Varadien", "Éowyn Varadien-Lasalle"), 150000, 0, 0, 1, 1 },
    { "deposit", "R4insid", 100000, 0, 0, 4, 0 },
    { "deposit", "Lustu", 50000, 0, 0, 4, 0 },
    { "deposit", "PoPyTeK", 50000, 0, 0, 4, 1 },
    { "withdraw", "Shenryu Valdor", 50000, 0, 0, 1, 0 },
  },
  items = { [1] = {
    { "deposit", "Lustu", "|cff1eff00|Hitem:3451:0|h[Potion de soins majeure]|h|r", 8, 0, 0, 0, 4, 0, 1 },
  } },
}

local profs = function(rank) return { { name = "Couture", rank = rank, max = 150, id = 197 } } end
local clients = {}
local specs = {
  { name = "Shenryu Valdor", rankIndex = 1, class = "PALADIN", bank = bank, profs = profs(128), map = { m = 1453, x = 0.52, y = 0.61 } },
  { name = N("Zephira Fale", "Zéphirine Montmorency"), class = "PRIEST", profs = profs(150), map = { m = 1453, x = 0.30, y = 0.40 } },
  { name = N("Brume Lune", "Bartholomeus Vandenberghe"), class = "MAGE", profs = profs(90) },
  { name = N("Éowyn Varadien", "Éowyn Varadien-Lasalle"), class = "DRUID", profs = profs(60) },
  { name = "Lustu", class = "HUNTER" },
  { name = "PoPyTeK", class = "ROGUE" },
}
for _, spec in ipairs(specs) do
  spec.guild = "Dernier Rempart"
  clients[#clients + 1] = net:AddClient(spec)
end
net:Advance(25)
local A = clients[1]
A.DR.db.settings.debug = true

-- Recettes de couture : lues par trois membres, deux recettes que personne ne sait.
local ALL = { 70001, 70002, 70003, 70004, 70005, 70006, 70007, 70008 }
local TB, TR, TC, TK = N("Sacs", "Sacs et besaces de voyage de grande contenance"), N("Robes", "Robes d'érudit et tenues de cérémonie"),
  N("Chemises", "Chemises et tuniques de tous les jours"), N("Composants", "Composants et matériaux de couture avancée")
local TYPES = { [70001] = TB, [70002] = TB, [70003] = TB, [70004] = TR, [70005] = TR,
  [70006] = TC, [70007] = TC, [70008] = TK }
local function learn(client, ids)
  local set = {}
  for _, id in ipairs(ids) do set[id] = true end
  client.tradeskill = { id = 197, name = "Couture", all = ALL, learned = set, types = TYPES }
  client:Fire("TRADE_SKILL_SHOW")
end
learn(clients[1], { 70001, 70004 })
learn(clients[2], { 70001, 70002, 70004 })
learn(clients[3], { 70001 })
net:Advance(10)
-- Des +1 sur les recettes que personne ne sait.
local function entry(client, id)
  for _, e in ipairs(client.DR.Crafts:Entries(197)) do if e.id == id then return e end end
end
for i = 2, 6 do
  if entry(clients[i], 70003) then clients[i].DR.Crafts:ToggleWant(entry(clients[i], 70003)) end
  net:Advance(6)
end
for i = 3, 5 do
  if entry(clients[i], 70005) then clients[i].DR.Crafts:ToggleWant(entry(clients[i], 70005)) end
  net:Advance(6)
end
-- Une commande pour Shenryu.
local zephiraEntry = entry(clients[2], 70001)
if zephiraEntry then clients[2].DR.Crafts:RequestCraft(70001, "Shenryu Valdor", "Avec mon lin") end
net:Advance(5)

-- Sorties.
local now = net:ServerTime()
local function at(days, hour)
  local t = os.date("*t", now + days * 86400)
  t.hour, t.min, t.sec = hour, 0, 0
  return os.time(t)
end
local E = A.DR.Calendar
local evSoiree = E:SaveEvent({ t = N("Sac de couchage", "Soirée de guilde : défi des maîtres du donjon de Brassenoire"), k = "soiree", d = at(1, 21), dur = 120 })
local evDonjon = E:SaveEvent({ t = N("Profondeurs de Brassenoire", "Profondeurs de Brassenoire en mode héroïque avec les nouveaux"), k = "donjon", d = at(2, 20), dur = 150, cap = 5, nt = 1, nh = 1, nd = 3 })
local evRaid = E:SaveEvent({ t = N("Cœur du Magma", "Cœur du Magma : première nuit de progression en mode mythique"), k = "raid", d = at(4, 21), dur = 180, cap = 10, nt = 2, nh = 4, nd = 10,
  lead = "Shenryu Valdor", rdv = N("Entrée du repaire", "Devant l'entrée du repaire, côté pont de pierre"), note = "Potions de résistance au feu, nourriture" })
-- Un donjon créé par un membre, à cinq places : complet, avec une liste d'attente.
local evMembre = clients[2].DR.Calendar:SaveEvent({ t = N("Brassenoire entre amis", "Brassenoire en mode héroïque avec les nouveaux de la guilde"),
  k = "donjon", d = at(3, 20), dur = 120, cap = 3, nt = 1, nh = 1, nd = 1, rdv = "Devant l'entrée" })
net:Advance(5)
A.DR.Calendar:SetSignup(evSoiree.id, "Shenryu Valdor", "yes", "H")
A.DR.Calendar:SetSignup(evDonjon.id, "Shenryu Valdor", "yes", "H")
local roles = { "T", "H", "D", "D", "D" }
local answers = { "yes", "yes", "yes", "maybe", "yes" }
for i = 2, 6 do
  clients[i].DR.Calendar:SetSignup(evRaid.id, clients[i].DR.playerName, answers[i - 1], roles[i - 1])
end
net:Advance(8)
for i, role in ipairs({ "T", "H", "D", "D", "H" }) do
  clients[i + 1].DR.Calendar:SetSignup(evMembre.id, clients[i + 1].DR.playerName, "yes", role)
  net:Advance(2)
end
net:Advance(6)

-- Effort de guerre : l'or lu dans la banque, un objectif en objets, un objectif atteint.
A.DR.Effort:SaveGoal({ t = N("Coffre de guilde, onglet 2", "Coffre de guilde, onglet 2 : réserve pour les réparations de raid"), k = "or", amt = "200 po",
  from = os.date("%d/%m/%Y", now - 5 * 86400), to = os.date("%d/%m/%Y", now + 10 * 86400) })
A.DR.Effort:SaveGoal({ t = N("Potions de résistance au feu", "Potions de résistance au feu pour la progression du Cœur du Magma"), k = "objet", amt = "40", tag = N("Cœur du Magma", "Cœur du Magma, mode mythique"),
  item = "|Hitem:3451:0|h[Potion de soins majeure]|h", from = os.date("%d/%m/%Y", now - 3 * 86400),
  to = os.date("%d/%m/%Y", now + 4 * 86400) })
local done = A.DR.Effort:SaveGoal({ t = N("Tabards de guilde", "Tabards de guilde pour tous les nouveaux membres"), k = "or", amt = "150 po",
  from = os.date("%d/%m/%Y", now - 20 * 86400), to = os.date("%d/%m/%Y", now - 12 * 86400) })
net:Advance(4)
A:Fire("GUILDBANKFRAME_OPENED")
net:Advance(8)
if done then A.DR.Effort:Declare(done.id, "150 po", "") end
net:Advance(5)
A.DR.Effort.snap = nil

---------------------------------------------------------------------------
-- Calcul des rectangles
---------------------------------------------------------------------------
local ui = A.DR.UI
A.DR.db.settings.window = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 50, y = -40 }
ui:Build()
local parentRect = { 0, 0, CANVAS_W, CANVAS_H }

local children = {}
local function buildChildren()
  children = {}
  for _, o in ipairs(A.frames) do
    local p = o._parent
    if p then
      children[p] = children[p] or {}
      table.insert(children[p], o)
    end
  end
end

local cache = {}
local rectOf
local PRE_W = { FontString = true }

local function anchorX(r, point)
  if point:find("LEFT", 1, true) then return r[1] end
  if point:find("RIGHT", 1, true) then return r[1] + r[3] end
  return r[1] + r[3] / 2
end
local function anchorY(r, point)
  if point:find("TOP", 1, true) then return r[2] end
  if point:find("BOTTOM", 1, true) then return r[2] + r[4] end
  return r[2] + r[4] / 2
end

local function textWidth(o)
  local size = o._fsize or 12
  local plain = (o._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", "MM")
  return #plain * size * 0.60
end

rectOf = function(o)
  if cache[o] then return cache[o] end
  if o == A.env.UIParent then
    cache[o] = parentRect
    return parentRect
  end
  local parent = o._parent or A.env.UIParent
  local pr = rectOf(parent)
  local result
  if o._all then
    local r = rectOf(o._all)
    result = { r[1], r[2], r[3], r[4] }
  else
    local left, right, hc, top, bottom, vc
    for _, pt in ipairs(o._points or {}) do
      local rr = rectOf(pt.rel or parent)
      local x = anchorX(rr, pt.relPoint) + pt.x
      local y = anchorY(rr, pt.relPoint) - pt.y
      local p = pt.point
      if p:find("LEFT", 1, true) then left = x elseif p:find("RIGHT", 1, true) then right = x else hc = x end
      if p:find("TOP", 1, true) then top = y elseif p:find("BOTTOM", 1, true) then bottom = y else vc = y end
    end
    local w = o._w
    local h = o._h
    if PRE_W[o._type] and not o._wset then w = nil end
    if left and right then w = right - left end
    if top and bottom then h = bottom - top end
    if not w then w = textWidth(o) end
    if not h then h = (o._fsize or 12) + 4 end
    local l = left or (right and right - w) or (hc and hc - w / 2) or pr[1]
    local t = top or (bottom and bottom - h) or (vc and vc - h / 2) or pr[2]
    result = { l, t, w, h }
  end
  cache[o] = result
  return result
end

local LAYER = { BACKGROUND = 0, BORDER = 1, ARTWORK = 2, OVERLAY = 3, HIGHLIGHT = 4 }

local function color(c)
  if not c then return nil end
  return { c[1] or c.r, c[2] or c.g, c[3] or c.b, c[4] or c.a or 1 }
end

local json = A.DR.Json.Encode

local function dump(name)
  cache = {}
  buildChildren()
  local items, n = {}, 0
  local function visit(frame)
    if frame._type ~= "Frame" and frame._type ~= "Button" and frame._type ~= "EditBox" and frame._type ~= "ScrollFrame"
      and frame._type ~= "GameTooltip" then return end
    if not frame:IsVisible() then return end
    local fr = rectOf(frame)
    n = n + 1
    local fid = n
    items[#items + 1] = { k = "frame", id = fid, l = fr[1], t = fr[2], w = fr[3], h = fr[4], lv = frame:GetFrameLevel(), clip = frame._clip or nil }
    for _, c in ipairs(children[frame] or {}) do
      if c._type == "Texture" or c._type == "FontString" then
        if c._shown ~= false and frame:IsVisible() then
          local r = rectOf(c)
          local it = {
            k = c._type == "Texture" and "tex" or "text", f = fid, l = r[1], t = r[2], w = r[3], h = r[4],
            layer = LAYER[c._layer or "ARTWORK"] or 2, sub = c._sub or 0, order = #items,
          }
          if c._type == "Texture" then
            it.color = color(c._color)
            if c._grad then it.grad = { orient = c._grad.orient, from = color(c._grad.from), to = color(c._grad.to) } end
            if type(c._tex) == "string" then it.img = c._tex elseif c._tex then it.img = "#" .. tostring(c._tex) end
            it.vertex = color(c._vertex)
            it.tc = c._tc
            if c._layer == "HIGHLIGHT" then it.k = nil end
          else
            it.text = c._text or ""
            it.size = c._fsize or 12
            it.tc = color(c._tcolor) or { 1, 1, 1, 1 }
            it.just = c._justify or "LEFT"
            it.wrap = c._wrap and true or false
            it.autow = (not c._wset) and not (c._points and #c._points > 1 and false) or nil
            local hasLeft, hasRight
            for _, pt in ipairs(c._points or {}) do
              if pt.point:find("LEFT", 1, true) then hasLeft = true end
              if pt.point:find("RIGHT", 1, true) then hasRight = true end
            end
            it.autow = (not c._wset) and not (hasLeft and hasRight) or nil
            it.font = c._font or ""
            it.jv = c._justifyV or "MIDDLE"
            it.hset = c._hset or nil
          end
          if it.k then items[#items + 1] = it end
        end
      end
    end
    for _, c in ipairs(children[frame] or {}) do visit(c) end
  end
  visit(ui.frame)
  local f = assert(io.open(OUT .. "/" .. name .. ".json", "w"))
  f:write(json({ name = name, w = CANVAS_W, h = CANVAS_H, items = items }))
  f:close()
  print("écrit " .. OUT .. "/" .. name .. ".json (" .. #items .. " éléments)")
end

for _, tab in ipairs({ "sorties", "artisans", "carte", "effort", "officiers" }) do
  A:Slash(tab)
  net:Advance(3)
  dump(tab)
end

-- Quelques vues particulières.
A:Slash("banque")
net:Advance(3)
dump("effort-journal")

A:Slash("artisans")
net:Advance(2)
local arts = ui.tabs.artisans
arts.selectedRecipe = 70003
arts:RefreshRecipes()
dump("artisans-personne")
arts:SetView("buy")
dump("artisans-achat")
arts:SetView("orders")
dump("artisans-commandes")
arts:SetView("recipes")

A:Slash("sorties")
local sorties = ui.tabs.sorties
sorties.selected = evRaid.id
sorties.editing = true
sorties:Refresh()
dump("sorties-modifier")
sorties.editing = false
sorties:OpenForm(nil)
-- Le formulaire recouvre la fiche : on ne dessine pas ce qui est dessous.
sorties.detail:Hide()
dump("sorties-formulaire")
sorties.detail:Show()
sorties.form:Hide()

A:Slash("officiers")
ui.tabs.officiers.pasteOpen = true
ui.tabs.officiers:Refresh()
dump("officiers-secours")

-- Synchro en retard : la bande ambre.
A:Slash("sorties")
A.DR.Sync.lastReply = nil
A.DR.Sync.lastRequest = A.DR.Util.Now() - 3600
ui.tabs.sorties:Refresh()
dump("sorties-retard")

-- Une sortie de membre, complète : la barre des places et la liste d'attente.
A:Slash("sorties")
ui.tabs.sorties.selected = evMembre.id
ui.tabs.sorties.answerFor = nil
ui.tabs.sorties:Refresh()
dump("sorties-complet")

-- Un membre (pas officier) : pas d'onglet Officiers, pas de boutons d'officier.
A = clients[2]
ui = A.DR.UI
A.DR.db.settings.window = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 50, y = -40 }
ui:Build()
for _, tab in ipairs({ "sorties", "artisans", "carte", "effort" }) do
  A:Slash(tab)
  net:Advance(3)
  dump("membre-" .. tab)
end

-- Le membre voit « Nouvelle sortie » : le formulaire sans Raid, et sa propre sortie avec ses boutons.
A:Slash("sorties")
local ms = ui.tabs.sorties
ms.selected = evMembre.id
ms.answerFor = nil
ms:Refresh()
dump("membre-sorties-organisateur")
ms:OpenForm(nil)
ms.detail:Hide()
dump("membre-formulaire")
ms.detail:Show()
ms.form:Hide()

local errors = 0
for _, m in ipairs(A.chat) do
  if m:find("Erreur", 1, true) then
    errors = errors + 1
    if errors <= 8 then print(m) end
  end
end
print(errors .. " erreur(s) dans la discussion")
