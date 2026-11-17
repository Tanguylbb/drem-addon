-- Composants d'interface au style des fenêtres du jeu : boutons rouge sombre et
-- ardoise, en-têtes de section dorés, barres à chiffre central, onglets d'icônes
-- sur le bord, fiche marine, listes défilantes, menus.

local _, DR = ...
local W = {}
DR.Widgets = W
local T = DR.Theme
local C = T.C

local BLACK = { 0, 0, 0 }
local function rgb(h) return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 } end

---------------------------------------------------------------------------
-- Infobulle simple
---------------------------------------------------------------------------
function W.Tip(frame, title, ...)
  local lines = { ... }
  frame:HookScript("OnEnter", function(self)
    local t = type(title) == "function" and title(self) or title
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(t, C.goldText[1], C.goldText[2], C.goldText[3])
    for _, l in ipairs(lines) do GameTooltip:AddLine(l, C.ivory[1], C.ivory[2], C.ivory[3], true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Boutons
---------------------------------------------------------------------------
-- style : red (l'action principale de l'écran), sec (secondaire), ghost (discret),
-- toggle (réponse : rouge quand choisie), chip (pastille de filtre : cerclée d'or
-- quand choisie), danger (supprimer). « gold » et « slate » sont d'anciens noms
-- de red et sec.
local ALIAS = { gold = "red", slate = "sec" }
local STYLES = {
  red = { size = 13 }, sec = { size = 13 }, ghost = { size = 12 },
  toggle = { size = 12 }, chip = { size = 12 }, danger = { size = 12 },
}

local function skin(b, top, bottom, inner, innerAlpha, text, shadow)
  T.Gradient(b.bg, top, bottom)
  T.Border(b, BLACK, 1)
  T.InnerBorder(b, inner, innerAlpha)
  T.Color(b.label, text)
  b.label:SetShadowColor(0, 0, 0, shadow or 0.9)
end

local RED_INNER = rgb("B5862F")

function W.StyleButton(b)
  local s = b.style
  if s == "red" then
    skin(b, C.redTop, C.redBottom, RED_INNER, 1, C.redText)
  elseif s == "toggle" then
    if b.active then
      skin(b, C.redTop, C.redBottom, RED_INNER, 1, C.redText)
    else
      skin(b, C.slateTop, C.slateBottom, C.line2, 1, C.slateText)
    end
  elseif s == "chip" then
    if b.active then
      skin(b, C.slateTop, C.slateBottom, C.gold, 1, C.goldPale)
    else
      skin(b, C.slateTop, C.slateBottom, C.line2, 1, C.slateText)
    end
  elseif s == "danger" then
    skin(b, C.slateTop, C.slateBottom, C.red, 0.6, C.red)
  else -- sec, ghost
    skin(b, C.slateTop, C.slateBottom, C.line2, 1, C.slateText)
  end
end

function W.Button(parent, text, style, width, height)
  local b = CreateFrame("Button", nil, parent)
  style = ALIAS[style or ""] or style or "ghost"
  b.style = style
  local st = STYLES[style] or STYLES.ghost
  b:SetSize(width or 120, height or 26)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  b.label = T.Text(b, "body", st.size)
  b.label:SetPoint("LEFT", 6, 0)
  b.label:SetPoint("RIGHT", -6, 0)
  b.label:SetJustifyH("CENTER")
  function b:SetLabel(t) self.label:SetText(t or "") end
  function b:SetActive(on)
    self.active = on and true or false
    W.StyleButton(self)
  end
  -- Change de style : l'action principale d'un écran devient discrète quand
  -- elle devient « retirer ».
  function b:SetStyle(newStyle)
    newStyle = ALIAS[newStyle or ""] or newStyle
    if self.style == newStyle then return end
    self.style = newStyle
    local def = STYLES[newStyle] or STYLES.ghost
    T.SetFont(self.label, "body", def.size)
    W.StyleButton(self)
  end
  b:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
  b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
  b:SetLabel(text)
  W.StyleButton(b)
  return b
end

-- Bouton icône carré (fermer, chercher...).
function W.IconButton(parent, icon, size, color, tip)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size or 24, size or 24)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("CENTER")
  b.icon:SetSize((size or 24) - 8, (size or 24) - 8)
  b.icon:SetTexture(T.Icon(icon))
  local c = color or C.brume
  b.icon:SetVertexColor(c[1], c[2], c[3])
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  if tip then W.Tip(b, tip) end
  return b
end

---------------------------------------------------------------------------
-- Onglets d'icônes sur le bord droit de la fenêtre
---------------------------------------------------------------------------
-- items : { key, icon (nom du fichier du dossier Media), label, tip }
function W.SideTabs(parent, items, onSelect)
  local col = CreateFrame("Frame", nil, parent)
  col:SetSize(54, 60)
  col:SetFrameLevel(parent:GetFrameLevel() + 8)
  col.buttons, col.items = {}, items
  for _, item in ipairs(items) do
    local b = CreateFrame("Button", nil, col)
    b.key = item.key
    b:SetSize(50, 50)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    T.Gradient(b.bg, rgb("2D241A"), rgb("0E0A07"))
    T.Border(b, BLACK, 1)
    T.InnerBorder(b, rgb("735833"), 1, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(32, 32)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(T.Icon(item.icon))
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)
    -- Halo doré de l'onglet choisi.
    b.glow = CreateFrame("Frame", nil, b)
    b.glow:SetPoint("TOPLEFT", -3, 3)
    b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    T.Border(b.glow, C.gold, 0.45, 3)
    b.glow:Hide()
    -- Pastille « il y a quelque chose à faire ».
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(18, 18)
    b.badge:SetPoint("TOPRIGHT", 5, 5)
    b.badge:SetFrameLevel(b:GetFrameLevel() + 5)
    b.badge.dot = b.badge:CreateTexture(nil, "ARTWORK")
    b.badge.dot:SetAllPoints()
    b.badge.dot:SetTexture(T.Icon("dot"))
    b.badge.dot:SetVertexColor(C.amber[1], C.amber[2], C.amber[3])
    b.badge.text = T.Text(b.badge, "bold", 10, C.goldInk, "OVERLAY")
    b.badge.text:SetPoint("CENTER", 0, 0)
    b.badge.text:SetShadowColor(0, 0, 0, 0)
    b.badge:Hide()
    b:SetScript("OnClick", function() col:Select(item.key, true) end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(item.label, C.goldText[1], C.goldText[2], C.goldText[3])
      if item.tip then GameTooltip:AddLine(item.tip, C.ivory[1], C.ivory[2], C.ivory[3], true) end
      if self.badgeTip then GameTooltip:AddLine(self.badgeTip, C.amber[1], C.amber[2], C.amber[3], true) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    col.buttons[item.key] = b
  end
  function col:Layout()
    local y = 0
    for _, item in ipairs(self.items) do
      local b = self.buttons[item.key]
      if item.hidden then
        b:Hide()
      else
        b:Show()
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
        y = y + 56
      end
    end
    self:SetHeight(math.max(60, y))
  end
  -- Allume l'onglet sans rien lancer (quand l'écran a déjà changé).
  function col:Mark(key)
    self.selected = key
    for k, b in pairs(self.buttons) do
      local on = (k == key)
      b.glow:SetShown(on)
      T.InnerBorder(b, on and C.gold or rgb("735833"), 1, 1)
    end
  end
  function col:Select(key, user)
    self:Mark(key)
    if onSelect then onSelect(key, user) end
  end
  function col:SetHidden(key, hidden)
    for _, item in ipairs(self.items) do
      if item.key == key then item.hidden = hidden end
    end
    self:Layout()
  end
  function col:SetBadge(key, n, tip)
    local b = self.buttons[key]
    if not b then return end
    b.badgeTip = tip
    if n and n > 0 then
      b.badge.text:SetText(n > 9 and "9+" or tostring(n))
      b.badge:Show()
    else
      b.badge:Hide()
    end
  end
  col:Layout()
  return col
end

---------------------------------------------------------------------------
-- Onglets en haut d'un écran (« Objectifs », « Journal de la banque »)
---------------------------------------------------------------------------
function W.TabStrip(parent, items, onSelect)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetSize(400, 30)
  bar.buttons, bar.items = {}, items
  local rule = bar:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(0.906, 0.804, 0.137, 1)
  rule:SetHeight(2)
  rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
  for _, item in ipairs(items) do
    local b = CreateFrame("Button", nil, bar)
    b.key = item.key
    b:SetHeight(26)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    T.Border(b, rgb("4A3A22"), 1)
    b.label = T.Text(b, "body", 12, C.brume)
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(item.label)
    b:SetScript("OnClick", function() bar:Select(item.key, true) end)
    bar.buttons[item.key] = b
  end
  function bar:Layout()
    local x = 0
    for _, item in ipairs(self.items) do
      local b = self.buttons[item.key]
      if item.hidden then
        b:Hide()
      else
        b:Show()
        local w = (b.label:GetStringWidth() or 60) + 34
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 2)
        x = x + w + 2
      end
    end
  end
  function bar:Select(key, user)
    self.selected = key
    for k, b in pairs(self.buttons) do
      local on = (k == key)
      b:SetHeight(on and 28 or 24)
      if on then
        T.Gradient(b.bg, rgb("34506F"), rgb("14233A"))
        T.Border(b, C.bronzeHi, 1)
        T.Color(b.label, rgb("FFF1C8"))
      else
        T.Gradient(b.bg, rgb("2B2217"), rgb("1A130B"))
        T.Border(b, rgb("4A3A22"), 1)
        T.Color(b.label, C.brume)
      end
    end
    if onSelect then onSelect(key, user) end
  end
  function bar:SetLabel(key, text)
    local b = self.buttons[key]
    if b then b.label:SetText(text) end
    self:Layout()
  end
  function bar:SetHidden(key, hidden)
    for _, item in ipairs(self.items) do
      if item.key == key then item.hidden = hidden end
    end
    self:Layout()
  end
  bar:Layout()
  return bar
