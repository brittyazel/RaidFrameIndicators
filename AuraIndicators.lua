--Enhanced Raid Frames, a World of Warcraft® user interface addon.

--This file is part of Enhanced Raid Frames.
--
--Enhanced Raid Frame is free software: you can redistribute it and/or modify
--it under the terms of the GNU General Public License as published by
--the Free Software Foundation, either version 3 of the License, or
--(at your option) any later version.
--
--Enhanced Raid Frame is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
--GNU General Public License for more details.
--
--You should have received a copy of the GNU General Public License
--along with this add-on.  If not, see <https://www.gnu.org/licenses/>.
--
--Copyright for portions of Neuron are held in the public domain,
--as determined by Szandos. All other copyrights for
--Enhanced Raid Frame are held by Britt Yazel, 2017-2019.


local EnhancedRaidFrames = EnhancedRaidFrames_Global

local media = LibStub:GetLibrary("LibSharedMedia-3.0")
local f = {} -- Indicators for the frames
local PAD = 2
local unitBuffs = {} -- Matrix to keep a list of all buffs on all units
local unitDebuffs = {} -- Matrix to keep a list of all debuffs on all units


-------------------------------------------------------------------------
-------------------------------------------------------------------------

function EnhancedRaidFrames:SetStockIndicatorVisibility(frame)

	if not EnhancedRaidFrames.db.profile.showBuffs then
		CompactUnitFrame_HideAllBuffs(frame)
	end

	if not EnhancedRaidFrames.db.profile.showDebuffs then
		CompactUnitFrame_HideAllDebuffs(frame)
	end

	if not EnhancedRaidFrames.db.profile.showDispelDebuffs then
		CompactUnitFrame_HideAllDispelDebuffs(frame)
	end

end


-- Create the FontStrings used for indicators
function EnhancedRaidFrames:CreateIndicators(frame)
	local frameName = frame:GetName()

	f[frameName] = {}

	-- Create indicators
	for i = 1, 9 do
		--We have to use this template to allow for our clicks to be passed through, otherwise our frames won't allow selecting the raidframe behind it
		f[frameName][i] = CreateFrame("Button", nil, frame, "CompactAuraTemplate")

		f[frameName][i].text = f[frameName][i]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		f[frameName][i].icon = f[frameName][i]:CreateTexture(nil, "OVERLAY")

		f[frameName][i].text:SetPoint("CENTER", f[frameName][i], "CENTER", 0, 0)
		f[frameName][i].icon:SetPoint("CENTER", f[frameName][i], "CENTER", 0, 0)

		f[frameName][i]:SetFrameStrata("HIGH")
		f[frameName][i]:RegisterForClicks("LeftButtonDown", "RightButtonUp");
		--f[frameName][i]:Hide()

		if i == 1 then
			f[frameName][i]:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
		elseif i == 2 then
			f[frameName][i]:SetPoint("TOP", frame, "TOP", 0, -PAD)
		elseif i == 3 then
			f[frameName][i]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -PAD)
		elseif i == 4 then
			f[frameName][i]:SetPoint("LEFT", frame, "LEFT", PAD, 0)
		elseif i == 5 then
			f[frameName][i]:SetPoint("CENTER", frame, "CENTER", 0, 0)
		elseif i == 6 then
			f[frameName][i]:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
		elseif i == 7 then
			f[frameName][i]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
		elseif i == 8 then
			f[frameName][i]:SetPoint("BOTTOM", frame, "BOTTOM", 0, PAD)
		elseif i == 9 then
			f[frameName][i]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
		end

		-- hook enter and leave for showing ability tooltips
		EnhancedRaidFrames:SecureHookScript(f[frameName][i], "OnEnter", function() EnhancedRaidFrames:Tooltip_OnEnter(f[frameName][i]) end)
		EnhancedRaidFrames:SecureHookScript(f[frameName][i], "OnLeave", function() EnhancedRaidFrames:Tooltip_OnLeave(f[frameName][i]) end)
	end

	-- Set appearance
	EnhancedRaidFrames:SetIndicatorAppearance(frame)
end


