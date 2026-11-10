-- Base64 standard (RFC 4648, avec remplissage "="), lisible par PHP base64_decode.

local _, DR = ...
local Base64 = {}
DR.Base64 = Base64

local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local floor, byte, char, sub, concat = math.floor, string.byte, string.char, string.sub, table.concat

local ENC, DEC = {}, {}
for i = 1, 64 do
  local c = sub(ALPHA, i, i)
  ENC[i - 1] = c
  DEC[byte(c)] = i - 1
end
-- Variante "URL" acceptée à la lecture.
DEC[byte("-")] = 62
DEC[byte("_")] = 63

function Base64.Encode(s)
  local out, n = {}, #s
  for i = 1, n - 2, 3 do
    local a, b, c = byte(s, i, i + 2)
    local v = a * 65536 + b * 256 + c
    out[#out + 1] = ENC[floor(v / 262144)] .. ENC[floor(v / 4096) % 64] .. ENC[floor(v / 64) % 64] .. ENC[v % 64]
  end
  local rest = n % 3
  if rest == 1 then
    local a = byte(s, n)
    local v = a * 65536
    out[#out + 1] = ENC[floor(v / 262144)] .. ENC[floor(v / 4096) % 64] .. "=="
  elseif rest == 2 then
    local a, b = byte(s, n - 1, n)
    local v = a * 65536 + b * 256
    out[#out + 1] = ENC[floor(v / 262144)] .. ENC[floor(v / 4096) % 64] .. ENC[floor(v / 64) % 64] .. "="
  end
  return concat(out)
end

-- Rend la chaîne décodée, ou nil si un caractère n'est pas du Base64.
function Base64.Decode(s)
  s = s:gsub("[%s=]", "")
  local out, bits, value = {}, 0, 0
  for i = 1, #s do
    local d = DEC[byte(s, i)]
    if not d then return nil end
    value = value * 64 + d
    bits = bits + 6
    if bits >= 8 then
      bits = bits - 8
      local p = 2 ^ bits
      out[#out + 1] = char(floor(value / p))
      value = value % p
    end
  end
  return concat(out)
end