end

-- Rangée de pastilles (« 7 jours », « 30 jours », « Tout »).
function W.Chips(parent, items, onSelect)
  local row = CreateFrame("Frame", nil, parent)
  -- Une largeur toujours définie : un cadre sans largeur n'affiche pas ses
  -- pastilles dans le client Forever (Layout la recalcule à chaque changement).
  row:SetSize(60, 24)
  row.buttons, row.items = {}, items
  for _, item in ipairs(items) do
    local b = W.Button(row, item.label, "chip", 80, 24)
    b:SetScript("OnClick", function() row:Select(item.key, true) end)
    row.buttons[item.key] = b
  end
  function row:Layout()
    local x = 0
    for _, item in ipairs(self.items) do
      local b = self.buttons[item.key]
      if item.hidden then b:Hide() else
        b:Show()
        local w = (b.label:GetStringWidth() or 60) + 26
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("LEFT", self, "LEFT", x, 0)
        x = x + w + 6
      end
    end
    self.width = x
    self:SetWidth(math.max(60, x - 6))
  end
  function row:Select(key, user)
    self.selected = key
    for k, b in pairs(self.buttons) do b:SetActive(k == key) end
    if onSelect then onSelect(key, user) end
  end
  function row:SetLabel(key, text)
    local b = self.buttons[key]
    if b then b:SetLabel(text) end
    self:Layout()
  end
  function row:SetHidden(key, hidden)
    for _, item in ipairs(self.items) do if item.key == key then item.hidden = hidden end end
    self:Layout()
  end
  row:Layout()
  return row
