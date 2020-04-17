-- Locals
local EventFrame = CreateFrame("Frame")
local CurrentRollValue = 10000
local Rolls = {}
local Players = {}
local Channel = "RAID"
local ChannelIndex = 2
local CustomChannelIndex = 0
local Locked = false
local Me = UnitName("player")
local DB = LibStub:GetLibrary("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")
local DataObject = DB:NewDataObject("vGambler", {label = "vGambler", type = "data source", icon = "Interface\\ICONS\\INV_Misc_Coin_01", text = "vGambler"})
local NewGameButton, LastCallButton, RollButton, ResetGameButton, EnterUserButton, UserRollButton
local RollMatch = "(.-) rolls (%d-) %((%d-)%-(%d-)%)"

local ChannelToLabel = {
	["PARTY"] = "|cffaaaaffParty|r",
	["RAID"] = "|cffff7f00Raid",
	["GUILD"] = "|cff40ff40Guild|r",
	["SAY"] = "|cffffffffSay|r",
}

local ChannelIndexList = {
	[1] = "PARTY",
	[2] = "RAID",
	[3] = "GUILD",
	[4] = "SAY",
}

local CustomChannels = {}

local EventGroups = {
	["PARTY"] = {
		["CHAT_MSG_PARTY"] = true,
		["CHAT_MSG_PARTY_LEADER"] = true,
	},
	
	["RAID"] = {
		["CHAT_MSG_RAID"] = true,
		["CHAT_MSG_RAID_LEADER"] = true,
	},
	
	["GUILD"] = {
		["CHAT_MSG_GUILD"] = true,
		["CHAT_MSG_GUILD_LEADER"] = true,
	},
	
	["SAY"] = {
		["CHAT_MSG_SAY"] = true,
	},
	
	["CHANNEL"] = {
		["CHAT_MSG_CHANNEL"] = true,
	},
}

local DisableButton = function(button)
	button:EnableMouse(false)
	button.Label:SetTextColor(0.3, 0.3, 0.3)
end

local EnableButton = function(button)
	button:EnableMouse(true)
	button.Label:SetTextColor(1, 1, 1)
end

-- Functions
local gsub = gsub
local type = type
local floor = floor
local format = format
local strsub = strsub
local strfind = strfind
local strmatch = string.match
local tonumber = tonumber
local tostring = tostring
local reverse = string.reverse
local tinsert = tinsert
local tremove = tremove
local tsort = table.sort
local split = strsplit
local SendChatMessage = SendChatMessage

local Comma = function(number)
	if (not number) then
		return
	end
	
	if (type(number) ~= "number") then
		number = tonumber(number)
	end
	
	local Number = format("%.0f", floor(number + 0.5))
   	local Left, Number, Right = strmatch(Number, "^([^%d]*%d)(%d+)(.-)$")
	
	return Left and Left .. reverse(gsub(reverse(Number), "(%d%d%d)", "%1,")) or number
end

