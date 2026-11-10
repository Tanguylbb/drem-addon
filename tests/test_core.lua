-- JSON, Base64, outils.
return function(H)
  local net = H.NewNetwork()
  local c = net:AddClient({ name = "Solo" })
  local DR = c.DR

  H.test("JSON : aller-retour avec accents et caractères spéciaux", function()
    local v = { t = "Repaire d’Onyxia", note = "ligne 1\nligne \"2\"\t\\ fin", n = 42, f = 0.25, ok = true,
      l = { 3, 1, 2 }, sub = { a = "é", b = {} } }
    local s = DR.Json.Encode(v)
    local back = assert(DR.Json.Decode(s))
    H.eq(back.t, v.t)
    H.eq(back.note, v.note)
    H.eq(back.n, 42)
    H.eq(back.f, 0.25)
    H.eq(back.ok, true)
    H.eq(#back.l, 3)
    H.eq(back.sub.a, "é")
  end)

  H.test("JSON : clés triées, encodage stable", function()
    H.eq(DR.Json.Encode({ b = 1, a = 2, c = { z = 1, y = 2 } }), '{"a":2,"b":1,"c":{"y":2,"z":1}}')
  end)

  H.test("JSON : champs privés « _ » ignorés sur demande", function()
    H.eq(DR.Json.Encode({ a = 1, _r = 5 }, true), '{"a":1}')
  end)

  H.test("JSON : lit les échappements \\u (y compris paires de substitution)", function()
    local v = assert(DR.Json.Decode('{"a":"\\u00e9t\\u00e9","b":"\\ud83d\\udee1"}'))
    H.eq(v.a, "été")
    H.eq(v.b, "\240\159\155\161")
  end)

  H.test("JSON : texte abîmé rejeté proprement", function()
    local v, err = DR.Json.Decode('{"a":[1,2')
    H.eq(v, nil)
    H.ok(err and err:find("JSON invalide"), "message d'erreur attendu")
    H.eq((DR.Json.Decode('{"a":1} trop')), nil)
  end)

  H.test("Base64 : vecteurs de la RFC 4648", function()
    local B = DR.Base64
    H.eq(B.Encode(""), "")
    H.eq(B.Encode("f"), "Zg==")
    H.eq(B.Encode("fo"), "Zm8=")
    H.eq(B.Encode("foo"), "Zm9v")
    H.eq(B.Encode("foob"), "Zm9vYg==")
    H.eq(B.Encode("fooba"), "Zm9vYmE=")
    H.eq(B.Encode("foobar"), "Zm9vYmFy")
    H.eq(B.Decode("Zm9vYmFy"), "foobar")
    H.eq(B.Decode("Zm9vYg=="), "foob")
    H.eq(B.Decode("Zm9v\nYmE="), "fooba")
    H.eq(B.Decode("Zm9v*"), nil)
  end)

  H.test("Base64 : tous les octets", function()
    local t = {}
    for i = 0, 255 do t[#t + 1] = string.char(i) end
    local s = table.concat(t)
    H.eq(DR.Base64.Decode(DR.Base64.Encode(s)), s)
  end)

  H.test("Dates : lecture JJ/MM et HH:MM", function()
    local U = DR.Util
    local t = U.ParseDateTime("10/12/2026", "21:00")
    local d = os.date("*t", t)
    H.eq(d.day, 10); H.eq(d.month, 12); H.eq(d.year, 2026); H.eq(d.hour, 21); H.eq(d.min, 0)
    H.ok(U.ParseDateTime("10/12/26", "21h30"), "année sur deux chiffres et 21h30")
    H.eq(U.ParseDateTime("31/02/2026", "21:00"), nil, "31 février refusé")
    H.eq(U.ParseDateTime("10/13/2026", "21:00"), nil, "mois 13 refusé")
    H.eq(U.ParseDateTime("10/12/2026", "25:00"), nil, "25 h refusé")
  end)

  H.test("Durées lisibles en français", function()
    local U = DR.Util
    H.eq(U.Duration(30), nil)
    H.eq(U.Duration(12 * 60), "12 min")
    H.eq(U.Duration(3 * 3600), "3 h")
    H.eq(U.Duration(2 * 86400 + 20 * 3600), "2 j 20 h")
    H.eq(U.Duration(10 * 86400), "10 j")
    H.eq(U.Ago(net:ServerTime() - 3 * 3600, net:ServerTime()), "il y a 3 h")
  end)

  H.test("Recherche sans accents ni majuscules", function()
    H.eq(DR.Util.Fold("Élixir de Défense"), "elixir de defense")
    H.eq(DR.Util.Fold("|cff1eff00Cœur|r"), "coeur")
  end)

  H.test("Noms : royaume ajouté puis retiré", function()
    H.eq(DR.Util.FullName("Shenryu"), "Shenryu-Rempart")
    H.eq(DR.Util.FullName("Shenryu-Autre"), "Shenryu-Autre")
    H.eq(DR.Util.ShortName("Shenryu-Rempart"), "Shenryu")
    H.eq(DR.Util.ShortName("Shenryu-Autre"), "Shenryu-Autre")
  end)

  H.test("Versions comparées nombre par nombre", function()
    H.eq(DR.Util.CompareVersions("0.10.0", "0.9.9"), 1)
    H.eq(DR.Util.CompareVersions("0.2.0", "0.2"), 0)
    H.eq(DR.Util.CompareVersions("1.0.0", "1.0.1"), -1)
  end)

  H.test("Message de chargement et commande /rempart", function()
    local found = false
    for _, m in ipairs(c.chat) do if m:find("/rempart", 1, true) then found = true end end
    H.ok(found, "le message de chargement cite /rempart")
    c:Slash("aide")
    H.ok(#c.chat > 3, "l'aide s'affiche")
  end)
end