end

---------------------------------------------------------------------------
-- Champs de saisie
---------------------------------------------------------------------------
function W.Edit(parent, width, height, placeholder, maxLetters)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width or 160, height or 24)
  e:SetAutoFocus(false)
  T.SetFont(e, "body", 12)
  e:SetTextColor(C.ivory[1], C.ivory[2], C.ivory[3])
  e:SetTextInsets(8, 8, 0, 0)
  if maxLetters then e:SetMaxLetters(maxLetters) end
  e.bg = T.Fill(e, C.field)
  T.Border(e, C.line2)
  e.placeholder = T.Text(e, "body", 12, C.muted)
  e.placeholder:SetPoint("LEFT", 8, 0)
  e.placeholder:SetPoint("RIGHT", -8, 0)
  e.placeholder:SetText(placeholder or "")
  local function refresh(self)
    self.placeholder:SetShown(self:GetText() == "" and not self:HasFocus())
  end
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEditFocusGained", function(self)
    T.Border(self, C.gold)
    refresh(self)
  end)
  e:SetScript("OnEditFocusLost", function(self)
    T.Border(self, C.line2)
    refresh(self)
  end)
  e:HookScript("OnTextChanged", refresh)
  function e:SetPlaceholder(t) self.placeholder:SetText(t or "") end
  W.linkTargets[#W.linkTargets + 1] = e
  return e
end

-- Champ de recherche : la loupe et le texte gris, comme dans les fenêtres du jeu.
function W.Search(parent, width, placeholder, maxLetters)
  local e = W.Edit(parent, width, 24, placeholder, maxLetters)
  e:SetTextInsets(26, 8, 0, 0)
  e.placeholder:SetPoint("LEFT", 26, 0)
  local icon = e:CreateTexture(nil, "OVERLAY")
  icon:SetSize(13, 13)
  icon:SetPoint("LEFT", 8, 0)
  icon:SetTexture(T.Icon("search"))
  icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
  return e
end

-- Les champs qui acceptent un lien Maj+clic (objet, sort, recette).
W.linkTargets = {}
local function hookLinks()
  local insert = function(link)
    if not link then return end
    for _, e in ipairs(W.linkTargets) do
      if e:IsVisible() and e:HasFocus() and e.acceptLinks then
        e:Insert(link)
        return
      end
    end
  end
  if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", insert)
  elseif ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", insert)
  end
end
W.HookLinks = hookLinks

-- Grande zone de texte pour les codes du pont.
function W.CodeBox(parent, width, height)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width, height)
  holder.bg = T.Fill(holder, { 0, 0, 0 })
  T.Border(holder, C.line2)
  local sf = CreateFrame("ScrollFrame", nil, holder)
  sf:SetPoint("TOPLEFT", 8, -8)
  sf:SetPoint("BOTTOMRIGHT", -8, 8)
  local e = CreateFrame("EditBox", nil, sf)
  e:SetMultiLine(true)
  e:SetAutoFocus(false)
  e:SetMaxLetters(0)
  e:SetWidth(width - 16)
  e:SetHeight(height - 16)
  T.SetFont(e, "body", 10)
  e:SetTextColor(0.8, 0.77, 0.68)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  sf:SetScrollChild(e)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    local v = Clamp and Clamp(self:GetVerticalScroll() - delta * 30, 0, range)
      or math.max(0, math.min(range, self:GetVerticalScroll() - delta * 30))
    self:SetVerticalScroll(v)
  end)
  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function() e:SetFocus() end)
  e:SetScript("OnEditFocusGained", function() T.Border(holder, C.gold) end)
  e:SetScript("OnEditFocusLost", function() T.Border(holder, C.line2) end)
  holder.edit, holder.scroll = e, sf
  function holder:SetText(t)
    e:SetText(t or "")
    sf:SetVerticalScroll(0)
  end
  function holder:GetText() return e:GetText() end
  function holder:SelectAll()
    e:SetFocus()
    e:HighlightText()
  end
  return holder
