-- Fabrique un vrai code DR2 avec l'add-on (pour le test croisé avec PHP).
package.path = "./tests/?.lua;" .. package.path
local H = require("harness")
-- Un dépôt de 25 po lu dans la banque par les deux officiers connectés.
local bank = { tabs = 1, money = { { "deposit", "Pikvol", 250000, 0, 0, 0, 3 } }, items = {} }
local net, cl = H.Guild({ server = os.time(), clients = {
  { name = "Shenryu", rankIndex = 1, class = "PALADIN", bank = bank },
  { name = "Brumelune", class = "MAGE", bank = bank },
} })
local A, B = cl[1], cl[2]
A.tradeskill = { id = 171, name = "Alchimie", all = { 3451, 17556 }, learned = { [3451] = true } }
A:Fire("TRADE_SKILL_SHOW")
local ev = A.DR.Calendar:SaveEvent({ t = "Repaire d’Onyxia", k = "raid", d = net:ServerTime() + 86400, nt = 4, nh = 10, nd = 26 })
net:Advance(5)
B.DR.Calendar:SetSignup(ev.id, nil, "yes", "H", "je ramène des fioles « bleues »")
B.DR.Crafts:Wish("|cff71d5ff|Hspell:17635:0|h[Flacon des Titans]|h|r", { id = 171, name = "Alchimie" })
net:Advance(10)
-- Effort de guerre : un objectif, la banque lue deux fois, un don déclaré.
local goal = assert(A.DR.Effort:SaveGoal({ t = "Coffre de guilde, onglet 2", k = "or", amt = "200 po",
  from = os.date("%d/%m/%Y", net:ServerTime() - 5 * 86400) }))
net:Advance(5)
A:Fire("GUILDBANKFRAME_OPENED")
B:Fire("GUILDBANKFRAME_OPENED")
net:Advance(8)
assert(B.DR.Effort:Declare(goal.id, "10 po", ""))
net:Advance(10)
local code = assert(A.DR.Bridge:Export(true))
io.write(code)
