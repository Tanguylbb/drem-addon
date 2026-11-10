-- Relit dans l'add-on le code fabriqué par le site (PHP).
package.path = "./tests/?.lua;" .. package.path
local H = require("harness")
local net, cl = H.Guild({ server = os.time() })
local A, B = cl[1], cl[2]

-- Recrée la recette recherchée que le site va supprimer.
local wish = B.DR.Crafts:Wish("|Hspell:17635|h[Flacon des Titans]|h")
net:Advance(5)

local f = assert(io.open(arg[1]))
local code = f:read("*a")
f:close()
local payload = assert(A.DR.Bridge.Decode(code))
-- L'identifiant de la commande vient de l'export ; on l'aligne sur celle d'ici,
-- et la suppression est faite sur le site après la création en jeu.
payload.orders[1].id = wish.id
payload.orders[1].u = net:ServerTime() + 1

local preview = A.DR.Bridge:Preview(payload)
assert(preview.total == 3, "aperçu : 3 changements attendus, " .. preview.total .. " trouvés")
local counts = assert(A.DR.Bridge:Import(payload))
assert(counts.taken == 3, "3 lignes prises")
net:Advance(5)
local ev = assert(B.DR.Calendar:Get("s77"), "sortie du site arrivée chez Brumelune")
assert(ev.rdv == "Entrée du mont Hyjal", "accents intacts")
assert(B.DR.Calendar:Counts("s77").T == 1, "inscription du site comptée")
assert(B.DR.Store:Get("orders", wish.id) == nil, "suppression venue du site appliquée")
assert(B.DR.Bridge:Freshness() == "vert", "données du site fraîches")
io.write("Lua : code du site relu, appliqué et partagé\n")