end

---------------------------------------------------------------------------
-- Case à cocher
---------------------------------------------------------------------------
function W.Check(parent, label, onChange)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(20, 20)
  b.box = CreateFrame("Frame", nil, b)
  b.box:SetSize(16, 16)
  b.box:SetPoint("LEFT")
  T.Fill(b.box, rgb("14100C"))
  T.Border(b.box, rgb("9A7A3A"))
  b.tick = b.box:CreateTexture(nil, "ARTWORK")
  b.tick:SetSize(20, 20)
  b.tick:SetPoint("CENTER", 0, 0)
  b.tick:SetTexture(T.Icon("coche"))
  b.tick:SetVertexColor(C.goldText[1], C.goldText[2], C.goldText[3])
  b.label = T.Text(b, "body", 12, C.brume)
  b.label:SetPoint("LEFT", b.box, "RIGHT", 7, 0)
  b.label:SetText(label or "")
  function b:SetChecked(on)
    self.checked = on and true or false
    self.tick:SetShown(self.checked)
  end
  function b:Fit()
    self:SetWidth(24 + (self.label:GetStringWidth() or 100))
  end
  b:SetScript("OnClick", function(self)
    self:SetChecked(not self.checked)
    if onChange then onChange(self.checked) end
  end)
  b:SetChecked(false)
  b:Fit()
  return b
