-- Membres de la guilde sur la carte du monde (fournisseur de données de la
-- carte du jeu, comme les membres du groupe).

local _, DR = ...
local Pins = DR:NewModule("MapPins")
local Util = DR.Util
local GuildMap = DR.GuildMap

local TEMPLATE = "DernierRempartMapPinTemplate"

-- Le gabarit XML s'appuie sur ce mélange ; les méthodes de la carte du jeu y
-- sont ajoutées à la connexion.
DernierRempartMapPinMixin = {}
local PinMixin = DernierRempartMapPinMixin

function PinMixin:OnLoad()
  if self.UseFrameLevelType then
    local ok = pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_GROUP_MEMBER")
    if not ok then pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_AREA_POI") end
  end
  if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.25) end
end

function PinMixin:OnAcquired(name, x, y)
  self.name = name
  self:SetPosition(x, y)
  self.class = DR.Profile:ClassOf(name)
  local r, g, b = Util.ClassColor(self.class)
  self.Dot:SetVertexColor(r, g, b)
end

function PinMixin:OnMouseEnter()
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(Util.ClassName(self.name, self.class))
  local m = DR.Guild:Get(self.name)
  if m then GameTooltip:AddLine("Niveau " .. (m.level or "?") .. " · " .. (m.zone or ""), 0.73, 0.76, 0.82) end
  GameTooltip:AddLine("Dernier Rempart", 0.9, 0.77, 0.49)
  GameTooltip:Show()
end

function PinMixin:OnMouseLeave()
  GameTooltip:Hide()
end

local Provider = {}

function Provider:RemoveAllData()
  self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function Provider:RefreshAllData()
  self:RemoveAllData()
  if not DR.db.settings.showMapPins then return end
  local map = self:GetMap()
  local mapID = map:GetMapID()
  if not mapID then return end
  for name, p in pairs(GuildMap:Positions()) do
    if not p.me then
      local x, y = GuildMap.ToMap(p, mapID)
      if x then map:AcquirePin(TEMPLATE, name, x, y) end
    end
  end
end

function Provider:OnShow()
  GuildMap:SetWatching("monde", true)
  if not self.ticker then
    self.ticker = DR.Every(2, function() self:RefreshAllData() end)
  end
end

function Provider:OnHide()
  GuildMap:SetWatching("monde", false)
  if self.ticker then self.ticker:Cancel(); self.ticker = nil end
end

function Provider:OnMapChanged()
  self:RefreshAllData()
end

function Pins:Attach()
  if self.attached or not (WorldMapFrame and WorldMapFrame.AddDataProvider) then return end
  if not (MapCanvasDataProviderMixin and MapCanvasPinMixin) then return end
  for k, v in pairs(MapCanvasPinMixin) do
    if PinMixin[k] == nil then PinMixin[k] = v end
  end
  local provider = CreateFromMixins(MapCanvasDataProviderMixin, Provider)
  WorldMapFrame:AddDataProvider(provider)
  self.provider = provider
  self.attached = true
end

function Pins:OnLogin()
  self:Attach()
  if not self.attached then
    DR:On("ADDON_LOADED", function(_, name)
      if name == "Blizzard_WorldMap" then self:Attach() end
    end)
  end
  DR:Listen("SETTINGS_CHANGED", function(what)
    if what == "showMapPins" and self.provider and WorldMapFrame:IsShown() then self.provider:RefreshAllData() end
  end)
end
