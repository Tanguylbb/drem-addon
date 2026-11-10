-- Vérification statique de l'add-on : luacheck DernierRempart
std = "lua51"
max_line_length = 300
max_string_line_length = false
unused_args = false
self = false

globals = {
  "DernierRempart", "DernierRempartDB", "DernierRempartMapPinMixin",
  "SLASH_DERNIERREMPART1", "SLASH_DERNIERREMPART2", "SlashCmdList",
  "DernierRempart_OnAddonCompartmentClick", "DernierRempart_OnAddonCompartmentEnter",
  "DernierRempart_OnAddonCompartmentLeave",
}

read_globals = {
  -- Cadres et interface
  "CreateFrame", "UIParent", "Minimap", "GameTooltip", "WorldMapFrame", "UISpecialFrames",
  "DEFAULT_CHAT_FRAME", "ChatFrame1", "STANDARD_TEXT_FONT", "RAID_CLASS_COLORS", "CreateColor",
  "CreateVector2D", "CreateFromMixins", "MapCanvasDataProviderMixin", "MapCanvasPinMixin",
  "hooksecurefunc", "Clamp", "ToggleWorldMap", "GetCursorPosition",
  "ChatEdit_InsertLink", "ChatFrameUtil", "ChatFrame_SendTell", "ChatFrame_OpenChat",
  -- Espaces C_
  "C_AddOns", "C_ChatInfo", "C_ClassColor", "C_GuildInfo", "C_Item", "C_Map", "C_Spell",
  "C_Timer", "C_TradeSkillUI", "Enum",
  -- Fonctions du jeu
  "GetAddOnMetadata", "GetTime", "GetServerTime", "time", "date",
  "UnitName", "UnitClass", "UnitRace", "UnitLevel", "GetNormalizedRealmName", "GetRealmName",
  "IsInGuild", "GetGuildInfo", "GetNumGuildMembers", "GetGuildRosterInfo", "GuildRoster",
  "GuildControlGetRankName", "RegisterAddonMessagePrefix", "SendAddonMessage",
  "IsEncounterInProgress", "IsInInstance",
  "GetSpecialization", "GetSpecializationInfo", "GetNumTalentTabs", "GetTalentTabInfo",
  "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
  "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillLine", "GetTradeSkillRecipeLink",
  "GetTradeSkillItemLink", "GetNumCrafts", "GetCraftInfo", "GetCraftItemLink", "GetCraftDisplaySkillLine",
  "GetItemInfo", "GetItemIcon", "GetSpellInfo", "GetSpellTexture",
}