end

---------------------------------------------------------------------------
-- En-tête de section : barre brune à liseré doré, bouton « − » ou « + »
---------------------------------------------------------------------------
function W.Header(parent, width)
  local h = CreateFrame("Button", nil, parent)
  h:SetSize(width or 200, 24)
  h.bg = h:CreateTexture(nil, "BACKGROUND")
  h.bg:SetAllPoints()
  T.Gradient(h.bg, C.headTop, C.headBottom)
  T.Border(h, C.goldLine, 1)
  h.box = CreateFrame("Frame", nil, h)
  h.box:SetSize(15, 13)
  h.box:SetPoint("RIGHT", -7, 0)
  T.Fill(h.box, rgb("150C05"))
  T.Border(h.box, C.goldLine, 1)
  h.minus = h.box:CreateTexture(nil, "ARTWORK")
  h.minus:SetSize(9, 2)
  h.minus:SetPoint("CENTER")
  h.minus:SetColorTexture(C.goldText[1], C.goldText[2], C.goldText[3], 1)
  h.plus = h.box:CreateTexture(nil, "ARTWORK")
  h.plus:SetSize(2, 9)
  h.plus:SetPoint("CENTER")
  h.plus:SetColorTexture(C.goldText[1], C.goldText[2], C.goldText[3], 1)
  -- À droite, le nombre et la petite mention (« 3 sans artisan ») : un seul texte,
  -- à sa largeur. Le nom, à gauche, prend la place qui reste et se coupe par « … »
  -- au lieu de passer sur ses voisins.
  h.right = T.Text(h, "body", 11, C.muted)
  h.right:SetPoint("RIGHT", h.box, "LEFT", -8, 0)
  h.right:SetJustifyH("RIGHT")
  h.label = T.Text(h, "body", 14, C.goldText)
  h.label:SetPoint("LEFT", 10, 0)
  h.label:SetPoint("RIGHT", h.right, "LEFT", -10, 0)
  h.open = true
  h.plus:Hide()
  local function render(self)
    local count = self.countText and (T.Hex(rgb("A8956A")) .. self.countText .. "|r") or ""
    local extra = (self.extraText and self.extraText ~= "")
      and (T.Hex(self.extraColor or C.muted) .. self.extraText .. "|r") or ""
    self.right:SetText(count .. ((count ~= "" and extra ~= "") and "   " or "") .. extra)
  end
  function h:SetLabel(text, count)
    self.fullText = text or ""
    self.label:SetText(self.fullText)
    self.countText = count and ("(" .. count .. ")") or nil
    render(self)
  end
  function h:SetExtra(text, c)
    self.extraText, self.extraColor = text or "", c
    render(self)
  end
  function h:SetOpen(open)
    self.open = open and true or false
    self.plus:SetShown(not self.open)
  end
  h:SetScript("OnClick", function(self)
    if self.onToggle then self.onToggle(not self.open) end
  end)
  -- Nom coupé : l'infobulle le donne en entier.
  h:HookScript("OnEnter", function(self)
    local cut = self.label.IsTruncated and self.label:IsTruncated()
    if cut == nil then cut = self.label:GetStringWidth() > (self.label:GetWidth() or 0) end
    if not cut or (self.fullText or "") == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.fullText, C.goldText[1], C.goldText[2], C.goldText[3])
    GameTooltip:Show()
  end)
  h:HookScript("OnLeave", function() GameTooltip:Hide() end)
  return h
end

