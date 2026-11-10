-- Onglet Mes persos : les persos du compte, lus tout seuls dans le jeu.

local _, DR = ...
local UI, T, W, Util = DR.UI, DR.Theme, DR.Widgets, DR.Util
local C = T.C

local Tab = {}
UI:RegisterTab("persos", "Mes persos", Tab)

function Tab:Create(f, width, height)
  self.f = f
  local intro = T.Para(f, "body", 12, C.ivory, width - 200)
  intro:SetPoint("TOPLEFT", 0, -2)
  intro:SetText("Tes persos sont lus tout seuls : à la connexion, quand tu montes de niveau, de métier ou changes de spé. Rien à taper. Leurs fiches partent vers la guilde, et les officiers les passent au site. Ouvre ta fenêtre de métier une fois pour partager tes recettes.")
  local rescan = W.Button(f, "Relire mon perso", "gold", 180, 30)
  rescan:SetPoint("TOPRIGHT", 0, 0)
  rescan:SetScript("OnClick", function()
    DR.Profile:Scan("manuel")
    UI:Toast("Fiche relue.", "ok")
  end)

  local roleLabel = T.Text(f, "semi", 12, C.goldPale)
  roleLabel:SetPoint("TOPLEFT", 0, -52)
  roleLabel:SetText("Mon rôle pour les inscriptions")
  self.roleBtns = {}
  local last
  for _, role in ipairs(Util.ROLES) do
    local b = W.Button(f, Util.ROLE_LABEL[role], "toggle", 96, 28)
    if last then b:SetPoint("LEFT", last, "RIGHT", 6, 0) else b:SetPoint("LEFT", roleLabel, "RIGHT", 14, 0) end
    b:SetScript("OnClick", function()
      DR.Profile:SetPreferredRole(role)
      self:Refresh()
    end)
    self.roleBtns[role] = b
    last = b
  end

  self.list = W.List(f, {
    width = width, height = height - 92, rowHeight = 84,
    create = function(row)
      local card = T.Card(row)
      card:SetPoint("TOPLEFT", 0, 0)
      card:SetPoint("BOTTOMRIGHT", 0, 8)
      row.card = card
      row.name = T.Text(card, "title", 17, C.ivory)
      row.name:SetPoint("TOPLEFT", 14, -10)
      row.info = T.Text(card, "body", 11, C.brume)
      row.info:SetPoint("LEFT", row.name, "RIGHT", 12, -1)
      row.seen = T.Text(card, "body", 10, C.muted)
      row.seen:SetPoint("TOPRIGHT", -14, -12)
      row.seen:SetJustifyH("RIGHT")
      row.profs = T.Text(card, "body", 12, C.ivory)
      row.profs:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -8)
      row.profs:SetPoint("RIGHT", -14, 0)
      row.state = T.Text(card, "body", 11, C.teal)
      row.state:SetPoint("BOTTOMLEFT", 14, 9)
      row.state:SetPoint("RIGHT", -14, 0)
    end,
    update = function(row, c) self:UpdateRow(row, c) end,
  })
  self.list:SetPoint("TOPLEFT", 0, -92)
end

function Tab:UpdateRow(row, c)
  local current = c.n == DR.playerName
  row.name:SetText(Util.ClassName(c.n, c.cl) .. (current and (T.Hex(C.goldText) .. "  (connecté)|r") or ""))
  local role = (DR.db.prefs[c.n] and DR.db.prefs[c.n].role) or c.r
  local parts = { "niveau " .. (c.lv or "?") }
  if c.sp or role then
    parts[#parts + 1] = (role and T.RoleIcon(role, 11, C.teal) .. " " or "") .. (c.sp or Util.ROLE_LABEL[role] or "")
  else
    parts[#parts + 1] = "spé ?"
  end
  parts[#parts + 1] = c.g or "sans guilde"
  row.info:SetText(table.concat(parts, " · "))
  row.seen:SetText(current and "vu à l'instant" or ("vu " .. Util.Ago(c.seen)))
  local profs = {}
  for _, p in ipairs(c.p or {}) do
    local nrec = c.recipes and c.recipes[tostring(p.id)]
    local txt = p.nm .. " " .. T.Hex(C.goldText) .. (p.lv or "?") .. "|r" .. T.Hex(C.muted) .. "/" .. (p.mx or "?") .. "|r"
    if nrec then txt = txt .. T.Hex(C.muted) .. " (" .. nrec.n .. " recettes)|r" end
    profs[#profs + 1] = txt
  end
  row.profs:SetText(#profs > 0 and table.concat(profs, "   ") or (T.Hex(C.muted) .. "Pas de métier lu pour l'instant.|r"))
  if not c.g then
    row.state:SetText(T.Hex(C.muted) .. "Hors guilde : rien n'est envoyé.|r")
  elseif c.g ~= DR.Guild.name then
    row.state:SetText(T.Hex(C.muted) .. "Dans une autre guilde (" .. c.g .. ") : partagé là-bas seulement.|r")
  else
    local shared = DR.Store:Get("chars", c.n)
    if shared then
      row.state:SetText("Partagée avec la guilde · fiche du " .. Util.ShortDate(shared.u))
    else
      row.state:SetText(T.Hex(C.amber) .. "• Pas encore partagée : connecte ce perso une fois avec l'add-on.|r")
    end
  end
end

function Tab:Refresh()
  if not self.f then return end
  local role = DR.Profile:PreferredRole(DR.playerName)
  for r, b in pairs(self.roleBtns) do b:SetActive(r == role) end
  self.list:SetEmptyText("Aucun perso lu pour l'instant.")
  self.list:SetItems(DR.Profile:MyChars(), true)
end