-- Set the appearance of the FontStrings
function EnhancedRaidFrames:SetIndicatorAppearance(frame)
	local unit = frame.unit
	local frameName = frame:GetName()

	-- Check if the frame is pointing at anything
	if not unit then return end
	if not f[frameName] then return end

	local font = media and media:Fetch('font', EnhancedRaidFrames.db.profile.indicatorFont) or STANDARD_TEXT_FONT

	for i = 1, 9 do
		f[frameName][i]:SetWidth(EnhancedRaidFrames.db.profile["iconSize"..i])
		f[frameName][i]:SetHeight(EnhancedRaidFrames.db.profile["iconSize"..i])
		f[frameName][i].icon:SetWidth(EnhancedRaidFrames.db.profile["iconSize"..i])
		f[frameName][i].icon:SetHeight(EnhancedRaidFrames.db.profile["iconSize"..i])

		f[frameName][i].text:SetFont(font, EnhancedRaidFrames.db.profile["size"..i], "OUTLINE")
		f[frameName][i].text:SetTextColor(EnhancedRaidFrames.db.profile["color"..i].r, EnhancedRaidFrames.db.profile["color"..i].g, EnhancedRaidFrames.db.profile["color"..i].b, EnhancedRaidFrames.db.profile["color"..i].a)

		if EnhancedRaidFrames.db.profile["showIcon"..i] then
			f[frameName][i].icon:Show()
		else
			f[frameName][i].icon:Hide()
		end
	end
end


