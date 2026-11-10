-- Charte « Nuit de Forever » du site Dernier Rempart (maquettes v2) :
-- fond Nuit, panneaux bleu nuit, texte Ivoire, titres dorés en Marcellus,
-- action principale en Or, secondaire en Ardoise, Sarcelle pour « c'est
-- plein », Ambre pour « il manque ». Texte courant en Open Sans.

local _, DR = ...
local T = {}
DR.Theme = T

local function hex(h)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, hex = h }
end

T.C = {
  night = hex("0A1220"),     -- le fond
  header = hex("09101E"),    -- barre du haut
  panel = hex("122038"),     -- les cartes
  sunk = hex("0C1628"),      -- champs, cases
  line = hex("25395B"),      -- bordure des cartes
  line2 = hex("33496F"),     -- bordure des champs et boutons
  rule = hex("1D2C47"),      -- filets
  ivory = hex("F3EEE2"),     -- le texte
  brume = hex("B9C2D0"),     -- texte secondaire
  muted = hex("9AA6BA"),     -- petites légendes
  gold = hex("E6C47C"),      -- l'action principale, la bordure dorée
  goldText = hex("F1D796"),  -- titres dorés
  goldPale = hex("F7E7B9"),  -- surtitres
  goldTop = hex("F7E2A8"),
  goldBottom = hex("C99A4E"),
  goldInk = hex("1D1408"),   -- texte sur bouton or
  slateTop = hex("27446E"),  -- ardoise : l'action secondaire
  slateBottom = hex("182C4A"),
  teal = hex("72D3C6"),      -- liens, « c'est plein »
  tealDark = hex("1F7D75"),  -- réponse choisie
  tealBorder = hex("2A9A90"),
  amber = hex("F4A95C"),     -- « il manque »
  amberSoft = hex("F6C58E"),
  blue = hex("86B6EE"),      -- donjons
  green = hex("66CC85"),     -- soirées
  red = hex("F07070"),
  sand = hex("2C2218"),
}

local FONTS = DR.MEDIA .. "Fonts\\"
T.FONTS = {
  title = FONTS .. "Marcellus-Regular.ttf",
  caps = FONTS .. "MarcellusSC-Regular.ttf",
  body = FONTS .. "OpenSans-Regular.ttf",
  semi = FONTS .. "OpenSans-SemiBold.ttf",
  bold = FONTS .. "OpenSans-Bold.ttf",
}
-- Polices du jeu si les nôtres ne se chargent pas.
local FALLBACK = {
  title = "Fonts\\MORPHEUS.TTF", caps = "Fonts\\MORPHEUS.TTF",
  body = "Fonts\\FRIZQT__.TTF", semi = "Fonts\\FRIZQT__.TTF", bold = "Fonts\\FRIZQT__.TTF",
}

function T.SetFont(fs, kind, size, flags)
  kind = kind or "body"
  local ok = pcall(fs.SetFont, fs, T.FONTS[kind] or T.FONTS.body, size or 12, flags or "")
  if not ok or not fs:GetFont() then
    pcall(fs.SetFont, fs, FALLBACK[kind] or STANDARD_TEXT_FONT, size or 12, flags or "")
  end
end

function T.Color(obj, c, alpha, method)
  method = method or "SetTextColor"
  obj[method](obj, c[1], c[2], c[3], alpha or 1)
end

-- Texte : kind = title | caps | body | semi | bold
function T.Text(parent, kind, size, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  T.SetFont(fs, kind, size)
  T.Color(fs, color or T.C.ivory)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("MIDDLE")
  fs:SetShadowColor(0, 0, 0, 0.55)
  fs:SetShadowOffset(1, -1)
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  return fs
end

-- Texte sur plusieurs lignes.
function T.Para(parent, kind, size, color, width)
  local fs = T.Text(parent, kind, size, color)
  fs:SetJustifyV("TOP")
  if fs.SetWordWrap then fs:SetWordWrap(true) end
  if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(true) end
  if width then fs:SetWidth(width) end
  if fs.SetSpacing then fs:SetSpacing(2) end
  return fs
end

function T.Fill(frame, c, alpha, layer, sub)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetAllPoints(frame)
  t:SetColorTexture(c[1], c[2], c[3], alpha or 1)
  return t
end

-- Dégradé vertical (haut -> bas).
function T.Gradient(tex, top, bottom, alpha)
  tex:SetColorTexture(1, 1, 1, 1)
  local a = alpha or 1
  if CreateColor and tex.SetGradient then
    local ok = pcall(tex.SetGradient, tex, "VERTICAL",
      CreateColor(bottom[1], bottom[2], bottom[3], a), CreateColor(top[1], top[2], top[3], a))
    if ok then return end
  end
  tex:SetColorTexture((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2, a)
end

-- Bordure d'un pixel.
function T.Border(frame, c, alpha, size)
  size = size or 1
  local b = frame.drBorder
  if not b then
    b = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
      b[side] = frame:CreateTexture(nil, "BORDER")
    end
    b.top:SetPoint("TOPLEFT"); b.top:SetPoint("TOPRIGHT")
    b.bottom:SetPoint("BOTTOMLEFT"); b.bottom:SetPoint("BOTTOMRIGHT")
    b.left:SetPoint("TOPLEFT"); b.left:SetPoint("BOTTOMLEFT")
    b.right:SetPoint("TOPRIGHT"); b.right:SetPoint("BOTTOMRIGHT")
    frame.drBorder = b
  end
  b.top:SetHeight(size); b.bottom:SetHeight(size)
  b.left:SetWidth(size); b.right:SetWidth(size)
  for _, t in pairs(b) do t:SetColorTexture(c[1], c[2], c[3], alpha or 1) end
  return b
end

function T.Line(parent, c, alpha, height)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(c[1], c[2], c[3], alpha or 1)
  t:SetHeight(height or 1)
  return t
end

-- Carte : panneau bleu nuit à bordure fine.
function T.Card(parent, c, borderColor)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = T.Fill(f, c or T.C.panel)
  T.Border(f, borderColor or T.C.line)
  return f
end

function T.Icon(name)
  return DR.MEDIA .. name
end

-- Icône intégrée au texte, teinte facultative.
function T.InlineIcon(name, size, c)
  size = size or 12
  local color = ""
  if c then
    color = string.format(":%d:%d:%d", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
  end
  return string.format("|T%s%s:%d:%d:0:0:32:32:0:32:0:32%s|t", DR.MEDIA, name, size, size, color)
end

T.ROLE_ICON = { T = "tank", H = "heal", D = "dps" }

function T.RoleIcon(role, size, c)
  local icon = T.ROLE_ICON[role or ""]
  if not icon then return "" end
  return T.InlineIcon(icon, size or 12, c or T.C.brume)
end

function T.Hex(c)
  if c.hex then return "|cff" .. c.hex end
  return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5))
end
