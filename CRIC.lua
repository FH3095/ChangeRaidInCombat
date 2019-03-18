
local ADDON_NAME = "ChangeRaidInCombat"
local VERSION = "@project-version@"
local log = FH3095Debug.log
local CRIC = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME)
ChangeRaidInCombat = CRIC


CRIC.consts = {}
CRIC.consts.ADDON_NAME = ADDON_NAME
CRIC.consts.VERSION = VERSION
CRIC.consts.MAX_RAID_GROUPS = 8
CRIC.consts.MAX_GROUP_MEMBERS = 5
CRIC.consts.MAX_RAID_MEMBERS = CRIC.consts.MAX_GROUP_MEMBERS * CRIC.consts.MAX_RAID_GROUPS
CRIC.consts.EMPTY_COLOR = function() return 0.35,0.35,0.35 end
CRIC.consts.SELECTED_COLOR = function() return 1.0, 0.2, 0.2 end


function CRIC:OnEnable()
	FH3095Debug.onEnable()
end

function CRIC:OnInitialize()
	log("CRIC:OnInitialize")
	self.gui = LibStub("AceGUI-3.0")
	self.timers = {}
	LibStub("AceTimer-3.0"):Embed(self.timers)
	self.events = {}
	LibStub("AceEvent-3.0"):Embed(self.events) -- Have to embed, UnregisterEvent doesnt work otherwise
end

local function showGUI()
	CRIC:showGUI()
end

SLASH_CHANGERAIDINCOMBAT1 = "/cric"
SlashCmdList["CHANGERAIDINCOMBAT"] = showGUI