-- Icône dans un cadre bronze, comme les icônes des fenêtres du jeu.
function W.IconFrame(parent, size)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(size, size)
  box.bg = box:CreateTexture(nil, "BACKGROUND")
  box.bg:SetAllPoints()
  T.Gradient(box.bg, rgb("2D2418"), rgb("0C0907"))
  T.Border(box, BLACK, 1)
  T.InnerBorder(box, rgb("7D5F31"), 1, 1)
  box.icon = box:CreateTexture(nil, "ARTWORK")
  box.icon:SetPoint("TOPLEFT", 4, -4)
  box.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  box.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  function box:SetSelected(on)
    T.InnerBorder(self, on and C.gold or rgb("7D5F31"), 1, 1)
  end
  return box
end

---------------------------------------------------------------------------
-- Liste défilante (seules les lignes visibles existent)
---------------------------------------------------------------------------
-- opts : width, height, rowHeight, create(row), update(row, item, index),
--        click(item, row, button)
function W.List(parent, opts)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(opts.width, opts.height)
  f.opts, f.rows, f.items, f.offset = opts, {}, {}, 0
  local rh = opts.rowHeight or 24
  local visible = math.floor(opts.height / rh)
  f.visible = visible

  f.track = f:CreateTexture(nil, "ARTWORK")
  f.track:SetPoint("TOPRIGHT", -1, 0)
  f.track:SetPoint("BOTTOMRIGHT", -1, 0)
  f.track:SetWidth(6)
  f.track:SetColorTexture(0, 0, 0, 0.75)
  f.thumb = f:CreateTexture(nil, "OVERLAY")
  f.thumb:SetWidth(6)
  f.thumb:SetColorTexture(C.bronzeHi[1], C.bronzeHi[2], C.bronzeHi[3], 1)

  local function makeRow(i)
    local row = CreateFrame("Button", nil, f)
    row:SetHeight(rh)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * rh)
    row:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, 0.05)
    if opts.create then opts.create(row, i) end
    row:SetScript("OnClick", function(self, button)
      if self.item and opts.click then opts.click(self.item, self, button) end
    end)
    return row
  end
  for i = 1, visible do f.rows[i] = makeRow(i) end

  f.empty = T.Para(f, "body", 12, C.muted, opts.width - 24)
  f.empty:SetPoint("TOPLEFT", 12, -12)

  function f:Refresh()
    local n = #self.items
    local maxOffset = math.max(0, n - self.visible)
    if self.offset > maxOffset then self.offset = maxOffset end
    for i, row in ipairs(self.rows) do
      local item = i <= self.visible and self.items[self.offset + i] or nil
      row.item = item
      if item then
        row:Show()
        if opts.update then opts.update(row, item, self.offset + i) end
      else
        row:Hide()
      end
    end
    if n > self.visible then
      self.track:Show(); self.thumb:Show()
      local h = self:GetHeight()
      local th = math.max(20, h * self.visible / n)
      local y = (h - th) * (self.offset / maxOffset)
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", -1, -y)
    else
      self.track:Hide(); self.thumb:Hide()
    end
    self.empty:SetShown(n == 0 and self.emptyText ~= nil)
  end
  -- Change la hauteur de la liste (les lignes en plus se créent, les autres se cachent).
  function f:Resize(height)
    self:SetHeight(height)
    self.visible = math.max(1, math.floor(height / rh))
    for i = #self.rows + 1, self.visible do self.rows[i] = makeRow(i) end
    self:Refresh()
  end
  function f:SetItems(items, keepOffset)
    self.items = items or {}
    if not keepOffset then self.offset = 0 end
    self:Refresh()
  end
  function f:SetEmptyText(t)
    self.emptyText = t
    self.empty:SetText(t or "")
  end
  function f:ScrollTo(index)
    if index <= self.offset then self.offset = index - 1
    elseif index > self.offset + self.visible then self.offset = index - self.visible end
    self:Refresh()
  end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(self, delta)
    self.offset = math.max(0, self.offset - delta * 3)
    self:Refresh()
  end)
  return f
end

-- Liste noire encadrée, comme celles des fenêtres du jeu (recettes, journal).
function W.BlackList(parent, opts)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(opts.width, opts.height)
  T.Fill(box, C.sunk)
  T.Border(box, rgb("2B241A"))
  opts.width, opts.height = opts.width - 2, opts.height - 2
  local list = W.List(box, opts)
  list:SetPoint("TOPLEFT", 1, -1)
  box.list = list
  -- Même chose pour la boîte et la liste qu'elle contient.
  function box:Resize(height)
    self:SetHeight(height)
    list:Resize(height - 2)
  end
  return box, list