-- Check the indicators on a frame and update the times on them
function EnhancedRaidFrames:UpdateIndicators(frame)
	local unit = frame.unit

	--check to see if the bar is even targeting a unit, bail if it isn't
	--also, tanks have two bars below their frame that have a frame.unit that ends in "target" and "targettarget".
	--Normal raid members have frame.unit that says "Raid1", "Raid5", etc.
	--We don't want to put icons over these tiny little target and target of target bars
	--Also, in 8.2.5 blizzard unified the nameplate code with the raid frame code. Don't display icons on nameplates
	if not unit or string.find(unit, "target") or string.find(unit, "nameplate") then
		return
	end

	EnhancedRaidFrames:SetStockIndicatorVisibility(frame)

	local currentTime = GetTime()
	local frameName = frame:GetName()

	-- Check if the indicator frame exists, else create it
	if not f[frameName] then
		EnhancedRaidFrames:CreateIndicators(frame)
	end

	-- Update unit auras
	EnhancedRaidFrames:UpdateUnitAuras(unit)

	-- Loop over the indicators and see if we get a hit
	for i = 1, 9 do
		local remainingTime, remainingTimeAsText, count, duration, expirationTime, castBy, icon, debuffType, n

		remainingTimeAsText = ""
		icon = ""
		count = 0
		duration = 0
		expirationTime = 0
		castBy = ""

		-- Check if unit is alive/connected
		if (not UnitIsConnected(unit)) or UnitIsDeadOrGhost(frame.displayedUnit) then
			f[frameName][i]:Hide() --if the unit isn't connected or is dead, hide the indicators and break out of the loop
			break
		end

		-- If we only are to show the indicator on me, then don't bother if I'm not the unit
		if EnhancedRaidFrames.db.profile["me"..i] then
			local uName, uRealm = UnitName(unit)
			if uName ~= UnitName("player") or uRealm ~= nil then
				break
			end
		end

		-- Go through the aura strings
		for _, auraName in ipairs(EnhancedRaidFrames.auraStrings[i]) do -- Grab each line

			if not auraName then --if there's no auraName (i.e. the user never specified anything to go in this spot), stop here there's no need to keep going
				break
			end

			-- Check if the aura exist on the unit
			for j = 1, unitBuffs[unit].len do -- Check buffs
				if tonumber(auraName) then  -- Use spell id
					if unitBuffs[unit][j].spellId == tonumber(auraName) then n = j end
				elseif unitBuffs[unit][j].auraName == auraName then -- Hit on auraName
					n = j
				end
				if n and unitBuffs[unit][j].castBy == "player" then
					break
				end -- Keep looking if it's not cast by the player
			end
			if n then
				count = unitBuffs[unit][n].count
				duration = unitBuffs[unit][n].duration
				expirationTime = unitBuffs[unit][n].expirationTime
				castBy = unitBuffs[unit][n].castBy
				icon = unitBuffs[unit][n].icon
				f[frameName][i].index = unitBuffs[unit][n].index
				f[frameName][i].buff = true
			else
				for j = 1, unitDebuffs[unit].len do -- Check debuffs
					if tonumber(auraName) then  -- Use spell id
						if unitDebuffs[unit][j].spellId == tonumber(auraName) then n = j end
					elseif unitDebuffs[unit][j].auraName == auraName then -- Hit on auraName
						n = j
					elseif unitDebuffs[unit][j].debuffType == auraName then -- Hit on debufftype
						n = j
					end
					if n and unitDebuffs[unit][j].castBy == "player" then
						break
					end -- Keep looking if it's not cast by the player
				end
				if n then
					count = unitDebuffs[unit][n].count
					duration = unitDebuffs[unit][n].duration
					expirationTime = unitDebuffs[unit][n].expirationTime
					castBy = unitDebuffs[unit][n].castBy
					icon = unitDebuffs[unit][n].icon
					debuffType = unitDebuffs[unit][n].debuffType
					f[frameName][i].index = unitDebuffs[unit][n].index
				end
			end
			if auraName:upper() == "PVP" then -- Check if we want to show pvp flag
				if UnitIsPVP(unit) then
					count = 0
					expirationTime = 0
					duration = 0
					castBy = "player"
					n = -1
					local factionGroup = UnitFactionGroup(unit)
					if factionGroup then icon = "Interface\\GroupFrame\\UI-Group-PVP-"..factionGroup end
					f[frameName][i].index = -1
				end
			elseif auraName:upper() == "TOT" then -- Check if we want to show ToT flag
				if UnitIsUnit (unit, "targettarget") then
					count = 0
					expirationTime = 0
					duration = 0
					castBy = "player"
					n = -1
					icon = "Interface\\Icons\\Ability_Hunter_SniperShot"
					f[frameName][i].index = -1
				end
			end

			if n then -- We found a matching spell
				-- If we only are to show spells cast by me, make sure the spell is
				if (EnhancedRaidFrames.db.profile["mine"..i] and castBy ~= "player") then
					n = nil
					icon = ""
				else
					if not EnhancedRaidFrames.db.profile["showIcon"..i] then icon = "" end -- Hide icon
					if expirationTime == 0 then -- No expiration time = permanent
						if not EnhancedRaidFrames.db.profile["showIcon"..i] then
							remainingTimeAsText = "■" -- Only show the blob if we don't show the icon
						end
					else
						if EnhancedRaidFrames.db.profile["showText"..i] then
							-- Pretty formating of the remaining time text
							remainingTime = expirationTime - currentTime
							if remainingTime > 60 then
								remainingTimeAsText = string.format("%.0f", (remainingTime / 60)).."m" -- Show minutes without seconds
							elseif remainingTime >= 1 then
								remainingTimeAsText = string.format("%.0f",remainingTime) -- Show seconds without decimals
							end
						else
							remainingTimeAsText = ""
						end

					end

					-- Add stack count
					if EnhancedRaidFrames.db.profile["stack"..i] and count > 0 then
						if EnhancedRaidFrames.db.profile["showText"..i] and expirationTime > 0 then
							remainingTimeAsText = count.."-"..remainingTimeAsText
						else
							remainingTimeAsText = count
						end
					end

					-- Set color
					if EnhancedRaidFrames.db.profile["stackColor"..i] then -- Color by stack
						if count == 1 then
							f[frameName][i].text:SetTextColor(1,0,0,1)
						elseif count == 2 then
							f[frameName][i].text:SetTextColor(1,1,0,1)
						else
							f[frameName][i].text:SetTextColor(0,1,0,1)
						end
					elseif EnhancedRaidFrames.db.profile["debuffColor"..i] then -- Color by debuff type
						if debuffType then
							if debuffType == "Curse" then
								f[frameName][i].text:SetTextColor(0.6,0,1,1)
							elseif debuffType == "Disease" then
								f[frameName][i].text:SetTextColor(0.6,0.4,0,1)
							elseif debuffType == "Magic" then
								f[frameName][i].text:SetTextColor(0.2,0.6,1,1)
							elseif debuffType == "Poison" then
								f[frameName][i].text:SetTextColor(0,0.6,0,1)
							end
						end
					elseif EnhancedRaidFrames.db.profile["colorByTime"..i] then -- Color by remaining time
						if remainingTime and remainingTime < 3 then
							f[frameName][i].text:SetTextColor(1,0,0,1)
						elseif remainingTime and remainingTime < 5 then
							f[frameName][i].text:SetTextColor(1,1,0,1)
						else
							f[frameName][i].text:SetTextColor(EnhancedRaidFrames.db.profile["color"..i].r, EnhancedRaidFrames.db.profile["color"..i].g, EnhancedRaidFrames.db.profile["color"..i].b, EnhancedRaidFrames.db.profile["color"..i].a)
						end
					end

					break -- We found a match, so no need to continue the for loop
				end
			end
		end

		-- Only show when it's missing?
		if EnhancedRaidFrames.db.profile["missing"..i] then
			icon = ""
			remainingTimeAsText = ""
			if not n then -- No n means we didn't find the spell
				remainingTimeAsText = "■"
			end
		end



		if icon ~= "" or remainingTimeAsText ~="" then
			-- show the frame
			f[frameName][i]:Show()
			-- Show the text
			f[frameName][i].text:SetText(remainingTimeAsText)
			-- Show the icon
			f[frameName][i].icon:SetTexture(icon)
		else
			-- hide the frame
			f[frameName][i]:Hide()
		end

		--set cooldown animation
		if EnhancedRaidFrames.db.profile["showCooldownAnimation"..i] and icon~="" and expirationTime and expirationTime ~= 0 then
			CooldownFrame_Set(f[frameName][i].cooldown, expirationTime - duration, duration, true, true)
		else
			CooldownFrame_Clear(f[frameName][i].cooldown);
		end


	end

