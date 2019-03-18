
local CRIC = ChangeRaidInCombat
local log = FH3095Debug.log
local PSEUDO_RAID = false

local newRaidSetup = {}

local function tableIsEmpty(tbl)
	for _, _ in pairs(tbl) do
		return false
	end
	return true
end

local function findPlayerInRaidGroup(group, playerName)
	for j,_ in ipairs(group) do
		if group[j]["name"] == playerName then
			return j
		end
	end
	return nil
end

local function findPlayerInRaid(raid, playerName)
	for i,_ in ipairs(raid) do
		local playerPos = findPlayerInRaidGroup(raid[i], playerName)
		if playerPos ~= nil then
			return i,playerPos
		end
	end
	return nil
end

local function getCurrentRaidGroup(withEmptySlots)
	local createEntry = function(name, class)
		local isEmpty = false
		if name == nil then
			name = "<Empty>"
			isEmpty = true
		end
		return {name = name, class = class, isEmpty = isEmpty}
	end

	local raid = {}

	-- Save raid members to table
	for i = 1, CRIC.consts.MAX_RAID_MEMBERS do
		local playerName,_,playerGroup,_,_,playerClass = GetRaidRosterInfo(i)
		if playerName ~= nil then
			if raid[playerGroup] == nil then
				raid[playerGroup] = {}
			end
			table.insert(raid[playerGroup], createEntry(playerName, playerClass))
		end
	end

	-- Create at least empty groups (and probably empty slots)
	for i = 1, CRIC.consts.MAX_RAID_GROUPS do
		if raid[i] == nil then
			raid[i] = {}
		end
		if withEmptySlots then
			for j = (#raid[i])+1, CRIC.consts.MAX_GROUP_MEMBERS do
				table.insert(raid[i], createEntry(nil, nil))
			end
		end
	end

	if PSEUDO_RAID then
		raid[1][1] = createEntry("Test1","PRIEST")
		raid[1][2] = createEntry("Test2","PALADIN")
		raid[1][3] = createEntry("Test3","PALADIN")
		raid[1][4] = createEntry("Test4","PALADIN")
		raid[1][5] = createEntry("Test5","PALADIN")
		raid[2][1] = createEntry("Test2_1","HUNTER")
		raid[2][2] = createEntry("Test2_2","HUNTER")
		raid[2][3] = createEntry("Test2_3","HUNTER")
		raid[2][4] = createEntry("Test2_4","HUNTER")
		raid[2][5] = createEntry("Test2_5","HUNTER")
		raid[3][1] = createEntry("Test3_1","WARRIOR")
		raid[3][2] = createEntry("Test3_2","WARRIOR")
		raid[3][3] = createEntry("Test3_3","WARRIOR")
		raid[3][4] = createEntry("Test3_4","WARRIOR")
		raid[3][5] = createEntry("Test3_5","WARRIOR")
		raid[4][1] = createEntry("Test4_1","SHAMAN")
		raid[4][2] = createEntry("Test4_2","SHAMAN")
	end

	return raid
end

--Selection sort
local function sortAndSaveChanges(raid, swapFunc)
	local size = #raid

	for i = 1, size do
		local minPos = i
		for j = i+1, size do
			if raid[j].targetGroup < raid[minPos].targetGroup then
				minPos = j
			end
		end

		if minPos ~= i then
			swapFunc(i, minPos)
		end
	end

	return nil
end

local function executeChanges(changes)
	local searchPlayerInRaid = function(searchName)
		for i = 1, CRIC.consts.MAX_RAID_MEMBERS do
			local foundName = GetRaidRosterInfo(i)
			if foundName == searchName then
				return i
			end
		end
		return nil
	end

	for changePos,change in ipairs(changes) do
		if change.player ~= nil then
			local playerIndex = searchPlayerInRaid(change.player)
			log("CRIC:ExecChange Move " .. change.player .. " -> " .. change.group, playerIndex, change)
			SetRaidSubgroup(playerIndex, change.group)
		else
			local player1Index = searchPlayerInRaid(change.player1)
			local player2Index = searchPlayerInRaid(change.player2)
			log("CRIC:ExecChange Swap " .. change.player1 .. " <-> " .. change.player2, player1Index, player2Index, change)
			SwapRaidSubgroup(player1Index, player2Index)
		end
	end
end

function CRIC:doChanges()
	log("CRIC:DoChanges", newRaidSetup)

	local currentRaid = getCurrentRaidGroup(true)

	-- Prepare new raid group: Remove all no longer existing members
	for _,group in ipairs(newRaidSetup) do
		for _,member in ipairs(group) do
			if not UnitInRaid(member.name) then
				if not PSEUDO_RAID then
					member.isEmpty = true
				end
			end
		end
	end
	-- Prepare new raid group: Add all not added members to last free positions
	for _,group in ipairs(currentRaid) do
		for _,member in ipairs(group) do
			local foundGroup = findPlayerInRaid(newRaidSetup, member.name)
			if foundGroup == nil then
				-- couldnt find player in newRaidGroup -> add to last possible group
				local done = false
				for targetGroupPos = #newRaidSetup, 1, -1 do
					for targetMemberPos,targetMember in ipairs(newRaidSetup[targetGroupPos]) do
						if targetMember.isEmpty then
							newRaidSetup[targetGroupPos][targetMemberPos] = member
							done = true
						end
						if done then break end
					end
					if done then break end
				end
				if not done then
					error("Cant find group position for " .. member.name)
				end
			end
		end
	end

	local emptySlotsToGroupList = {}
	-- Prepare: Count empty slots per group
	for groupNumber,group in ipairs(newRaidSetup) do
		for _,member in ipairs(group) do
			if member.isEmpty then
				table.insert(emptySlotsToGroupList, groupNumber)
			end
		end
	end

	-- Prepare current Raid: Assign target groups to members
	for groupNumber,group in ipairs(currentRaid) do
		for _,member in ipairs(group) do
			if not member.isEmpty then
				member.targetGroup = findPlayerInRaid(newRaidSetup, member.name)
			else
				member.targetGroup = table.remove(emptySlotsToGroupList, 1)
			end
		end
	end
	if not tableIsEmpty(emptySlotsToGroupList) then
		log("CRIC:Error empty slots mismatch", emptySlotsToGroupList)
		log("CRIC:DoChange newRaid", newRaidSetup)
		log("CRIC:DoChange currentRaid", currentRaid)
		error("Empty slots mismatch?!?")
	end

	-- Prepare: Flatten current raid
	local raidFlat = {}
	local i = 1
	for _,group in ipairs(currentRaid) do
		for _,member in ipairs(group) do
			raidFlat[i] = member
			i = i + 1
		end
	end

	local changes = {}
	-- Now: Do Business: Get Changes
	-- Sorting algo: Selection sort. Reason: Seems to be the algo with least number of swaps.
	-- https://www.quora.com/Which-of-the-sorting-algorithms-require-the-least-amount-of-swapping-or-memory-copying-operations
	-- https://www.quora.com/Which-sorting-algorithm-requires-the-minimum-number-of-swaps/answer/Martin-Puryear
	-- Requirements for sorting algo: In-Memory (needed for 40 player groups), least number of swaps (swaps are expensive!)
	-- No insertion operations, because we cant move all follwing elements one position down
	log("CRIC:DoChange Sort Prepation done", raidFlat)
	local swapFunc = function(pos1, pos2)
		local entry1 = raidFlat[pos1]
		local entry2 = raidFlat[pos2]
		local group1 = math.ceil(pos1/CRIC.consts.MAX_GROUP_MEMBERS)
		local group2 = math.ceil(pos2/CRIC.consts.MAX_GROUP_MEMBERS)
		if group1 ~= group2 then
			if entry1.isEmpty and entry2.isEmpty then
			-- Nothing to do
			elseif (not entry1.isEmpty) and (not entry2.isEmpty) then
				table.insert(changes, {player1 = entry1.name, player2 = entry2.name})
			elseif ((not entry1.isEmpty) and entry2.isEmpty) or ((not entry2.isEmpty) and entry1.isEmpty) then
				local playerName = (not entry1.isEmpty) and entry1.name or entry2.name
				local toGroup = entry1.isEmpty and group1 or group2
				local lastChange = changes[#changes]
				if lastChange ~= nil and lastChange.player == playerName then
					lastChange.group = toGroup
				else
					table.insert(changes, {player = playerName, group = toGroup})
				end
			else
				log("CRIC:Error Missing case", entry1, entry2)
				error("Missing case for swap func: " .. entry1.name .. " <-> " .. entry2.name)
			end
		end
		raidFlat[pos1] = entry2
		raidFlat[pos2] = entry1
	end
	sortAndSaveChanges(raidFlat, swapFunc)

	log("CRIC:DoChanges calc finished", changes)

	if tableIsEmpty(changes) then
		print("--- Nothing to change")
		newRaidSetup = {}
		self:refreshGUI()
	else
		executeChanges(changes)
	end
end

function CRIC:addChange(group1, player1, group2, player2)
	log("CRIC:AddChange", group1, player1, group2, player2, newRaidSetup[group1][player1], newRaidSetup[group2][player2])

	local tmpEntry = newRaidSetup[group1][player1]
	newRaidSetup[group1][player1] = newRaidSetup[group2][player2]
	newRaidSetup[group2][player2] = tmpEntry

	self:refreshGUI()
end

function CRIC:resetChanges()
	log("CRIC:ResetChanges")
	newRaidSetup = {}
	self:refreshGUI()
end

function CRIC:getRaidGroup()
	if not tableIsEmpty(newRaidSetup) then
		return newRaidSetup
	end

	newRaidSetup = getCurrentRaidGroup(true)

	log("CRIC:getRaidGroup", newRaidSetup)
	return newRaidSetup
end
