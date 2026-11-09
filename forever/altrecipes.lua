local name, data = ...
local Main = LibStub("AceAddon-3.0"):GetAddon("HandyNotes_NPCs (Classic)")
local Addon = Main:NewModule("AltRecipes", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("HandyNotes_NPCs (Classic)")

local teachesToItemID = { }
do
	for k, v in pairs(data["items"]) do
		if v.teaches then
			teachesToItemID[v.teaches] = k
		end
	end
end

function Addon:OnInitialize()
	local defaults = {
		realm = {
			['*'] = {
				professions = {
					['*'] = nil,
				},
				learned = {
					['*'] = nil,
				},
			},
		},
	}
	
	self.db = Main.db:RegisterNamespace("AltRecipes", defaults)
	self:SetEnabledState(Main.db.profile.showAltRecipes)
end

function Addon:OnEnable()
	self.playerName = UnitName("player")
	self.playerGUID = UnitGUID("player")

	if self.playerName and self.playerGUID then
		local data = self.db.realm[self.playerName]

		if data then
			if not data.GUID or data.GUID ~= self.playerGUID then
				self.db.realm[self.playerName] = { professions = {}, learned = {} }
        end

        self.db.realm[self.playerName].GUID = self.playerGUID
		end
	end
	
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED")
	self:RegisterEvent("SKILL_LINES_CHANGED")
	self:RegisterEvent("TRADE_SKILL_SHOW", "ScanTradeSkill") -- GetNumTradeSkills usually returns 0 here
	self:RegisterEvent("TRADE_SKILL_CLOSE", "ScanTradeSkill") -- Just try on both
	self:RegisterEvent("TRADE_SKILL_LIST_UPDATE", "ScanTradeSkill")
	
	local function CheckIfLearned(tooltip, tData)
		if not tData or not tData.id then return end

		local tooltipInfo = tooltip:GetProcessingTooltipInfo()
		
		local itemID = tData.id
		if not data["items"][itemID] or not data["items"][itemID].profession then return end
		--tooltip:AddLine("Checking if learned")
		for k, v in pairs(self.db.realm) do -- Look through all the alts on realm
			if v.professions[data["items"][itemID].profession] then-- We have the profession
				tooltip:AddLine("We have the profession")
				--if not lineAdded then tooltip:AddLine('\n') lineAdded = true end
				if v.learned[itemID] then
					tooltip:AddLine(L["Already learned by"] .. ": " .. k, 1, 0, 0)
				else
					if v.professions[data["items"][itemID].profession] >= data["items"][itemID].learnedAt then
						tooltip:AddLine(L["Could be learned by"] .. ": " .. k, 0, 1, 0) -- TODO Localize
					else
						tooltip:AddLine(L["Will be learnable by"] .. ": " .. k .. ' (' .. tostring(v.professions[data["items"][itemID].profession]) .. ')', .5, .5, 0)
					end
				end
			end
		end
	end
	
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, CheckIfLearned)
end

function Addon:OnDisable()
	self:UnregisterAllEvents()
	self:UnhookAll()
end

function Addon:Toggle()
	if Main.db.profile.showAltRecipes then
		self:Enable()
	else
		self:Disable()
	end
end

function Addon:SKILL_LINES_CHANGED() -- We do this in the main part too but seems easier to just leave it here also
	table.wipe(self.db.realm[self.playerName].professions)
	
	for i = 1, C_SkillInfo.GetNumSkillLines() do
		--local skillName, _, _, skillLevel = GetSkillLineInfo(i)
		local skillAttributes = C_SkillInfo.GetSkillLineInfo(i)
		local skillName = skillAttributes['name']
		local skillLevel = skillAttributes['rank']
		if Main.PROFESSIONS[skillName] then
			self.db.realm[self.playerName].professions[Main.PROFESSIONS[skillName]] = skillLevel
		end
	end
end

function Addon:ScanTradeSkill(event)
	if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE" then
		local baseProfessionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
		if baseProfessionInfo then
			--print(baseProfessionInfo.profession)
			local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
			
			for _, recipeID in ipairs(recipeIDs) do
				local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
				
				if recipeInfo then
					local name = recipeInfo.name
					local icon = recipeInfo.icon
					local originalCraftable = recipeInfo.numAvailable -- How many you can make
					local isHeader = recipeInfo.isHeader
					if not isHeader and teachesToItemID[name] then
						self.db.realm[self.playerName].learned[teachesToItemID[name]] = recipeInfo.learned
					end
					
				end
			end
		end
	end
end