end

---------------------------------------------------------------------------
-- Menu déroulant
---------------------------------------------------------------------------
local menu, closer

local function buildMenu()
  closer = CreateFrame("Button", nil, UIParent)
  closer:SetAllPoints(UIParent)
  closer:SetFrameStrata("FULLSCREEN")
  closer:Hide()
  closer:SetScript("OnClick", function() W.CloseMenu() end)
  menu = CreateFrame("Frame", "DernierRempartMenu", UIParent)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetClampedToScreen(true)
  T.Fill(menu, C.sunk)
  T.Border(menu, C.bronzeHi, 1)
  menu.buttons = {}
  menu:Hide()
  table.insert(UISpecialFrames, "DernierRempartMenu")
  menu:SetScript("OnHide", function() closer:Hide() end)
end

function W.CloseMenu()
  if menu then menu:Hide() end
  if closer then closer:Hide() end
end

-- items : { text, func, checked, disabled, color }
function W.OpenMenu(anchor, items, width)
  if not menu then buildMenu() end
  width = width or 200
  local h = 6
  for i, item in ipairs(items) do
    local b = menu.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, menu)
      b:SetHeight(24)
      b.label = T.Text(b, "body", 12)
      b.label:SetPoint("LEFT", 22, 0)
      b.label:SetPoint("RIGHT", -8, 0)
      b.mark = b:CreateTexture(nil, "ARTWORK")
      b.mark:SetSize(6, 6)
      b.mark:SetPoint("LEFT", 9, 0)
      b.mark:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.1)
      menu.buttons[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 1, -h)
    b:SetPoint("TOPRIGHT", -1, -h)
    b.label:SetText(item.text)
    T.Color(b.label, item.color or C.ivory)
    b.mark:SetShown(item.checked and true or false)
    b:SetEnabled(not item.disabled)
    b:SetAlpha(item.disabled and 0.45 or 1)
    b:SetScript("OnClick", function()
      W.CloseMenu()
      if item.func then item.func() end
    end)
    b:Show()
    h = h + 24
  end
  for i = #items + 1, #menu.buttons do menu.buttons[i]:Hide() end
  menu:SetSize(width, h + 6)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  closer:Show()
  menu:Show()
end

---------------------------------------------------------------------------
-- Petites pièces
---------------------------------------------------------------------------
function W.Dot(parent, size, c)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size or 8, size or 8)
  t:SetTexture(T.Icon("dot"))
  if c then t:SetVertexColor(c[1], c[2], c[3]) end
  function t:SetColor(col) self:SetVertexColor(col[1], col[2], col[3]) end
  return t
end