local SortRolls = function()
	EventFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
	
	tsort(Rolls, function(a, b)
		return a[2] > b[2]
	end)
	
	local Winner = Rolls[1]
	local Loser = Rolls[#Rolls]
	local Diff = Winner[2] - Loser[2]
	
	if (not vGambler) then
		vGambler = {}
		vGambler["All"] = {}
		vGambler["Specific"] = {}
	end
	
	-- General information (Who's up, who's down)
	if (not vGambler["All"][Winner[1]]) then
		vGambler["All"][Winner[1]] = 0
	end
	
	if (not vGambler["All"][Loser[1]]) then
		vGambler["All"][Loser[1]] = 0
	end
	
	vGambler["All"][Winner[1]] = vGambler["All"][Winner[1]] + Diff
	vGambler["All"][Loser[1]] = vGambler["All"][Loser[1]] - Diff
	
	-- Detailed information (Who lost/gained how much from who specifically)
	if (not vGambler["Specific"][Winner[1]]) then
		vGambler["Specific"][Winner[1]] = {}
	end
	
	if (not vGambler["Specific"][Loser[1]]) then
		vGambler["Specific"][Loser[1]] = {}
	end
	
	if (not vGambler["Specific"][Winner[1]][Loser[1]]) then
		vGambler["Specific"][Winner[1]][Loser[1]] = 0
	end
	
	if (not vGambler["Specific"][Loser[1]][Winner[1]]) then
		vGambler["Specific"][Loser[1]][Winner[1]] = 0
	end
	
	vGambler["Specific"][Winner[1]][Loser[1]] = vGambler["Specific"][Winner[1]][Loser[1]] + Diff
	vGambler["Specific"][Loser[1]][Winner[1]] = vGambler["Specific"][Loser[1]][Winner[1]] - Diff
	
	SendChatMessage(format("vGambler: %s owes %s %s gold!", Loser[1], Winner[1], Comma(Diff)), Channel)
	
	-- Reset everything
	for i = #Rolls, 1, -1 do
		tremove(Rolls, 1)
	end
	
	for i = #Players, 1, -1 do
		tremove(Players, 1)
	end
	
	Locked = false
end

local PostStats = function(player, override, to)
	local Target = Channel
	local ChatChannel = nil
	
	if override then
		Target = override
		ChatChannel = to
	end
	
	if (not vGambler) then
		SendChatMessage("vGambler: No stats yet!", Target, nil, ChatChannel)
		
		return
	end
	
	if player then
		if vGambler["Specific"][player] then
			local Temp = {}
			local i = 1
			
			for k, v in pairs(vGambler["Specific"][player]) do
				Temp[i] = {k, v}
				i = i + 1
			end
			
			tsort(Temp, function(a, b)
				return a[2] > b[2]
			end)
			
			SendChatMessage(format("vGambler specific stats for %s:", player), Target, nil, ChatChannel)
			
			for i = 1, #Temp do
				if (Temp[i][2] > 0) then
					SendChatMessage(format("%s owes %s %sg", Temp[i][1], player, Comma(Temp[i][2])), Target, nil, ChatChannel)
				else
					local Value = Comma(Temp[i][2])
					
					if strfind(Value, "-") then
						Value = strsub(Value, 2, Value:len())
					end
					
					SendChatMessage(format("%s owes %s %sg", player, Temp[i][1], Value), Target, nil, ChatChannel)
				end
			end
			
			Temp = nil
		else
			SendChatMessage("vGambler: No stats for that player!", Target, nil, ChatChannel)
		end
	else
		local Temp = {}
		local i = 1
		
		for k, v in pairs(vGambler["All"]) do
			Temp[i] = {k, v}
			i = i + 1
		end
		
		SendChatMessage(format("vGambler Stats:", player), Target, nil, ChatChannel)
		
		tsort(Temp, function(a, b)
			return a[2] > b[2]
		end)
		
		for i = 1, #Temp do
			SendChatMessage(format("%d. %s: %s", i, Temp[i][1], Comma(Temp[i][2])), Target, nil, ChatChannel)
		end
		
		Temp = nil
	end
end

local ResetStats = function()
	vGambler = nil
	
	print("vGambler: Stats have been reset.")
end

local BanPlayer = function(player, reason)
	if (not vGamblerBanList) then
		vGamblerBanList = {}
	end
	
	vGamblerBanList[player] = reason
	
	print(format("vGambler: %s has been added to the ban list.", player))
end

local UnbanPlayer = function(player)
	if (not vGamblerBanList) then
		return
	end
	
	vGamblerBanList[player] = nil
	
	print(format("vGambler: %s has been removed from the ban list.", player))
end

local IsBanned = function(player)
	if (not vGamblerBanList) then
		return false
	end
	
	for key, reason in pairs(vGamblerBanList) do
		if (key == player) then
			return true, reason
		end
	end
end

local ResetBans = function()
	vGamblerBanList = nil
	
	print("vGambler: Ban list has been reset.")
end

local IsLeaderRolling = function()
	for i = 1, #Players do
		if (Players[i][1] == Me) then
			return true
		end
	end
	
	return false
end

local OnEvent = function(self, event, message, sender)
	if (event == "CHAT_MSG_SYSTEM") then
		if strfind(message, "%a- rolls %d-") then
			local Name, Roll, Min, Max = strmatch(message, RollMatch)
			
			Roll = tonumber(Roll)
			Min = tonumber(Min)
			Max = tonumber(Max)
			
			if (Min == 1 and Max == CurrentRollValue) then
				for i = 1, #Players do
					if (Players[i][1] == Name and not Players[i][2]) then
						Players[i][2] = true
						tinsert(Rolls, {Players[i][1], Roll})
						
						if (#Rolls == #Players) then
							SortRolls()
						end
						
						break
					end
				end
			end
		end
	elseif EventGroups[Channel][event] then -- This is an event that we're currently interested in, based on our channel selection.
		sender = split("-", sender) -- Remove server name.
		
		if (message == "1") then
			local Banned, Reason = IsBanned(sender)
			
			if Banned then
				if (Reason == true) then -- No reason specified for this player being banned.
					SendChatMessage(format("vGambler: %s is banned from entering.", sender), Channel)
				else -- Let them know why they were banned.
					SendChatMessage(format("vGambler: %s is banned from entering. Reason: %s.", sender, Reason), Channel)
				end
				
				return
			else
				local Found = false
				
				for i = 1, #Players do
					if (Players[i][1] == sender) then
						Found = true
						
						break
					end
				end
				
				if (not Found) then
					Players[#Players + 1] = {[1] = sender}
					
					if (sender == Me) then
						DisableButton(EnterUserButton)
					end
				end
			end
		elseif (message == "-1") then
			for i = 1, #Players do
				if (Players[i][1] == sender) then
					tremove(Players, i)
					
					return
				end
			end
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		-- Minimap Icon
		if (DBIcon and not DBIcon:IsRegistered("vGambler")) then
			DBIcon:Register("vGambler", DataObject)
		end
		
		-- Find custom channels
		local Name, Header, Collapsed, ChannelNumber
		
		for i = 1, GetNumDisplayChannels() do
			Name, Header, Collapsed, ChannelNumber, Count, Active, Category = GetChannelDisplayInfo(i)
			
			if (Name and ChannelNumber and Category == "CHANNEL_CATEGORY_CUSTOM") then
				CustomChannels[#CustomChannels + 1] = {ChannelNumber, Name}
			end
		end
		
		self:UnregisterEvent(event)
	end
end

local ResetGame = function()
	-- Clear out old players and rolls.
	for i = #Rolls, 1, -1 do
		tremove(Rolls, 1)
	end
	
	for i = #Players, 1, -1 do
		tremove(Players, 1)
	end
	
	Locked = false
	
	EventFrame:UnregisterAllEvents()
	
	--SendChatMessage("vGambler: Game has been reset.", Channel)
	print("vGambler: Game has been reset.")
	
	DisableButton(LastCallButton)
	DisableButton(RollButton)
	DisableButton(ResetGameButton)
	DisableButton(EnterUserButton)
	DisableButton(UserRollButton)
end

local NewGame = function()
	if (#Rolls > 0) then -- Clear out data from previous game, if any exists
		ResetGame()
	end
	
	SendChatMessage(format("vGambler: New game started! Current roll is for %sg, type 1 to enter (-1 to leave).", Comma(CurrentRollValue)), Channel)
	
	for event in pairs(EventGroups[Channel]) do
		EventFrame:RegisterEvent(event)
	end
	
	EnableButton(LastCallButton)
	EnableButton(RollButton)
	EnableButton(ResetGameButton)
	EnableButton(EnterUserButton)
	--EnableButton(UserRollButton)
end

local LastCall = function()
	SendChatMessage("vGambler: Last call to enter!", Channel)
	
	DisableButton(LastCallButton)
end

local StillRoll = function()
	for i = 1, #Players do
		if (not Players[i][2]) then
			SendChatMessage(format("vGambler: %s still needs to roll.", Players[i][1]), Channel)
		end
	end
end

local CloseGame = function()
	if Locked then -- There's a roll going currently. Announce who still needs to roll.
		StillRoll()
	else -- Stop accepting players, and start rolling
		if (#Players > 1) then
			EventFrame:UnregisterAllEvents()
			EventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
			
			SendChatMessage("vGambler: Game is now closed! Roll!", Channel)
			
			if IsLeaderRolling() then
				EnableButton(UserRollButton)
			end
			
			Locked = true
		else
			SendChatMessage("vGambler: Not enough players!", Channel)
		end
	end
end

EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:SetScript("OnEvent", OnEvent)

-- Interface
local ButtonOnEnter = function(self)
	self.Tex:SetVertexColor(0.34, 0.34, 0.34)
end

local ButtonOnLeave = function(self)
	self.Tex:SetVertexColor(0.27, 0.27, 0.27)
end

local Font = "Interface\\AddOns\\vGambler\\PTSans.ttf"
local Texture = "Interface\\AddOns\\vGambler\\vUI4.tga"
local Blank = "Interface\\AddOns\\vGambler\\Blank.tga"

local Backdrop = {
	bgFile = Blank,
	edgeFile = Blank,
	edgeSize = 1,
	insets = {left = 0, right = 0, top = 0, bottom = 0},
}

-- Main panel
local CreateGamblerFrame = function()
	local vGamblerFrame = CreateFrame("Frame", "vGamblerFrame", UIParent)
	vGamblerFrame:SetSize(314, 105)
	vGamblerFrame:SetPoint("CENTER", UIParent, 0, 99)
	vGamblerFrame:SetBackdrop(Backdrop)
	vGamblerFrame:SetBackdropColor(0.22, 0.22, 0.22, 0.9)
	vGamblerFrame:SetBackdropBorderColor(0, 0, 0)
	vGamblerFrame:EnableMouse(true)
	vGamblerFrame:SetMovable(true)
	vGamblerFrame:RegisterForDrag("LeftButton")
	vGamblerFrame:SetScript("OnDragStart", vGamblerFrame.StartMoving)
	vGamblerFrame:SetScript("OnDragStop", vGamblerFrame.StopMovingOrSizing)
	
	-- New Game
	vGamblerFrame.Header = CreateFrame("Frame", nil, vGamblerFrame)
	vGamblerFrame.Header:SetPoint("BOTTOM", vGamblerFrame, "TOP", 0, -1)
	vGamblerFrame.Header:SetSize(314, 22)
	vGamblerFrame.Header:SetBackdrop(Backdrop)
	vGamblerFrame.Header:SetBackdropColor(0.22, 0.22, 0.22)
	vGamblerFrame.Header:SetBackdropBorderColor(0, 0, 0)
	vGamblerFrame.Header:EnableMouse(true)
	vGamblerFrame.Header:SetMovable(true)
	vGamblerFrame.Header:RegisterForDrag("LeftButton")
	vGamblerFrame.Header:SetScript("OnDragStart", function() vGamblerFrame:StartMoving() end)
	vGamblerFrame.Header:SetScript("OnDragStop", function() vGamblerFrame:StopMovingOrSizing() end)
	
	vGamblerFrame.Header.Tex = vGamblerFrame.Header:CreateTexture(nil, "ARTWORK")
	vGamblerFrame.Header.Tex:SetPoint("TOPLEFT", vGamblerFrame.Header, 1, -1)
	vGamblerFrame.Header.Tex:SetPoint("BOTTOMRIGHT", vGamblerFrame.Header, -1, 1)
	vGamblerFrame.Header.Tex:SetTexture(Texture)
	vGamblerFrame.Header.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	vGamblerFrame.Header.Label = vGamblerFrame.Header:CreateFontString(nil, "OVERLAY")
	vGamblerFrame.Header.Label:SetPoint("LEFT", vGamblerFrame.Header, 6, -0.5)
	vGamblerFrame.Header.Label:SetFont(Font, 14)
	vGamblerFrame.Header.Label:SetText("|cffFFE6C0vGambler|r")
	vGamblerFrame.Header.Label:SetShadowColor(0, 0, 0)
	vGamblerFrame.Header.Label:SetShadowOffset(1, -1)
	
	-- Close button
	local CloseButton = CreateFrame("Frame", nil, vGamblerFrame.Header)
	CloseButton:SetPoint("TOPRIGHT", vGamblerFrame.Header, 0, 0)
	CloseButton:SetSize(22, 22)
	CloseButton:SetScript("OnEnter", function(self) self.Texture:SetVertexColor(1, 0, 0) end)
	CloseButton:SetScript("OnLeave", function(self) self.Texture:SetVertexColor(1, 1, 1) end)
	CloseButton:SetScript("OnMouseUp", function() vGamblerFrame:Hide() end)
	
	CloseButton.Texture = CloseButton:CreateTexture(nil, "OVERLAY")
	CloseButton.Texture:SetPoint("CENTER", CloseButton, 0, 0)
	CloseButton.Texture:SetSize(16, 16)
	CloseButton.Texture:SetTexture("Interface\\AddOns\\vGambler\\vUIClose.tga")
	
	-- New Game
	NewGameButton = CreateFrame("Frame", nil, vGamblerFrame)
	NewGameButton:SetPoint("TOPLEFT", vGamblerFrame, 4, -4)
	NewGameButton:SetSize(100, 22)
	NewGameButton:SetBackdrop(Backdrop)
	NewGameButton:SetBackdropColor(0.22, 0.22, 0.22)
	NewGameButton:SetBackdropBorderColor(0, 0, 0)
	NewGameButton:SetScript("OnMouseUp", NewGame)
	NewGameButton:SetScript("OnEnter", ButtonOnEnter)
	NewGameButton:SetScript("OnLeave", ButtonOnLeave)
	
	NewGameButton.Tex = NewGameButton:CreateTexture(nil, "ARTWORK")
	NewGameButton.Tex:SetPoint("TOPLEFT", NewGameButton, 1, -1)
	NewGameButton.Tex:SetPoint("BOTTOMRIGHT", NewGameButton, -1, 1)
	NewGameButton.Tex:SetTexture(Texture)
	NewGameButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	NewGameButton.Label = NewGameButton:CreateFontString(nil, "OVERLAY")
	NewGameButton.Label:SetPoint("CENTER", NewGameButton, 0.5, -0.5)
	NewGameButton.Label:SetFont(Font, 14)
	NewGameButton.Label:SetText("New Game")
	NewGameButton.Label:SetShadowColor(0, 0, 0)
	NewGameButton.Label:SetShadowOffset(1, -1)
	
	-- Last Call
	LastCallButton = CreateFrame("Frame", nil, vGamblerFrame)
	LastCallButton:SetPoint("TOPLEFT", NewGameButton, "BOTTOMLEFT", 0, -3)
	LastCallButton:SetSize(100, 22)
	LastCallButton:SetBackdrop(Backdrop)
	LastCallButton:SetBackdropColor(0.22, 0.22, 0.22)
	LastCallButton:SetBackdropBorderColor(0, 0, 0)
	LastCallButton:SetScript("OnMouseUp", LastCall)
	LastCallButton:SetScript("OnEnter", ButtonOnEnter)
	LastCallButton:SetScript("OnLeave", ButtonOnLeave)
	
	LastCallButton.Tex = LastCallButton:CreateTexture(nil, "ARTWORK")
	LastCallButton.Tex:SetPoint("TOPLEFT", LastCallButton, 1, -1)
	LastCallButton.Tex:SetPoint("BOTTOMRIGHT", LastCallButton, -1, 1)
	LastCallButton.Tex:SetTexture(Texture)
	LastCallButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	LastCallButton.Label = LastCallButton:CreateFontString(nil, "OVERLAY")
	LastCallButton.Label:SetPoint("CENTER", LastCallButton, 0.5, -0.5)
	LastCallButton.Label:SetFont(Font, 14)
	LastCallButton.Label:SetText("Last Call")
	LastCallButton.Label:SetShadowColor(0, 0, 0)
	LastCallButton.Label:SetShadowOffset(1, -1)
	
	-- Roll
	RollButton = CreateFrame("Frame", nil, vGamblerFrame)
	RollButton:SetPoint("TOPLEFT", LastCallButton, "BOTTOMLEFT", 0, -3)
	RollButton:SetSize(100, 22)
	RollButton:SetBackdrop(Backdrop)
	RollButton:SetBackdropColor(0.22, 0.22, 0.22)
	RollButton:SetBackdropBorderColor(0, 0, 0)
	RollButton:SetScript("OnMouseUp", CloseGame)
	RollButton:SetScript("OnEnter", ButtonOnEnter)
	RollButton:SetScript("OnLeave", ButtonOnLeave)
	
	RollButton.Tex = RollButton:CreateTexture(nil, "ARTWORK")
	RollButton.Tex:SetPoint("TOPLEFT", RollButton, 1, -1)
	RollButton.Tex:SetPoint("BOTTOMRIGHT", RollButton, -1, 1)
	RollButton.Tex:SetTexture(Texture)
	RollButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	RollButton.Label = RollButton:CreateFontString(nil, "OVERLAY")
	RollButton.Label:SetPoint("CENTER", RollButton, 0.5, -0.5)
	RollButton.Label:SetFont(Font, 14)
	RollButton.Label:SetText("Roll")
	RollButton.Label:SetShadowColor(0, 0, 0)
	RollButton.Label:SetShadowOffset(1, -1)
	
	-- Reset Game
	ResetGameButton = CreateFrame("Frame", nil, vGamblerFrame)
	ResetGameButton:SetPoint("TOPLEFT", RollButton, "BOTTOMLEFT", 0, -3)
	ResetGameButton:SetSize(100, 22)
	ResetGameButton:SetBackdrop(Backdrop)
	ResetGameButton:SetBackdropColor(0.22, 0.22, 0.22)
	ResetGameButton:SetBackdropBorderColor(0, 0, 0)
	ResetGameButton:SetScript("OnMouseUp", ResetGame)
	ResetGameButton:SetScript("OnEnter", ButtonOnEnter)
	ResetGameButton:SetScript("OnLeave", ButtonOnLeave)
	
	ResetGameButton.Tex = ResetGameButton:CreateTexture(nil, "ARTWORK")
	ResetGameButton.Tex:SetPoint("TOPLEFT", ResetGameButton, 1, -1)
	ResetGameButton.Tex:SetPoint("BOTTOMRIGHT", ResetGameButton, -1, 1)
	ResetGameButton.Tex:SetTexture(Texture)
	ResetGameButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	ResetGameButton.Label = ResetGameButton:CreateFontString(nil, "OVERLAY")
	ResetGameButton.Label:SetPoint("CENTER", ResetGameButton, 0.5, -0.5)
	ResetGameButton.Label:SetFont(Font, 14)
	ResetGameButton.Label:SetText("Reset Game")
	ResetGameButton.Label:SetShadowColor(0, 0, 0)
	ResetGameButton.Label:SetShadowOffset(1, -1)
	
	-- Set Channel
	local SetChannelButton = CreateFrame("Frame", nil, vGamblerFrame)
	SetChannelButton:SetPoint("TOPLEFT", NewGameButton, "TOPRIGHT", 3, 0)
	SetChannelButton:SetSize(100, 22)
	SetChannelButton:SetBackdrop(Backdrop)
	SetChannelButton:SetBackdropColor(0.22, 0.22, 0.22)
	SetChannelButton:SetBackdropBorderColor(0, 0, 0)
	SetChannelButton:SetScript("OnMouseUp", function(self)
		if ((ChannelIndex == 4) and (#CustomChannels > 0)) then
			CustomChannelIndex = CustomChannelIndex + 1
			
			Channel = "CHANNEL"
			--print(CustomChannels[CustomChannelIndex][2])
			self.Label:SetText(CustomChannels[CustomChannelIndex][2])
			
			if (CustomChannelIndex >= #CustomChannels) then
				ChannelIndex = 1 -- Reset after we've cycled all valid channels and custom channels
				CustomChannelIndex = 0
			end
		else
			ChannelIndex = ChannelIndex + 1
			
			if (ChannelIndex > 4) then
				ChannelIndex = 1
			end
			
			Channel = ChannelIndexList[ChannelIndex]
			
			self.Label:SetText(ChannelToLabel[Channel])
		end
		
	end)
	SetChannelButton:SetScript("OnEnter", ButtonOnEnter)
	SetChannelButton:SetScript("OnLeave", ButtonOnLeave)
	
	SetChannelButton.Tex = SetChannelButton:CreateTexture(nil, "ARTWORK")
	SetChannelButton.Tex:SetPoint("TOPLEFT", SetChannelButton, 1, -1)
	SetChannelButton.Tex:SetPoint("BOTTOMRIGHT", SetChannelButton, -1, 1)
	SetChannelButton.Tex:SetTexture(Texture)
	SetChannelButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	SetChannelButton.Label = SetChannelButton:CreateFontString(nil, "OVERLAY")
	SetChannelButton.Label:SetPoint("CENTER", SetChannelButton, 0.5, -0.5)
	SetChannelButton.Label:SetFont(Font, 14)
	SetChannelButton.Label:SetText(ChannelToLabel[Channel])
	SetChannelButton.Label:SetShadowColor(0, 0, 0)
	SetChannelButton.Label:SetShadowOffset(1, -1)
	
	-- Roll Value
	local EditBoxOnMouseDown = function(self)
		self:SetAutoFocus(true)
	end
	
	local EditBoxOnEditFocusLost = function(self)
		self:SetAutoFocus(false)
	end
	
	local EditBoxOnEscapePressed = function(self)
		self:SetAutoFocus(false)
		self:ClearFocus()
		
		local Value = self:GetText():gsub(",", ""):gsub("%D", "")
		
		if (Value == "" or Value == " ") then
			return
		end
		
		CurrentRollValue = tonumber(Value)
		
		self:SetText(Comma(CurrentRollValue))
	end
	
	local EditBoxOnEnterPressed = function(self)
		self:SetAutoFocus(false)
		self:ClearFocus()
		
		local Value = self:GetText():gsub(",", ""):gsub("%D", "")
		
		if (Value == "" or Value == " ") then
			self:SetText(Comma(CurrentRollValue))
			
			return
		end
		
		CurrentRollValue = tonumber(Value)
		
		self:SetText(Comma(CurrentRollValue))
	end
	
	local RollValue = CreateFrame("Frame", nil, vGamblerFrame)
	RollValue:SetPoint("TOPLEFT", SetChannelButton, "BOTTOMLEFT", 0, -3)
	RollValue:SetSize(100, 22)
	RollValue:SetBackdrop(Backdrop)
	RollValue:SetBackdropColor(0.22, 0.22, 0.22)
	RollValue:SetBackdropBorderColor(0, 0, 0)
	
	RollValue.Tex = RollValue:CreateTexture(nil, "ARTWORK")
	RollValue.Tex:SetPoint("TOPLEFT", RollValue, 1, -1)
	RollValue.Tex:SetPoint("BOTTOMRIGHT", RollValue, -1, 1)
	RollValue.Tex:SetTexture(Texture)
	RollValue.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	RollValue.Box = CreateFrame("EditBox", nil, RollValue)
	RollValue.Box:SetPoint("TOPLEFT", RollValue, 4, -4)
	RollValue.Box:SetPoint("BOTTOMRIGHT", RollValue, -4, 2)
	RollValue.Box:SetFont(Font, 14)
	RollValue.Box:SetJustifyH("CENTER")
	RollValue.Box:SetText(Comma(CurrentRollValue))
	RollValue.Box:SetShadowColor(0, 0, 0)
	RollValue.Box:SetShadowOffset(1, -1)
	RollValue.Box:SetMaxLetters(6)
	RollValue.Box:SetAutoFocus(false)
	--RollValue.Box:SetNumeric(true)
	RollValue.Box:EnableKeyboard(true)
	RollValue.Box:EnableMouse(true)
	RollValue.Box:SetScript("OnMouseDown", EditBoxOnMouseDown)
	RollValue.Box:SetScript("OnEscapePressed", EditBoxOnEscapePressed)
	RollValue.Box:SetScript("OnEnterPressed", EditBoxOnEnterPressed)
	RollValue.Box:SetScript("OnEditFocusLost", EditBoxOnEditFocusLost)
	
	-- Stats
	local StatsButton = CreateFrame("Frame", nil, vGamblerFrame)
	StatsButton:SetPoint("TOPLEFT", RollValue, "BOTTOMLEFT", 0, -3)
	StatsButton:SetSize(100, 22)
	StatsButton:SetBackdrop(Backdrop)
	StatsButton:SetBackdropColor(0.22, 0.22, 0.22)
	StatsButton:SetBackdropBorderColor(0, 0, 0)
	StatsButton:SetScript("OnMouseUp", function()
		PostStats()
	end)
	StatsButton:SetScript("OnEnter", ButtonOnEnter)
	StatsButton:SetScript("OnLeave", ButtonOnLeave)
	
	StatsButton.Tex = StatsButton:CreateTexture(nil, "ARTWORK")
	StatsButton.Tex:SetPoint("TOPLEFT", StatsButton, 1, -1)
	StatsButton.Tex:SetPoint("BOTTOMRIGHT", StatsButton, -1, 1)
	StatsButton.Tex:SetTexture(Texture)
	StatsButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	StatsButton.Label = StatsButton:CreateFontString(nil, "OVERLAY")
	StatsButton.Label:SetPoint("CENTER", StatsButton, 0.5, -0.5)
	StatsButton.Label:SetFont(Font, 14)
	StatsButton.Label:SetText("Stats")
	StatsButton.Label:SetShadowColor(0, 0, 0)
	StatsButton.Label:SetShadowOffset(1, -1)
	
	-- Reset Stats
	local ResetStatsButton = CreateFrame("Frame", nil, vGamblerFrame)
	ResetStatsButton:SetPoint("TOPLEFT", StatsButton, "BOTTOMLEFT", 0, -3)
	ResetStatsButton:SetSize(100, 22)
	ResetStatsButton:SetBackdrop(Backdrop)
	ResetStatsButton:SetBackdropColor(0.22, 0.22, 0.22)
	ResetStatsButton:SetBackdropBorderColor(0, 0, 0)
	ResetStatsButton:SetScript("OnMouseUp", ResetStats)
	ResetStatsButton:SetScript("OnEnter", ButtonOnEnter)
	ResetStatsButton:SetScript("OnLeave", ButtonOnLeave)
	
	ResetStatsButton.Tex = ResetStatsButton:CreateTexture(nil, "ARTWORK")
	ResetStatsButton.Tex:SetPoint("TOPLEFT", ResetStatsButton, 1, -1)
	ResetStatsButton.Tex:SetPoint("BOTTOMRIGHT", ResetStatsButton, -1, 1)
	ResetStatsButton.Tex:SetTexture(Texture)
	ResetStatsButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	ResetStatsButton.Label = ResetStatsButton:CreateFontString(nil, "OVERLAY")
	ResetStatsButton.Label:SetPoint("CENTER", ResetStatsButton, 0.5, -0.5)
	ResetStatsButton.Label:SetFont(Font, 14)
	ResetStatsButton.Label:SetText("Reset Stats")
	ResetStatsButton.Label:SetShadowColor(0, 0, 0)
	ResetStatsButton.Label:SetShadowOffset(1, -1)
	
	-- Enter User
	EnterUserButton = CreateFrame("Frame", nil, vGamblerFrame)
	EnterUserButton:SetPoint("TOPLEFT", SetChannelButton, "TOPRIGHT", 3, 0)
	EnterUserButton:SetSize(100, 22)
	EnterUserButton:SetBackdrop(Backdrop)
	EnterUserButton:SetBackdropColor(0.22, 0.22, 0.22)
	EnterUserButton:SetBackdropBorderColor(0, 0, 0)
	EnterUserButton:SetScript("OnMouseUp", function(self)
		SendChatMessage("1", Channel)
		
		DisableButton(self)
		EnableButton(UserRollButton)
	end)
	EnterUserButton:SetScript("OnEnter", ButtonOnEnter)
	EnterUserButton:SetScript("OnLeave", ButtonOnLeave)
	
	EnterUserButton.Tex = EnterUserButton:CreateTexture(nil, "ARTWORK")
	EnterUserButton.Tex:SetPoint("TOPLEFT", EnterUserButton, 1, -1)
	EnterUserButton.Tex:SetPoint("BOTTOMRIGHT", EnterUserButton, -1, 1)
	EnterUserButton.Tex:SetTexture(Texture)
	EnterUserButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	EnterUserButton.Label = EnterUserButton:CreateFontString(nil, "OVERLAY")
	EnterUserButton.Label:SetPoint("CENTER", EnterUserButton, 0.5, -0.5)
	EnterUserButton.Label:SetFont(Font, 14)
	EnterUserButton.Label:SetText("Enter Self")
	EnterUserButton.Label:SetShadowColor(0, 0, 0)
	EnterUserButton.Label:SetShadowOffset(1, -1)
	
	-- User Roll
	UserRollButton = CreateFrame("Frame", nil, vGamblerFrame)
	UserRollButton:SetPoint("TOPLEFT", EnterUserButton, "BOTTOMLEFT", 0, -3)
	UserRollButton:SetSize(100, 22)
	UserRollButton:SetBackdrop(Backdrop)
	UserRollButton:SetBackdropColor(0.22, 0.22, 0.22)
	UserRollButton:SetBackdropBorderColor(0, 0, 0)
	UserRollButton:SetScript("OnMouseUp", function(self)
		RandomRoll(1, CurrentRollValue)
		
		if Locked then
			DisableButton(self)
		end
	end)
	UserRollButton:SetScript("OnEnter", ButtonOnEnter)
	UserRollButton:SetScript("OnLeave", ButtonOnLeave)
	
	UserRollButton.Tex = UserRollButton:CreateTexture(nil, "ARTWORK")
	UserRollButton.Tex:SetPoint("TOPLEFT", UserRollButton, 1, -1)
	UserRollButton.Tex:SetPoint("BOTTOMRIGHT", UserRollButton, -1, 1)
	UserRollButton.Tex:SetTexture(Texture)
	UserRollButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	UserRollButton.Label = UserRollButton:CreateFontString(nil, "OVERLAY")
	UserRollButton.Label:SetPoint("CENTER", UserRollButton, 0.5, -0.5)
	UserRollButton.Label:SetFont(Font, 14)
	UserRollButton.Label:SetText("Self Roll")
	UserRollButton.Label:SetShadowColor(0, 0, 0)
	UserRollButton.Label:SetShadowOffset(1, -1)
	
	-- Ban List
	BanListButton = CreateFrame("Frame", nil, vGamblerFrame)
	BanListButton:SetPoint("TOPLEFT", UserRollButton, "BOTTOMLEFT", 0, -3)
	BanListButton:SetSize(100, 22)
	BanListButton:SetBackdrop(Backdrop)
	BanListButton:SetBackdropColor(0.22, 0.22, 0.22)
	BanListButton:SetBackdropBorderColor(0, 0, 0)
	BanListButton:SetScript("OnMouseUp", function()
		if (not vGamblerBanList) then
			print("No players are banned.")
			
			return
		end
		
		for name, reason in pairs(vGamblerBanList) do
			if (reason == true) then
				print(name)
			else
				print(format("%s (Reason: %s)", name, reason))
			end
		end
	end)
	BanListButton:SetScript("OnEnter", ButtonOnEnter)
	BanListButton:SetScript("OnLeave", ButtonOnLeave)
	
	BanListButton.Tex = BanListButton:CreateTexture(nil, "ARTWORK")
	BanListButton.Tex:SetPoint("TOPLEFT", BanListButton, 1, -1)
	BanListButton.Tex:SetPoint("BOTTOMRIGHT", BanListButton, -1, 1)
	BanListButton.Tex:SetTexture(Texture)
	BanListButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	BanListButton.Label = BanListButton:CreateFontString(nil, "OVERLAY")
	BanListButton.Label:SetPoint("CENTER", BanListButton, 0.5, -0.5)
	BanListButton.Label:SetFont(Font, 14)
	BanListButton.Label:SetText("Ban List")
	BanListButton.Label:SetShadowColor(0, 0, 0)
	BanListButton.Label:SetShadowOffset(1, -1)
	
	-- Reset Ban List
	ResetBanListButton = CreateFrame("Frame", nil, vGamblerFrame)
	ResetBanListButton:SetPoint("TOPLEFT", BanListButton, "BOTTOMLEFT", 0, -3)
	ResetBanListButton:SetSize(100, 22)
	ResetBanListButton:SetBackdrop(Backdrop)
	ResetBanListButton:SetBackdropColor(0.22, 0.22, 0.22)
	ResetBanListButton:SetBackdropBorderColor(0, 0, 0)
	ResetBanListButton:SetScript("OnMouseUp", ResetBans)
	ResetBanListButton:SetScript("OnEnter", ButtonOnEnter)
	ResetBanListButton:SetScript("OnLeave", ButtonOnLeave)
	
	ResetBanListButton.Tex = ResetBanListButton:CreateTexture(nil, "ARTWORK")
	ResetBanListButton.Tex:SetPoint("TOPLEFT", ResetBanListButton, 1, -1)
	ResetBanListButton.Tex:SetPoint("BOTTOMRIGHT", ResetBanListButton, -1, 1)
	ResetBanListButton.Tex:SetTexture(Texture)
	ResetBanListButton.Tex:SetVertexColor(0.27, 0.27, 0.27)
	
	ResetBanListButton.Label = ResetBanListButton:CreateFontString(nil, "OVERLAY")
	ResetBanListButton.Label:SetPoint("CENTER", ResetBanListButton, 0.5, -0.5)
	ResetBanListButton.Label:SetFont(Font, 14)
	ResetBanListButton.Label:SetText("Reset Ban List")
	ResetBanListButton.Label:SetShadowColor(0, 0, 0)
	ResetBanListButton.Label:SetShadowOffset(1, -1)
	
	DisableButton(LastCallButton)
	DisableButton(RollButton)
	DisableButton(ResetGameButton)
	DisableButton(EnterUserButton)
	DisableButton(UserRollButton)
end

-- Commands
local CmdSplit = function(cmd)
	if strfind(cmd, "%s") then
		return strsplit(" ", cmd)
	else
		return cmd
	end
end

local CmdList = {
	["stats"] = function(name)
		PostStats(name)
	end,
	
	["unban"] = function(name)
		UnbanPlayer(name)
	end,
	
	["resetbans"] = function()
		ResetBans()
	end,
	
	["show"] = function()
		if (not vGamblerFrame) then
			CreateGamblerFrame()
		end
		
		vGamblerFrame:Show()
	end,
	
	["hide"] = function()
		vGamblerFrame:Hide()
	end,
}

SLASH_VGAMBLER1 = "/vg"
SlashCmdList["VGAMBLER"] = function(cmd)
	local arg1, arg2 = CmdSplit(cmd)
	
	if CmdList[arg1] then
		CmdList[arg1](arg2)
	elseif (arg1 == "ban") then
		local Start, Stop = strfind(cmd, arg2)
		local Reason = strsub(cmd, Stop + 2, strlen(cmd))
		
		if (Reason and Reason ~= "") then
			BanPlayer(arg2, Reason)
		else
			BanPlayer(arg2, true)
		end
	end
end

function DataObject:OnClick(button)
	if (not vGamblerFrame) then
		CreateGamblerFrame()
		
		return
	end
	
	if (not vGamblerFrame:IsShown()) then
		vGamblerFrame:Show()
	else
		vGamblerFrame:Hide()
	end
end

function DataObject:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	
	GameTooltip:AddLine("vGambler", 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Click to toggle")
	
	GameTooltip:Show()
end

function DataObject:OnLeave()
	GameTooltip:Hide()
end

local WhisperFrame = CreateFrame("Frame")
WhisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
WhisperFrame:SetScript("OnEvent", function(self, event, msg, sender)
	if (msg == "!stats") then
		PostStats(nil, "WHISPER", sender)
	elseif (msg == "!stats me") then
		local Name = split("-", sender)
		
		PostStats(Name, "WHISPER", sender)
	elseif strfind(msg, "!stats %a+") then
		local Name = strmatch(msg, "!stats (%a+)")
		
		if Name then
			PostStats(Name, "WHISPER", sender)
		end
	end
end)