-- Composants d'interface au style du site : boutons Or et Ardoise, réponses
-- en sarcelle, onglets soulignés, pastilles, champs, listes défilantes, menus.

local _, DR = ...
local W = {}
DR.Widgets = W
local T = DR.Theme
local C = T.C

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
-- style : gold (action principale), slate (secondaire), ghost (discret),
-- toggle (réponse, sarcelle quand choisie), chip (pastille de filtre),
-- danger (supprimer).
local STYLES = {
  gold = { font = "title", size = 15 },
  slate = { font = "title", size = 15 },
  ghost = { font = "semi", size = 12 },
  toggle = { font = "semi", size = 12 },
  chip = { font = "semi", size = 12 },
  danger = { font = "semi", size = 12 },
}

function W.StyleButton(b)
  local s = b.style
  local active = b.active
  local tex, label = b.bg, b.label
  if s == "gold" then
    T.Gradient(tex, C.goldTop, C.goldBottom)
    T.Border(b, { 1, 0.94, 0.78 }, 0.55)
    T.Color(label, C.goldInk)
    label:SetShadowColor(1, 1, 1, 0.25)
  elseif s == "slate" then
    T.Gradient(tex, C.slateTop, C.slateBottom)
    T.Border(b, { 1, 1, 1 }, 0.18)
    T.Color(label, C.ivory)
  elseif s == "toggle" then
    if active then
      tex:SetColorTexture(C.tealDark[1], C.tealDark[2], C.tealDark[3], 1)
      T.Border(b, C.tealBorder)
      label:SetTextColor(1, 1, 1)
    else
      tex:SetColorTexture(C.sunk[1], C.sunk[2], C.sunk[3], 1)
      T.Border(b, C.line2)
      label:SetTextColor(0.89, 0.9, 0.925)
    end
  elseif s == "chip" then
    if active then
      tex:SetColorTexture(C.goldText[1], C.goldText[2], C.goldText[3], 1)
      T.Border(b, C.goldText)
      T.Color(label, C.goldInk)
      label:SetShadowColor(0, 0, 0, 0)
    else
      tex:SetColorTexture(C.sunk[1], C.sunk[2], C.sunk[3], 1)
      T.Border(b, C.line2)
      label:SetTextColor(0.85, 0.87, 0.9)
      label:SetShadowColor(0, 0, 0, 0.55)
    end
  elseif s == "danger" then
    tex:SetColorTexture(C.sunk[1], C.sunk[2], C.sunk[3], 1)
    T.Border(b, C.red, 0.6)
    T.Color(label, C.red)
  else -- ghost
    tex:SetColorTexture(C.sunk[1], C.sunk[2], C.sunk[3], 1)
    T.Border(b, C.line2)
    T.Color(label, C.ivory)
  end
end

function W.Button(parent, text, style, width, height)
  local b = CreateFrame("Button", nil, parent)
  b.style = style or "ghost"
  local st = STYLES[b.style] or STYLES.ghost
  b:SetSize(width or 120, height or 30)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.07)
  b.label = T.Text(b, st.font, st.size)
  b.label:SetPoint("LEFT", 6, 0)
  b.label:SetPoint("RIGHT", -6, 0)
  b.label:SetJustifyH("CENTER")
  function b:SetLabel(t) self.label:SetText(t or "") end
  function b:SetActive(on)
    self.active = on and true or false
    W.StyleButton(self)
  end
  -- Change de style (or <-> ardoise) : l'action principale d'un écran change de
  -- couleur quand elle devient « retirer ».
  function b:SetStyle(newStyle)
    if self.style == newStyle then return end
    self.style = newStyle
    local def = STYLES[newStyle] or STYLES.ghost
    T.SetFont(self.label, def.font, def.size)
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
-- Onglets soulignés (comme les zones du site)
---------------------------------------------------------------------------
function W.Tabs(parent, items, onSelect, size)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(34)
  bar.buttons, bar.items = {}, items
  local rule = T.Line(bar, { 1, 1, 1 }, 0.12)
  rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
  for _, item in ipairs(items) do
    local b = CreateFrame("Button", nil, bar)
    b.key = item.key
    b.label = T.Text(b, "title", size or 17, { 0.78, 0.81, 0.86 })
    b.label:SetPoint("BOTTOMLEFT", 2, 9)
    b.label:SetText(item.label)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", 0, 0)
    b.line:SetPoint("BOTTOMRIGHT", 0, 0)
    b.line:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 1)
    b:SetScript("OnClick", function() bar:Select(item.key, true) end)
    b:SetScript("OnEnter", function(self) if bar.selected ~= self.key then self.label:SetTextColor(1, 1, 1) end end)
    b:SetScript("OnLeave", function(self) if bar.selected ~= self.key then self.label:SetTextColor(0.78, 0.81, 0.86) end end)
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
        local w = math.max(40, (b.label:GetStringWidth() or 60) + 6)
        b:SetSize(w, 34)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", x, 0)
        x = x + w + 22
      end
    end
  end
  function bar:Select(key, user)
    self.selected = key
    for k, b in pairs(self.buttons) do
      local on = (k == key)
      b.line:SetShown(on)
      if on then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(0.78, 0.81, 0.86) end
    end
    if onSelect then onSelect(key, user) end
  end
  function bar:SetHidden(key, hidden)
    for _, item in ipairs(self.items) do
      if item.key == key then item.hidden = hidden end
    end
    self:Layout()
  end
  function bar:SetLabel(key, text)
    local b = self.buttons[key]
    if b then b.label:SetText(text) end
    self:Layout()
  end
  bar:Layout()
  return bar
end