end


-- Get all unit auras
function EnhancedRaidFrames:UpdateUnitAuras(unit)

	-- Create tables for the unit
	if not unitBuffs[unit] then unitBuffs[unit] = {} end
	if not unitDebuffs[unit] then unitDebuffs[unit] = {} end

	-- Get all unit buffs
	local auraName, icon, count, duration, expirationTime, castBy, debuffType, spellId
	local i = 1
	local j = 1

	while true do
		auraName, icon, count, _, duration, expirationTime, castBy, _, _, spellId = UnitBuff(unit, i)

		if not spellId then
			break
		end

		if string.find(EnhancedRaidFrames.allAuras, "+"..auraName.."+") or string.find(EnhancedRaidFrames.allAuras, "+"..spellId.."+") then -- Only add the spell if we're watching for it
			if not unitBuffs[unit][j] then unitBuffs[unit][j] = {} end
			unitBuffs[unit][j].auraName = auraName
			unitBuffs[unit][j].spellId = spellId
			unitBuffs[unit][j].count = count
			unitBuffs[unit][j].duration = duration
			unitBuffs[unit][j].expirationTime = expirationTime
			unitBuffs[unit][j].castBy = castBy
			unitBuffs[unit][j].icon = icon
			unitBuffs[unit][j].index = i
			j = j + 1
		end
		i = i + 1
	end
	unitBuffs[unit].len = j -1

	-- Get all unit debuffs
	i = 1
	j = 1
	while true do
		auraName, icon, count, debuffType, duration, expirationTime, castBy, _, _, spellId  = UnitDebuff(unit, i)

		if not spellId then
			break
		end

		if string.find(EnhancedRaidFrames.allAuras, "+"..auraName.."+") or string.find(EnhancedRaidFrames.allAuras, "+"..spellId.."+") or string.find(EnhancedRaidFrames.allAuras, "+"..tostring(debuffType).."+") then -- Only add the spell if we're watching for it
			if not unitDebuffs[unit][j] then unitDebuffs[unit][j] = {} end
			unitDebuffs[unit][j].auraName = auraName
			unitDebuffs[unit][j].spellId = spellId
			unitDebuffs[unit][j].count = count
			unitDebuffs[unit][j].duration = duration
			unitDebuffs[unit][j].expirationTime = expirationTime
			unitDebuffs[unit][j].castBy = castBy
			unitDebuffs[unit][j].icon = icon
			unitDebuffs[unit][j].index = i
			unitDebuffs[unit][j].debuffType= debuffType
			j = j + 1
		end
		i = i + 1
	end
	unitDebuffs[unit].len = j -1
end



-------------------------------
---Tooltip Code
-------------------------------
function EnhancedRaidFrames:Tooltip_OnEnter(buffFrame)

	if not EnhancedRaidFrames.db.profile.showTooltips then --don't show tooltips unless we have the option set
		return
	end

	local frame = buffFrame:GetParent() --this is the parent raid frame that holds all the buffFrames
	local index = buffFrame.index
	local buff = buffFrame.buff

	local displayedUnit = frame.displayedUnit

	-- Set the tooltip
	if index and index ~= -1 and buffFrame.icon:GetTexture() then -- -1 is the pvp icon, no tooltip for that
		-- Set the buff/debuff as tooltip and anchor to the cursor
		GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
		if buff then
			GameTooltip:SetUnitBuff(displayedUnit, index)
		else
			GameTooltip:SetUnitDebuff(displayedUnit, index)
		end
	else
		--causes the tooltip to reset to the "default" tooltip which is usually information about the character
		if frame then
			UnitFrame_UpdateTooltip(frame)
		end
	end

	GameTooltip:Show()
end


function EnhancedRaidFrames:Tooltip_OnLeave(buffFrame)

	if not EnhancedRaidFrames.db.profile.showTooltips then --don't show tooltips unless we have the option set
		return
	end

	GameTooltip:Hide()
end