-- Découpage des messages, file d'attente, pause pendant les combats de boss.
return function(H)
  local net, cl = H.Guild()
  local A, B = cl[1], cl[2]
  local Comm = A.DR.Comm

  H.test("Un long texte accentué est découpé en morceaux de 255 octets, sans couper les accents", function()
    local text = string.rep("Été à la forge, ça brûle ! ", 60)
    local parts = Comm.Split(text)
    H.ok(#parts > 3, "plusieurs morceaux")
    local body = {}
    for _, p in ipairs(parts) do
      H.ok(#p <= 255, "morceau trop long : " .. #p)
      local chunk = p:sub(4)
      local first, last = chunk:byte(1), chunk:byte(#chunk)
      H.ok(not (first >= 0x80 and first < 0xC0), "un morceau commence au milieu d'un caractère")
      H.ok(last < 0xC0, "un morceau finit sur un début de caractère")
      body[#body + 1] = chunk
    end
    H.eq(table.concat(body), text)
  end)

  H.test("Recollage dans l'ordre", function()
    local text = string.rep("abcdefghij", 80)
    local store, out = {}, nil
    for _, p in ipairs(Comm.Split(text)) do out = Comm.Reassemble(store, "X", p) or out end
    H.eq(out, text)
    H.eq(Comm.Reassemble({}, "X", "Scourt"), "court")
  end)

  H.test("Un message part à la guilde et arrive chez l'autre", function()
    local got
    B.DR:Listen("COMM_MESSAGE", function(msg, sender) if msg.t == "ping" then got = { msg, sender } end end)
    Comm:Send({ t = "ping", x = string.rep("é", 400) }, "high")
    net:Advance(5)
    H.ok(got, "message reçu")
    H.eq(got[2], "Shenryu-Rempart")
    H.eq(#got[1].x, 800)
  end)

  H.test("Le débit est limité : pas plus de 8 messages d'avance par préfixe", function()
    local before = #A.sent
    for i = 1, 40 do Comm:Send({ t = "bruit", i = i }, "bulk") end
    net:Advance(0.2)
    local burst = #A.sent - before
    H.ok(burst <= 3 * 8, "rafale limitée (" .. burst .. ")")
    net:Advance(30)
    H.eq(Comm:Pending(), 0, "tout finit par partir")
  end)

  H.test("Pendant un combat de boss, rien ne part ; tout part après", function()
    A.lockdown = true
    local before = #A.sent
    Comm:Send({ t = "pendant" }, "high")
    net:Advance(5)
    H.eq(#A.sent, before, "rien n'est parti pendant le combat")
    H.eq(Comm:Pending(), 1)
    A.lockdown = false
    net:Advance(2)
    H.eq(Comm:Pending(), 0)
    H.ok(#A.sent > before, "parti après le combat")
  end)
end