-- Rangée de pastilles (« À venir 6 », « Passées 2 »).
function W.Chips(parent, items, onSelect)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(26)
  row.buttons, row.items = {}, items
  for _, item in ipairs(items) do
    local b = W.Button(row, item.label, "chip", 80, 26)
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
        b:SetPoint("LEFT", x, 0)
        x = x + w + 6
      end
    end
    self.width = x
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
  e:SetSize(width or 160, height or 26)
  e:SetAutoFocus(false)
  T.SetFont(e, "body", 12)
  e:SetTextColor(C.ivory[1], C.ivory[2], C.ivory[3])
  e:SetTextInsets(8, 8, 0, 0)
  if maxLetters then e:SetMaxLetters(maxLetters) end
  e.bg = T.Fill(e, C.sunk)
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
  holder.bg = T.Fill(holder, { 0.02, 0.03, 0.075 })
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
  e:SetTextColor(0.73, 0.76, 0.87)
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
  T.Fill(b.box, C.sunk)
  T.Border(b.box, C.line2)
  b.tick = b.box:CreateTexture(nil, "ARTWORK")
  b.tick:SetSize(8, 8)
  b.tick:SetPoint("CENTER")
  b.tick:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 1)
  b.label = T.Text(b, "body", 12, C.ivory)
  b.label:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
  b.label:SetText(label or "")
  function b:SetChecked(on)
    self.checked = on and true or false
    self.tick:SetShown(self.checked)
    T.Border(self.box, self.checked and C.tealBorder or C.line2)
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
  f.track:SetWidth(2)
  f.track:SetColorTexture(1, 1, 1, 0.06)
  f.thumb = f:CreateTexture(nil, "OVERLAY")
  f.thumb:SetWidth(4)
  f.thumb:SetColorTexture(C.line2[1] + 0.15, C.line2[2] + 0.15, C.line2[3] + 0.15, 1)

  for i = 1, visible do
    local row = CreateFrame("Button", nil, f)
    row:SetHeight(rh)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * rh)
    row:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, 0.05)
    if opts.create then opts.create(row, i) end
    row:SetScript("OnClick", function(self, button)
      if self.item and opts.click then opts.click(self.item, self, button) end
    end)
    f.rows[i] = row
  end

  f.empty = T.Para(f, "body", 12, C.muted, opts.width - 24)
  f.empty:SetPoint("TOPLEFT", 12, -12)

  function f:Refresh()
    local n = #self.items
    local maxOffset = math.max(0, n - self.visible)
    if self.offset > maxOffset then self.offset = maxOffset end
    for i, row in ipairs(self.rows) do
      local item = self.items[self.offset + i]
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
      self.thumb:SetPoint("TOPRIGHT", 0, -y)
    else
      self.track:Hide(); self.thumb:Hide()
    end
    self.empty:SetShown(n == 0 and self.emptyText ~= nil)
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
  T.Border(menu, C.gold, 0.8)
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
      b.mark:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 1)
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.08)
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
  if c then t:SetColorTexture(c[1], c[2], c[3], 1) end
  return t
end

-- Pastille de statut (texte coloré dans un cadre fin).
function W.Badge(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(18)
  f.bg = T.Fill(f, C.sunk)
  f.label = T.Text(f, "semi", 11)
  f.label:SetPoint("CENTER")
  function f:Set(text, c)
    self.label:SetText(text or "")
    T.Color(self.label, c or C.brume)
    T.Border(self, c or C.line2, 0.55)
    self:SetWidth((self.label:GetStringWidth() or 40) + 16)
  end
  return f
end

-- Barre de progression : fond creux, remplissage coloré. Largeur donnée d'avance.
function W.Bar(parent, width, height)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, height or 8)
  f.barWidth = width
  f.bg = T.Fill(f, C.sunk)
  T.Border(f, C.line)
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetPoint("TOPLEFT", 1, -1)
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  function f:Set(ratio, color)
    ratio = math.max(0, math.min(1, ratio or 0))
    color = color or C.teal
    self.fill:SetColorTexture(color[1], color[2], color[3], 1)
    self.fill:SetWidth(math.max(0.01, (self.barWidth - 2) * ratio))
    self.fill:SetShown(ratio > 0)
  end
  return f
end

-- Petit chiffre sur fond creux avec sa légende (« 12 » « en ligne »).
function W.Stat(parent, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 46)
  f.bg = T.Fill(f, C.sunk)
  T.Border(f, C.line)
  f.num = T.Text(f, "title", 20, C.ivory)
  f.num:SetPoint("TOP", 0, -5)
  f.label = T.Text(f, "body", 11, C.muted)
  f.label:SetPoint("BOTTOM", 0, 5)
  function f:Set(n, label, color)
    self.num:SetText(n)
    T.Color(self.num, color or C.ivory)
    self.label:SetText(label)
  end
  return f
end

-- Compteur de rôle « 1/2 tanks » : sarcelle si plein, ambre s'il manque.
function W.RoleNeed(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(24)
  f.bg = T.Fill(f, C.sunk)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(14, 14)
  f.icon:SetPoint("LEFT", 8, 0)
  f.label = T.Text(f, "semi", 12)
  f.label:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
  function f:Set(role, have, need)
    self.icon:SetTexture(T.Icon(T.ROLE_ICON[role]))
    local full = have >= need
    local c = full and C.teal or C.amber
    self.icon:SetVertexColor(c[1], c[2], c[3])
    T.Border(self, c, 0.55)
    local word = DR.Util.ROLE_PLURAL[role]
    self.label:SetText(T.Hex(c) .. have .. "|r" .. T.Hex(C.muted) .. "/" .. need .. "|r " .. word)
    self:SetWidth(36 + (self.label:GetStringWidth() or 60))
  end
  return f
end
