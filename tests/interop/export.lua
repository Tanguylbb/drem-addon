-- Fabrique un vrai code DR2 avec l'add-on (pour le test croisé avec PHP).
package.path = "./tests/?.lua;" .. package.path
local H = require("harness")
local net, cl = H.Guild({ server = os.time() })
local A, B = cl[1], cl[2]
A.tradeskill = { id = 171, name = "Alchimie", all = { 3451, 17556 }, learned = { [3451] = true } }
A:Fire("TRADE_SKILL_SHOW")
local ev = A.DR.Calendar:SaveEvent({ t = "Repaire d’Onyxia", k = "raid", d = net:ServerTime() + 86400, nt = 4, nh = 10, nd = 26 })
net:Advance(5)
B.DR.Calendar:SetSignup(ev.id, nil, "yes", "H", "je ramène des fioles « bleues »")
B.DR.Crafts:Wish("|cff71d5ff|Hspell:17635:0|h[Flacon des Titans]|h|r", { id = 171, name = "Alchimie" })
net:Advance(10)
local code = assert(A.DR.Bridge:Export(true))
io.write(code)
