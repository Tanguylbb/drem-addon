-- JSON minimal et déterministe (clés triées) : sert aux messages entre add-ons
-- et aux codes échangés avec le site. Les chaînes restent en UTF-8 brut.

local _, DR = ...
local Json = {}
DR.Json = Json

local concat, format, byte, char, sub = table.concat, string.format, string.byte, string.char, string.sub
local floor, huge = math.floor, math.huge

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
  ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function escapeString(s)
  return '"' .. s:gsub('[%c"\\]', function(c)
    return ESCAPES[c] or format("\\u%04x", byte(c))
  end) .. '"'
end

local function isArray(t)
  local n = #t
  if n == 0 then return next(t) == nil end
  local count = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k > n or floor(k) ~= k then return false end
    count = count + 1
  end
  return count == n
end

local function encodeNumber(n)
  if n ~= n or n == huge or n == -huge then return "null" end
  if floor(n) == n and n > -1e15 and n < 1e15 then return format("%d", n) end
  return format("%.10g", n)
end

local encodeValue

local function encodeTable(t, out, skipPrivate)
  if isArray(t) then
    out[#out + 1] = "["
    for i = 1, #t do
      if i > 1 then out[#out + 1] = "," end
      encodeValue(t[i], out, skipPrivate)
    end
    out[#out + 1] = "]"
    return
  end
  local keys = {}
  for k, v in pairs(t) do
    local ks = tostring(k)
    if not (skipPrivate and sub(ks, 1, 1) == "_") and type(v) ~= "function" then
      keys[#keys + 1] = ks
    end
  end
  table.sort(keys)
  out[#out + 1] = "{"
  for i, ks in ipairs(keys) do
    if i > 1 then out[#out + 1] = "," end
    out[#out + 1] = escapeString(ks)
    out[#out + 1] = ":"
    local v = t[ks]
    if v == nil then v = t[tonumber(ks)] end
    encodeValue(v, out, skipPrivate)
  end
  out[#out + 1] = "}"
end

encodeValue = function(v, out, skipPrivate)
  local tv = type(v)
  if tv == "string" then
    out[#out + 1] = escapeString(v)
  elseif tv == "number" then
    out[#out + 1] = encodeNumber(v)
  elseif tv == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif tv == "table" then
    encodeTable(v, out, skipPrivate)
  else
    out[#out + 1] = "null"
  end
end

-- skipPrivate : ignore les clés qui commencent par "_" (données locales).
function Json.Encode(value, skipPrivate)
  local out = {}
  encodeValue(value, out, skipPrivate)
  return concat(out)
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------
local function codepointToUtf8(n)
  if n < 0x80 then return char(n) end
  if n < 0x800 then return char(0xC0 + floor(n / 0x40), 0x80 + n % 0x40) end
  if n < 0x10000 then
    return char(0xE0 + floor(n / 0x1000), 0x80 + floor(n / 0x40) % 0x40, 0x80 + n % 0x40)
  end
  return char(0xF0 + floor(n / 0x40000), 0x80 + floor(n / 0x1000) % 0x40,
    0x80 + floor(n / 0x40) % 0x40, 0x80 + n % 0x40)
end

local decodeValue

local function skip(s, i)
  local _, e = s:find("^[ \n\r\t]*", i)
  return e + 1
end

local function fail(i, what)
  error(format("JSON invalide à la position %d : %s", i, what), 0)
end

local function decodeString(s, i)
  local out, j = {}, i + 1
  while true do
    local c = sub(s, j, j)
    if c == "" then fail(j, "chaîne non terminée") end
    if c == '"' then return concat(out), j + 1 end
    if c == "\\" then
      local e = sub(s, j + 1, j + 1)
      if e == "u" then
        local hex = sub(s, j + 2, j + 5)
        local n = tonumber(hex, 16)
        if not n then fail(j, "\\u invalide") end
        j = j + 6
        if n >= 0xD800 and n <= 0xDBFF and sub(s, j, j + 1) == "\\u" then
          local lo = tonumber(sub(s, j + 2, j + 5), 16)
          if lo and lo >= 0xDC00 and lo <= 0xDFFF then
            n = 0x10000 + (n - 0xD800) * 0x400 + (lo - 0xDC00)
            j = j + 6
          end
        end
        out[#out + 1] = codepointToUtf8(n)
      else
        local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
        local r = map[e]
        if not r then fail(j, "échappement inconnu") end
        out[#out + 1] = r
        j = j + 2
      end
    else
      local k = s:find('["\\]', j)
      if not k then fail(j, "chaîne non terminée") end
      out[#out + 1] = sub(s, j, k - 1)
      j = k
    end
  end
end

local function decodeArray(s, i)
  local arr, n = {}, 0
  i = skip(s, i + 1)
  if sub(s, i, i) == "]" then return arr, i + 1 end
  while true do
    local v
    v, i = decodeValue(s, i)
    n = n + 1
    arr[n] = v
    i = skip(s, i)
    local c = sub(s, i, i)
    if c == "]" then return arr, i + 1 end
    if c ~= "," then fail(i, "',' ou ']' attendu") end
    i = skip(s, i + 1)
  end
end

local function decodeObject(s, i)
  local obj = {}
  i = skip(s, i + 1)
  if sub(s, i, i) == "}" then return obj, i + 1 end
  while true do
    if sub(s, i, i) ~= '"' then fail(i, "clé attendue") end
    local k
    k, i = decodeString(s, i)
    i = skip(s, i)
    if sub(s, i, i) ~= ":" then fail(i, "':' attendu") end
    i = skip(s, i + 1)
    local v
    v, i = decodeValue(s, i)
    obj[k] = v
    i = skip(s, i)
    local c = sub(s, i, i)
    if c == "}" then return obj, i + 1 end
    if c ~= "," then fail(i, "',' ou '}' attendu") end
    i = skip(s, i + 1)
  end
end

decodeValue = function(s, i)
  i = skip(s, i)
  local c = sub(s, i, i)
  if c == "{" then return decodeObject(s, i) end
  if c == "[" then return decodeArray(s, i) end
  if c == '"' then return decodeString(s, i) end
  if sub(s, i, i + 3) == "true" then return true, i + 4 end
  if sub(s, i, i + 4) == "false" then return false, i + 5 end
  if sub(s, i, i + 3) == "null" then return nil, i + 4 end
  local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
  if num and num ~= "" and num ~= "-" then
    local n = tonumber(num)
    if n then return n, i + #num end
  end
  fail(i, "valeur inattendue")
end

-- Rend la valeur, ou nil et un message d'erreur.
function Json.Decode(s)
  if type(s) ~= "string" then return nil, "pas une chaîne" end
  local ok, value, i = pcall(decodeValue, s, 1)
  if not ok then return nil, value end
  i = skip(s, i)
  if i <= #s then return nil, format("JSON invalide : texte en trop à la position %d", i) end
  return value
end
