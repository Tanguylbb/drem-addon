-- Style « fidèle au jeu » (maquettes 0.5 révisées) : cuir brun très sombre,
-- cadre bronze, noms et en-têtes dorés, listes noires, action principale en
-- rouge sombre (comme « Créer » ou « Invoquer »). Le Dernier Rempart y tient
-- en trois choses : la tour du médaillon, le panneau marine des fiches et le
-- nom en Marcellus dans la barre de titre. Texte courant : la police du jeu.

local _, DR = ...
local T = {}
DR.Theme = T

local function hex(h)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, hex = h }
end

T.C = {
  -- Cuir et pierre : relevés sur les fenêtres du jeu.
  night = hex("13100C"),     -- le fond de la fenêtre
  header = hex("1D1008"),    -- la barre de titre
  panel = hex("1A1711"),     -- les blocs
  sunk = hex("0C0C0C"),      -- listes et journaux : noir
  field = hex("090806"),     -- champs de saisie
  line = hex("3A2D1A"),      -- bordure discrète
  line2 = hex("6F5C3A"),     -- bordure bronze des champs et boutons
  rule = hex("1A1610"),      -- filets entre les lignes
  bronze = hex("5B4022"),    -- le cadre de la fenêtre
  bronzeHi = hex("9A7A42"),  -- son filet clair
  -- Textes
  ivory = hex("EAE3D0"),     -- le texte
  brume = hex("C9BFA6"),     -- texte secondaire
  muted = hex("9A9180"),     -- petites légendes
  gold = hex("F0D12A"),      -- cercle d'une ligne ou d'un onglet choisi
  goldText = hex("F6D55A"),  -- noms et en-têtes dorés
  goldPale = hex("FDE27C"),  -- le titre de la fenêtre
  goldLine = hex("946F2C"),  -- liseré des en-têtes de section
  goldInk = hex("1D1408"),
  -- Couleurs de statut (les mêmes que dans les barres)
  green = hex("4EC27A"),     -- plein, présent, atteint
  amber = hex("F4A95C"),     -- il manque, à faire
  red = hex("E8553E"),       -- en retard, absent
  blue = hex("86B6EE"),      -- remplaçant, donjons
  cyan = hex("4FC3C3"),      -- durées du journal
  -- Boutons
  redTop = hex("8A210A"),
  redBottom = hex("580904"),
  redText = hex("F2CC4C"),
  slateTop = hex("37322C"),
  slateBottom = hex("1E1B17"),
  slateText = hex("E3D8B8"),
  -- Le panneau marine des fiches (l'étendard du Dernier Rempart)
  navyTop = hex("1F3869"),
  navyMid = hex("122549"),
  navyBottom = hex("0A152B"),
  navyLine = hex("2C4A7E"),
  -- En-tête de section
  headTop = hex("3B2711"),
  headBottom = hex("25160A"),
}
local C = T.C

local FONTS = DR.MEDIA .. "Fonts\\"
local GAME = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
T.FONTS = {
  brand = FONTS .. "Marcellus-Regular.ttf",
  title = GAME, caps = GAME, body = GAME, semi = GAME, bold = GAME,
}
-- Police du jeu si la nôtre ne se charge pas.
local FALLBACK = "Fonts\\FRIZQT__.TTF"

function T.SetFont(fs, kind, size, flags)
  kind = kind or "body"
  local ok = pcall(fs.SetFont, fs, T.FONTS[kind] or T.FONTS.body, size or 12, flags or "")
  if not ok or not fs:GetFont() then
    pcall(fs.SetFont, fs, FALLBACK, size or 12, flags or "")
  end
end

function T.Color(obj, c, alpha, method)
  method = method or "SetTextColor"
  obj[method](obj, c[1], c[2], c[3], alpha or 1)
end

-- Texte : kind = brand | title | caps | body | semi | bold (tout est la police du jeu,
-- sauf « brand » : le nom du Dernier Rempart en Marcellus).
function T.Text(parent, kind, size, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  T.SetFont(fs, kind, size)
  T.Color(fs, color or C.ivory)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("MIDDLE")
  fs:SetShadowColor(0, 0, 0, 0.9)
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

-- Dégradé : vertical (haut -> bas) ou horizontal (gauche -> droite).
function T.Gradient(tex, from, to, alpha, horizontal)
  tex:SetColorTexture(1, 1, 1, 1)
  local a = alpha or 1
  if CreateColor and tex.SetGradient then
    local ok
    if horizontal then
      ok = pcall(tex.SetGradient, tex, "HORIZONTAL",
        CreateColor(from[1], from[2], from[3], a), CreateColor(to[1], to[2], to[3], a))
    else
      ok = pcall(tex.SetGradient, tex, "VERTICAL",
        CreateColor(to[1], to[2], to[3], a), CreateColor(from[1], from[2], from[3], a))
    end
    if ok then return end
  end
  tex:SetColorTexture((from[1] + to[1]) / 2, (from[2] + to[2]) / 2, (from[3] + to[3]) / 2, a)
end

-- Bordure d'un pixel (ou plus).
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

-- Filet intérieur : une deuxième bordure, rentrée d'un pixel (le liseré clair
-- des boutons et du cadre).
function T.InnerBorder(frame, c, alpha, inset)
  local f = frame.drInner
  if not f then
    f = CreateFrame("Frame", nil, frame)
    f:SetFrameLevel(frame:GetFrameLevel() + 1)
    f:EnableMouse(false)
    frame.drInner = f
  end
  inset = inset or 1
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", inset, -inset)
  f:SetPoint("BOTTOMRIGHT", -inset, inset)
  T.Border(f, c, alpha)
  return f
end

function T.Line(parent, c, alpha, height)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(c[1], c[2], c[3], alpha or 1)
  t:SetHeight(height or 1)
  return t
end

-- Carte : bloc de cuir à bordure fine.
function T.Card(parent, c, borderColor)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = T.Fill(f, c or C.panel)
  T.Border(f, borderColor or C.line)
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
  return T.InlineIcon(icon, size or 12, c or C.brume)
end

function T.Hex(c)
  if c.hex then return "|cff" .. c.hex end
  return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5))
end

-- Icônes de métier : celles du jeu, par identifiant de métier.
T.PROF_ICON = {
  [171] = "Interface\\Icons\\Trade_Alchemy",
  [164] = "Interface\\Icons\\Trade_BlackSmithing",
  [333] = "Interface\\Icons\\Trade_Engraving",
  [202] = "Interface\\Icons\\Trade_Engineering",
  [165] = "Interface\\Icons\\Trade_LeatherWorking",
  [197] = "Interface\\Icons\\Trade_Tailoring",
  [185] = "Interface\\Icons\\INV_Misc_Food_15",
  [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
  [356] = "Interface\\Icons\\Trade_Fishing",
  [182] = "Interface\\Icons\\Trade_Herbalism",
  [186] = "Interface\\Icons\\Trade_Mining",
  [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  [755] = "Interface\\Icons\\INV_Misc_Gem_01",
  [773] = "Interface\\Icons\\INV_Inscription_Tradeskill01",
}
T.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

function T.ProfIcon(id)
  return T.PROF_ICON[id] or T.UNKNOWN_ICON
end

-- Icônes des types de sortie.
T.KIND_ICON = {
  raid = "Interface\\Icons\\Spell_Fire_Flamebolt",
  donjon = "Interface\\Icons\\INV_Misc_Key_03",
  soiree = "Interface\\Icons\\INV_Drink_05",
  autre = "Interface\\Icons\\INV_Misc_Note_01",
}