-- Plaque de statut (texte coloré dans un cadre fin).
function W.Badge(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(40, 18)
  f.bg = T.Fill(f, C.sunk)
  f.label = T.Text(f, "body", 11)
  f.label:SetPoint("CENTER")
  function f:Set(text, c)
    self.label:SetText(text or "")
    T.Color(self.label, c or C.brume)
    T.Border(self, c or C.line2, 0.6)
    self:SetWidth((self.label:GetStringWidth() or 40) + 16)
  end
  return f
end

-- Pastille de compte : « Sorties à venir  3 ».
function W.Pill(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(120, 21)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  T.Gradient(f.bg, rgb("3A2D17"), rgb("1F160A"))
  T.Border(f, rgb("5C4A2A"), 1)
  f.label = T.Text(f, "body", 12, C.slateText)
  f.label:SetPoint("LEFT", 12, 0)
  f.value = T.Text(f, "body", 12, C.goldText)
  function f:Set(label, value)
    self.label:SetText(label or "")
    self.value:SetText(tostring(value or ""))
    local lw = self.label:GetStringWidth() or 60
    self.value:ClearAllPoints()
    self.value:SetPoint("LEFT", self.label, "LEFT", lw + 14, 0)
    self:SetWidth(12 + lw + 14 + (self.value:GetStringWidth() or 10) + 12)
  end
  return f
end

-- Barre à chiffre central, comme les barres des métiers et de la réputation :
-- fond noir, remplissage en dégradé du sombre au clair. Largeur donnée d'avance.
local FILL = {
  gold = { rgb("5A3A0C"), rgb("F6D55A") },
  red = { rgb("4A0A06"), rgb("F08A30") },
  green = { rgb("052D0A"), rgb("3BC15A") },
  blue = { rgb("0B1B3D"), rgb("7FB2FF") },
}
W.FILL = FILL

function W.Bar(parent, width, height)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, height or 18)
  f.barWidth = width
  f.bg = T.Fill(f, BLACK)
  T.Border(f, rgb("6A5535"))
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetPoint("TOPLEFT", 1, -1)
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.text = T.Text(f, "body", 11, { 1, 1, 1 }, "OVERLAY")
  f.text:SetPoint("CENTER", 0, 0)
  f.text:SetJustifyH("CENTER")
  function f:SetBarWidth(w)
    self.barWidth = w
    self:SetWidth(w)
  end
  -- ratio 0..1, kind : gold | red | green | blue, label : le chiffre au milieu
  function f:Set(ratio, kind, label)
    ratio = math.max(0, math.min(1, ratio or 0))
    local fill = FILL[kind or "gold"] or FILL.gold
    T.Gradient(self.fill, fill[1], fill[2], 1, true)
    self.fill:SetWidth(math.max(0.01, (self.barWidth - 2) * ratio))
    self.fill:SetShown(ratio > 0)
    self.text:SetText(label or "")
  end
  return f
end

-- Petit chiffre sur fond noir avec sa légende (« 12 » « en ligne »).
function W.Stat(parent, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 46)
  f.bg = T.Fill(f, C.sunk)
  T.Border(f, rgb("4C3D24"))
  f.num = T.Text(f, "title", 17, C.ivory)
  f.num:SetPoint("TOP", 0, -6)
  f.label = T.Text(f, "body", 11, C.muted)
  f.label:SetPoint("BOTTOM", 0, 6)
  function f:Set(n, label, color)
    self.num:SetText(n)
    T.Color(self.num, color or C.ivory)
    self.label:SetText(label)
  end
  return f
end

---------------------------------------------------------------------------
-- La fiche marine : l'étendard du Dernier Rempart dans la fenêtre du jeu
---------------------------------------------------------------------------
local function corner(f, c)
  local lines = {
    { 34, 1, 0, 0 }, { 1, 34, 0, 0 }, { 17, 1, 6, -6 }, { 1, 17, 6, -6 },
  }
  for _, l in ipairs(lines) do
    local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    t:SetColorTexture(c[1], c[2], c[3], 0.3)
    t:SetSize(l[1], l[2])
    t:SetPoint("TOPRIGHT", -8 - l[3], -8 + (-l[4]))
  end
end

-- corner : un petit ornement doré au coin haut droit, comme la fiche du Codex des
-- mascottes. À éviter quand des boutons occupent ce coin.
function W.Navy(parent, withCorner)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  T.Gradient(f.bg, C.navyTop, C.navyBottom)
  local mid = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  mid:SetPoint("TOPLEFT", 1, -1)
  mid:SetPoint("BOTTOMRIGHT", -1, 1)
  T.Gradient(mid, C.navyMid, C.navyBottom, 0.9)
  T.Border(f, BLACK, 1)
  T.InnerBorder(f, C.navyLine, 1, 1)
  f.mark = f:CreateTexture(nil, "BACKGROUND", nil, 3)
  f.mark:SetSize(math.floor(190 * T.LOGO_RATIO + 0.5), 190)
  f.mark:SetPoint("BOTTOMRIGHT", -26, 16)
  T.SetLogo(f.mark)
  f.mark:SetVertexColor(1, 1, 1, 0.09)
  if withCorner then corner(f, C.goldPale) end
  return f
end

-- Zone noire du journal : fond noir, filet brun.
function W.Inset(parent)
  local f = CreateFrame("Frame", nil, parent)
  T.Fill(f, BLACK)
  T.Border(f, rgb("4C3D24"))
  return f
end
