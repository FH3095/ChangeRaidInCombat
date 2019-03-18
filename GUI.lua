
local CRIC = ChangeRaidInCombat

local mainFrame = nil
local selectedGroup = nil
local selectedPlayer = nil

local function memberClicked(frame, groupNumber, playerNumber)
	if selectedGroup == nil then
		frame:SetColor(CRIC.consts.SELECTED_COLOR())
		selectedGroup = groupNumber
		selectedPlayer = playerNumber
	else
		if selectedGroup ~= groupNumber or selectedPlayer ~= playerNumber then
			CRIC:addChange(selectedGroup, selectedPlayer, groupNumber, playerNumber)
		else
			CRIC:refreshGUI()
		end
		selectedGroup = nil
		selectedPlayer = nil
	end
end

function CRIC:refreshGUI()
	if mainFrame == nil then
		mainFrame = self.gui:Create("Frame")
		mainFrame:SetLayout("Flow")
		mainFrame:SetAutoAdjustHeight(true)
		mainFrame:SetWidth(700)
		mainFrame:SetHeight(620)
		mainFrame:SetTitle("Raid")
	end


	mainFrame:PauseLayout()
	mainFrame:ReleaseChildren()
	mainFrame:PauseLayout()

	for groupNumber,groupData in ipairs(CRIC:getRaidGroup()) do
		local groupFrame = self.gui:Create("InlineGroup")
		groupFrame:SetTitle(string.format("Group %d", groupNumber))
		mainFrame:AddChild(groupFrame)
		for playerNumber,playerData in ipairs(groupData) do
			local memberFrame = self.gui:Create("InteractiveLabel")
			memberFrame:SetFont(GameFontHighlight:GetFont(), 16, "OUTLINE")
			memberFrame:SetText(playerData["name"])
			if playerData["isEmpty"] == false then
				memberFrame:SetColor(RAID_CLASS_COLORS[playerData["class"]]:GetRGBA())
			else
				memberFrame:SetColor(CRIC.consts.EMPTY_COLOR())
			end
			memberFrame:SetCallback("OnClick", function() memberClicked(memberFrame, groupNumber, playerNumber) end)
			groupFrame:AddChild(memberFrame)
		end
	end

	local doChangeButton = self.gui:Create("Button")
	doChangeButton:SetText("Change group now")
	doChangeButton:SetRelativeWidth(1.0)
	doChangeButton:SetCallback("OnClick", function() selectedGroup=nil; selectedPlayer=nil; CRIC:doChanges() end)
	mainFrame:AddChild(doChangeButton)

	local doResetButton = self.gui:Create("Button")
	doResetButton:SetText("Reset")
	doResetButton:SetRelativeWidth(1.0)
	doResetButton:SetCallback("OnClick", function() selectedGroup=nil; selectedPlayer=nil; CRIC:resetChanges() end)
	mainFrame:AddChild(doResetButton)

	mainFrame:ResumeLayout()
	mainFrame:DoLayout()
end

function CRIC:showGUI()
	self:refreshGUI()
	mainFrame:Show()
end
