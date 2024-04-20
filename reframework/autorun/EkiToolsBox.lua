local Mod = {
	Info = {
		Name = "EkiToolsBox",
		Version = "0.4.4",
		Contributors = "Ekibunnel",
		Source = "https://github.com/Ekibunnel/DD2-EkiToolsBox"
	},
	Cfg = {
		Debug = false,
		DrawWindow = nil,
		IgnoreReframeworkDrawUI = false,
		InfStamina = 1,
		InfLanternOil = false,
		InfCarryTime = 1
	},
	Variable = {
		TicksToWait = 70,
		DefaultFurMaskMapHand = 0.05,
		DefaultConsumeOilSecSpeed = 0.0125,
		BackupConsumeOilSecSpeed = nil
	},
	Presets = {}
}

--- UTILS

local function StrToHex(String)
	local StrToHex = ""
	for i = 1, #String do
        local char = string.sub(String, i, i)
        StrToHex = StrToHex..string.format("%02X", string.byte(char))
    end
	return StrToHex
end

local function RoundNumber(Num, Precision)
	local FormatPrecision = 2
	if Precision ~= nil then FormatPrecision = Precision end
	local FormatString = "%."..FormatPrecision.."f"
	return tonumber(string.format(FormatString, Num))
end

local function ClearLogFile()
	if Mod.Cfg.Debug then
		local Logfile = io.open(Mod.Info.Name.."\\"..Mod.Info.Name..".log", "w")
		Logfile:write("--- "..Mod.Info.Name.." v"..Mod.Info.Version.." Debug:"..tostring(Mod.Cfg.Debug).." ("..os.date("%x-%X")..") ---\n")
		Logfile:close()
	end
end

local ScriptStartTime = os.clock()
local function DebugLog(String, UseGlobalTime)
	if Mod.Cfg.Debug then
		local LogTime = nil
		if UseGlobalTime == true or ScriptStartTime == nil then
			LogTime = os.clock()
		else
			LogTime = os.clock() - ScriptStartTime
		end
		local DebugString = "["..Mod.Info.Name.."]["..string.format("%09.3f", LogTime).."] "..tostring(String)
		log.debug(DebugString)
		local Logfile = io.open(Mod.Info.Name.."\\"..Mod.Info.Name..".log", "a")
		Logfile:write(DebugString.."\n")
		Logfile:close()
	end
end

local function LoadCfg()
	local jsonCfg = json.load_file(Mod.Info.Name.."\\"..Mod.Info.Name..".config.json")
	if jsonCfg ~= nil then
		for k,v in pairs(jsonCfg) do
			if Mod.Cfg[k] ~= nil then
				Mod.Cfg[k] = v
			end
		end
		DebugLog("LoadCfg from file : "..json.dump_string(Mod.Cfg, 4))
		return true
	end
	DebugLog("LoadCfg default : "..json.dump_string(Mod.Cfg, 4))
	return false
end

local function SaveCfg()
	DebugLog("SaveCfg : "..json.dump_string(Mod.Cfg, 4))
	return json.dump_file(Mod.Info.Name.."\\"..Mod.Info.Name..".config.json", Mod.Cfg)
end

local function LoadPreset(Name, Meta)
	local PresetName = "pawn"
	if Name == "Arisen" or Name == "MainPawn" then
		PresetName = string.lower(Name)
	elseif Name == nil then
		PresetName = "global"
	end
	local MetaString = ""
	if Meta ~= nil then
		if Meta._Name ~= nil and Meta._Nickname ~= nil then
			MetaString = "."..string.lower(Meta._Nickname).."."..StrToHex(Meta._Name)
		end
	end
	local jsonPreset = json.load_file(Mod.Info.Name.."\\"..Mod.Info.Name..".preset."..PresetName..MetaString..".json")
	if jsonPreset ~= nil then
		for k,v in pairs(jsonPreset) do
			if Mod.Presets[Name][k] ~= nil then
				Mod.Presets[Name][k] = v
			end
		end
		DebugLog("LoadPreset from file : "..json.dump_string(Mod.Presets[Name], 4))
		return true
	end
	return false
end

local function SavePreset(Name, Meta)
	local PresetName = "pawn"
	if Name == "Arisen" or Name == "MainPawn" then
		PresetName = string.lower(Name)
	elseif Name == nil then
		PresetName = "global"
	end
	local MetaString = ""
	if Meta ~= nil then
		if Meta._Name ~= nil and Meta._Nickname ~= nil then
			MetaString = "."..string.lower(Meta._Nickname).."."..StrToHex(Meta._Name)
		end
	end
	DebugLog("SavePreset : "..json.dump_string(Mod.Presets[Name], 4))
	return json.dump_file(Mod.Info.Name.."\\"..Mod.Info.Name..".preset."..PresetName..MetaString..".json", Mod.Presets[Name])
end

local function GetChildsFromTransform(Transform, ChildGameObjectName)
	--- Original function provided by alphaZomega
    local children = {}
    local child = Transform:call("get_Child")
    while child do
		if ChildGameObjectName ~= nil and child:get_GameObject():get_Name() == ChildGameObjectName then
			return child
		end
        table.insert(children, child)
        child = child:call("get_Next")
    end
	if ChildGameObjectName == nil then
		return children[1] and children
	end
    return nil
end

local function ExtractEnum(Typename, Field)
    local t = sdk.find_type_definition(Typename)
    if not t then return {} end

    local fields = t:get_fields()
    local enum = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = tostring(field:get_name())
            local raw_value = field:get_data(nil)

            DebugLog("Enum "..Typename.." : "..name .. " = " .. tostring(raw_value))
			if Field ~= nil then
				if type(Field) == "string" then
					if Field == name then
						return raw_value
					end
				else
					if Field == raw_value then
						return name
					end
				end
			else
				enum[i] = { [1] = name, [2] = raw_value }
			end
        end
    end
    return enum
end

local function InitTableFromEnum(Enum)
    local Table = {}
    for k, v in pairs(Enum) do
		Table[k] = nil
    end
    return Table
end

--- INIT

local ExtractedEnums = {}
ExtractedEnums["PawnID"] = ExtractEnum("app.PawnManager.PawnID")
ExtractedEnums["SwapObjects"] = ExtractEnum("app.charaedit.ch000.Define.SwapObjects")

LoadCfg()
SaveCfg()

ClearLogFile()

DebugLog("- START OF FILE -")

local ModCharaId = {
	Arisen = 1,
	[1] = "Arisen"
}

local Characters = {
	[1] = {
		Name = "Arisen",
		Meta = { _Name = nil, _Nickname = nil, NameAndNickString = "" },
		PawnID = nil,
		GameObject = nil,
		Mesh = nil,
		Human = nil,
		LanternController = nil,
		LanternMesh = nil,
		Character = nil,
		HideSwapObjects = nil,
		CaughtController = nil,
		PartSwapper = nil,
		PartSwapItem = {}
	}
}

local ManagedSingleton = { CharacterManager = nil, BattleManager = nil, PawnManager = nil }

local TickCounter = 0
local OnTickCounterZero = {
	DoSetupPawns = nil,
	DoForceUpdateAll = nil,
	DoSetupLantern = nil
}

--- MAIN

-- hook_vtable

function HookCharacterOnDestroy(NameOrIndex)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex].Character == nil then
		DebugLog("HookCharacterOnDestroy Character is null, aborting!")
		return false
	end
	sdk.hook_vtable(
		Characters[NewIndex].Character, Characters[NewIndex].Character:get_type_definition():get_method("onDestroy"),
		function(args) end,
		function(retval)
			Characters[NewIndex].GameObject = nil --This will recall Setup and clean the whole Characters Table
			DebugLog("Characters["..NewIndex.."] onDestroy called !")
			return retval
		end
	)
	DebugLog("HookCharacterOnDestroy Characters["..ModCharaId[NewIndex].."] onDestroy is hooked !")
	return true
end

local function HookPartSwapperHideSwapObjects(NameOrIndex)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex].PartSwapper == nil then
		DebugLog("HookPartSwapperHideSwapObjects PartSwapper is null, aborting!")
		return false
	end
	sdk.hook_vtable(
		Characters[NewIndex].PartSwapper, Characters[NewIndex].PartSwapper:get_type_definition():get_method("get_HideSwapObjects"),
		function(args) end,
		function(retval)
			if Characters[NewIndex].HideSwapObjects ~= nil then
				--DebugLog("HookPartSwapperHideSwapObjects PartSwapper get_HideSwapObjects for "..ModCharaId[NewIndex].." spoofed!") --spam
				return sdk.to_ptr(Characters[NewIndex].HideSwapObjects)
			end
			return retval
		end
	)
	DebugLog("HookPartSwapperHideSwapObjects PartSwapper get_HideSwapObjects is hooked for Characters["..ModCharaId[NewIndex].."] !")
	return true
end

-- Functions

local function InitCharactersTable(Name, Index)
	if Name == nil then
		DebugLog("InitCharactersTable failled Name arg is nil !")
		return nil
	end
	local NewIndex = nil
	if Index == nil then
		if ModCharaId[Name] == nil then
			if not (#Characters < #ModCharaId) then
				NewIndex = #Characters + 1
			else
				NewIndex = #ModCharaId + 1
			end
		else
			NewIndex = ModCharaId[Name]
		end
	else
		NewIndex = Index
	end
	if ModCharaId[NewIndex] == nil then
		ModCharaId[NewIndex] = Name
		ModCharaId[Name] = NewIndex
	end
	Characters[NewIndex] = {
		Name = Name,
		Meta = { _Name = nil, _Nickname = nil, NameAndNickString = "" },
		PawnID = nil,
		GameObject = nil,
		Mesh = nil,
		Human = nil,
		LanternController = nil,
		LanternMesh = nil,
		Character = nil,
		HideSwapObjects = nil,
		CaughtController = nil,
		PartSwapper = nil,
		PartSwapItem = {}
	}
	DebugLog("InitCharactersTable Characters["..NewIndex.."] ("..Name..") initialized")
	return NewIndex
end

local function InitCharactersTableWithModCharaId()
	local CleanTable = {}
	Characters = CleanTable
	for k, value in ipairs(ModCharaId) do
		if InitCharactersTable(value) == nil then
			DebugLog("InitCharactersTableWithModCharaId failed to init CharactersTable with "..tostring(value).." !")
			return false
		end
	end
	return true
end

local function InitPreset(Name)
	local DefaultPreset = {
		Fur_MaskMap_Hand = Mod.Variable.DefaultFurMaskMapHand,
		HideLantern = false,
		SwapObjectsToHide = InitTableFromEnum(ExtractedEnums.SwapObjects)
	}
	if Name ~= nil then
		Mod.Presets[Name] = DefaultPreset
	else
		return DefaultPreset
	end
end

local function LoadFromSavedPresets(NameOrIndex)
	local NewName = nil
	if type(NameOrIndex) == "string" then
		NewName = NameOrIndex
	else
		NewName = ModCharaId[NameOrIndex]
	end

	if Mod.Presets[NewName] == nil then InitPreset(NewName) end
	if LoadPreset(NewName, Characters[ModCharaId[NewName]].Meta) then
		return true
	end
	return false
end

local function SaveCurrentPreset(NameOrIndex)
	local NewName = nil
	if type(NameOrIndex) == "string" then
		NewName = NameOrIndex
	else
		NewName = ModCharaId[NameOrIndex]
	end

	if Mod.Presets[NewName] == nil then InitPreset(NewName) end
	if SavePreset(NewName, Characters[ModCharaId[NewName]].Meta) then
		return true
	end
	return false
end

local function UpdateAppSingleton(Name)
	local AppSingleton = sdk.get_managed_singleton('app.AppSingleton`1<app.'..Name..'>'):call('get_Instance')
	if AppSingleton ~= nil then
		ManagedSingleton[Name] = AppSingleton
		DebugLog("UpdateAppSingleton "..Name.." : "..tostring(AppSingleton).." @"..tostring(AppSingleton:get_address()))
		return true
	else
		DebugLog("UpdateAppSingleton "..Name.." is nil !")
	end
	return false
end

local function GetPlayerGameObject()
	if ManagedSingleton.CharacterManager == nil then UpdateAppSingleton("CharacterManager") end
	if ManagedSingleton.CharacterManager ~= nil then
		local ManualPlayer = ManagedSingleton.CharacterManager:get_ManualPlayer()
		if ManualPlayer == Characters[ModCharaId.Arisen].Character and ManualPlayer ~= nil then
			DebugLog("GetPLayerGameObject ManualPlayer the same as the one that called OnDestroy, aborting !")
		elseif ManualPlayer ~= nil then
			Characters[ModCharaId.Arisen].Character = ManualPlayer
			DebugLog("GetPLayerGameObject ManualPlayer get_ManualPlayer : "..tostring(ManualPlayer))
			local GameObjFromManualPlayer = ManualPlayer:get_GameObject()
			DebugLog("GetPLayerGameObject ManualPlayer get_GameObject : "..tostring(GameObjFromManualPlayer))
			return GameObjFromManualPlayer
		else
			DebugLog("GetPLayerGameObject ManualPlayer is nil aborting ")
		end
	else
		DebugLog("ManagedSingleton.CharacterManager is nil aborting ")
	end
	return nil
end

local function UpdatePlayerGameObject()
	local NewPlayerGameObject = GetPlayerGameObject()
	if NewPlayerGameObject ~= nil then
		Characters[ModCharaId.Arisen].GameObject = NewPlayerGameObject
		HookCharacterOnDestroy(ModCharaId.Arisen)
		return true
	end
	return false
end

local function ExtractComponentToCharacters(NameOrIndex, NameOfType)
	if NameOfType == nil then
		DebugLog("UpdateCharactersComponent NameOfType is nil !")
		return false
	end
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex].GameObject == nil then
		DebugLog("UpdateCharactersComponent Characters["..NewIndex.."] GameObject is nil, aborting !")
		return false
	end
	local NewComponent = Characters[NewIndex].GameObject:call("getComponent(System.Type)", sdk.typeof(NameOfType))
	if NewComponent ~= nil then
		local ComponentName = NewComponent:get_type_definition():get_name()
		DebugLog("UpdateCharactersComponent Characters["..NewIndex.."] Component "..ComponentName.." updated !")
		Characters[NewIndex][ComponentName] = NewComponent
		return true
	end
	DebugLog("UpdateCharactersComponent failled Characters["..NewIndex.."] GameObject not nil but has no "..NameOfType.." !")
	return false
end

local function UpdateLanternController(NameOrIndex)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex].Human == nil then
		DebugLog("UpdateLanternController Human is nil, aborting ! ")
	end
	local LanterController = Characters[NewIndex].Human:get_LanternCtrl()
	if LanterController ~= nil then
		DebugLog("UpdateLanternController Characters["..NewIndex.."] LanternController : "..tostring(LanterController))
		Characters[NewIndex].LanternController = LanterController
		return true
	end
	return false
end

local function UpdateMaterialFurMaskHand(NameOrIndex, Value)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex].Mesh == nil then
		DebugLog("UpdateMaterialFurMaskHand Mesh is nil, aborting !")
	end
	local MaterialNames = Characters[NewIndex].Mesh:get_MaterialNames()
	--DebugLog("UpdateMaterialFurMaskHand MaterialNames : "..tostring(MaterialNames))
	local IndexOfBodyMat = MaterialNames:IndexOf("body_mat")
	--DebugLog("UpdateMaterialFurMaskHand IndexOfBodyMat : "..tostring(IndexOfBodyMat))
	if IndexOfBodyMat < 0 then
		DebugLog("UpdateMaterialFurMaskHand IndexOfBodyMat is "..tostring(IndexOfBodyMat)..", aborting !")
		return false
	end
	local MaterialVariableNum = Characters[NewIndex].Mesh:getMaterialVariableNum(IndexOfBodyMat)
	for i = 0, MaterialVariableNum - 1 do
		local MaterialVariableName = Characters[NewIndex].Mesh:getMaterialVariableName(IndexOfBodyMat, i)

		--DebugLog("UpdateMaterialFurMaskHand MaterialVariableName : "..tostring(MaterialVariableName))

		if MaterialVariableName ~= nil then
			if MaterialVariableName == "Fur_MaskMap_Hand"then
				local NewFurMaskMapHand = Mod.Variable.DefaultFurMaskMapHand
				if Value ~= nil then NewFurMaskMapHand = RoundNumber(Value) end
				Characters[NewIndex].Mesh:setMaterialFloat(IndexOfBodyMat, i, NewFurMaskMapHand)
				Mod.Presets[ModCharaId[NewIndex]].Fur_MaskMap_Hand = NewFurMaskMapHand
				DebugLog("UpdateMaterialFurMaskHand setMaterialFloat with body_mat Fur_MaskMap_Hand "..tostring(NewFurMaskMapHand).." for Characters["..ModCharaId[NewIndex].."]!")
				return true
			end
		end
	end
	DebugLog("UpdateMaterialFurMaskHand could not found and set body_mat Fur_MaskMap_Hand")
	return false
end

local function InitPawnsModCharaId()
	if ExtractedEnums.PawnID == nil then
		DebugLog("InitPawnsInModCharaId ExtractedEnums.PawnID is nil, aborting !")
		return false
	end
	for k, v in pairs(ExtractedEnums.PawnID) do
		if (v[1] ~= "None" and v[1] ~= "Max") and v[2] >= 0 then
			ModCharaId[v[1]] = v[2] + 2 -- +2 is to convert PawnID to our ModCharaID : +1 because our table start at 1 and not 0 
			ModCharaId[v[2] + 2] = v[1] -- and then another +1 because we store Arisen before the pawn at ModCharaId[1]
		end
	end
	return true
end

local function ApplyInfLanternOil(CharacterName)
	local CharacterHuman = Characters[ModCharaId[CharacterName]].Human
	if CharacterHuman == nil then
		DebugLog("ApplyInfLanternOil Human is nil for Characters[ModCharaId["..CharacterName.."]] !")
		return false
	end
	local LanternParam = Characters[ModCharaId[CharacterName]].Human:get_Param():get_Action():get_LanternParamProp()
	local CurrentConsumeOilSecSpeed = LanternParam:get_field("ConsumeOilSecSpeed")

	if CurrentConsumeOilSecSpeed == nil then
		DebugLog("ApplyInfLanternOil CurrentConsumeOilSecSpeed is nil for Characters[ModCharaId["..CharacterName.."]] !")
		return false
	elseif CurrentConsumeOilSecSpeed ~= 0 and RoundNumber(CurrentConsumeOilSecSpeed, 3 ) ~= RoundNumber(Mod.Variable.DefaultConsumeOilSecSpeed, 3) then
		Mod.Variable.BackupConsumeOilSecSpeed = RoundNumber(CurrentConsumeOilSecSpeed, 3 )
		DebugLog("ApplyInfLanternOil BackupConsumeOilSecSpeed : "..tostring(CurrentConsumeOilSecSpeed))
	end

	local NewConsumeOilSecSpeed = Mod.Variable.DefaultConsumeOilSecSpeed

	if Mod.Cfg.InfLanternOil == true then
		 NewConsumeOilSecSpeed = 0
	elseif Mod.Variable.BackupConsumeOilSecSpeed ~= nil then
		NewConsumeOilSecSpeed = Mod.Variable.BackupConsumeOilSecSpeed
	end

	if CurrentConsumeOilSecSpeed == NewConsumeOilSecSpeed then
		DebugLog("ApplyInfLanternOil ConsumeOilSecSpeed is already "..tostring(CurrentConsumeOilSecSpeed).." for Characters[ModCharaId["..CharacterName.."]], skipping !")
	else
		LanternParam:set_field("ConsumeOilSecSpeed", NewConsumeOilSecSpeed)
		DebugLog("ApplyInfLanternOil called (set to "..tostring(NewConsumeOilSecSpeed)..") for Characters[ModCharaId["..CharacterName.."]] !")
	end

	return true
end

local function PopulateCharacters(NameOrIndex)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex].GameObject == nil then
		DebugLog("PopulateCharacters Characters["..NewIndex.."] GameObject is nil, aborting !")
		return false
	end

	ExtractComponentToCharacters(NameOrIndex, "app.Character")

	if ExtractComponentToCharacters(NameOrIndex, "app.Human") then
		if UpdateLanternController(NameOrIndex) then
			if Characters[NewIndex].PawnID == nil then
				ApplyInfLanternOil(ModCharaId[NewIndex])
			end
		end
	end
	
	
	local LanternTransform = GetChildsFromTransform(Characters[NewIndex].GameObject:get_Transform(), "lantern_000")
	if LanternTransform ~= nil then
		Characters[NewIndex].LanternMesh = LanternTransform:get_GameObject():call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
	end

	ExtractComponentToCharacters(NameOrIndex, "via.render.Mesh")

	if ExtractComponentToCharacters(NameOrIndex, "app.PartSwapper") then
		HookPartSwapperHideSwapObjects(NameOrIndex)
		local PawnDataContext = nil
		if Characters[NewIndex].PawnID ~= nil  then
			PawnDataContext = Characters[NewIndex].PartSwapper._PawnDataContext
			Characters[NewIndex].Meta._Name = PawnDataContext._Name
			Characters[NewIndex].Meta._Nickname = PawnDataContext._Nickname
			Characters[NewIndex].Meta.NameAndNickString = " - "..PawnDataContext._Name.." "..PawnDataContext._Nickname
		end
	end

	return true
end

local function UpdateLantern(CharacterName)
	local LanternMesh = Characters[ModCharaId[CharacterName]].LanternMesh
	if LanternMesh == nil then
		DebugLog("UpdateLantern LanternMesh is nil for Characters[ModCharaId["..CharacterName.."]] !")
		return false
	end
	local ShouldDrawLantern = true
	if Mod.Presets[CharacterName].HideLantern == true or not Characters[ModCharaId[CharacterName]].LanternController:hasLantern() then ShouldDrawLantern = false end
	LanternMesh:set_DrawDefault(ShouldDrawLantern)
	DebugLog("UpdateLantern called for Characters[ModCharaId["..CharacterName.."]] !")
	return true
end

local function ForceUpdate(CharacterName)
	if Characters[ModCharaId[CharacterName]].PartSwapper ~= nil then
		Characters[ModCharaId[CharacterName]].PartSwapper:forceUpdateStatusOfSwapObjects()
		DebugLog("ForceUpdate called for Characters[ModCharaId["..CharacterName.."]] !")
	end
end

local function ForceUpdateAll()
	for Name, value in pairs(Mod.Presets) do
		ForceUpdate(Name)
	end
	DebugLog("ForceUpdateAll done!")
end

local function UpdateHideSwapObjects(CharacterName)
	if Mod.Presets[CharacterName] == nil then
		DebugLog("Mod.Presets["..CharacterName.."] is nil, aborting !")
		return nil
	end
	local UpdatedHideSwapObjects = nil
	if Mod.Presets[CharacterName].SwapObjectsToHide ~= nil then
		for k, v in pairs(Mod.Presets[CharacterName].SwapObjectsToHide) do
			if v ~= nil then
				local EnumSwapObjectsValue = nil
				for kk, vv in pairs(ExtractedEnums.SwapObjects) do
					-- DebugLog("EnumSwapObjects vv[1] : "..vv[1].." | EnumSwapObjects vv[2] : "..tostring(vv[2]))
					if k == vv[1] then
						EnumSwapObjectsValue = vv[2]
						break
					end
				end
				if EnumSwapObjectsValue == nil then
					DebugLog("Updated HideSwapObjects error EnumSwapObjectsValue is nil!")
					DebugLog("Mod.Presets["..CharacterName.."].HideSwapObjects : '"..k.."' is a correct enum keyname?")
					break
				end
				if UpdatedHideSwapObjects == nil then UpdatedHideSwapObjects = 0 end
				UpdatedHideSwapObjects = UpdatedHideSwapObjects | EnumSwapObjectsValue
			end
		end
	end
	DebugLog("Updated HideSwapObjects for "..CharacterName.." is "..tostring(UpdatedHideSwapObjects))
	Characters[ModCharaId[CharacterName]].HideSwapObjects = UpdatedHideSwapObjects
	return UpdatedHideSwapObjects
end

local function ApplyPreset(Name)
	if Mod.Presets[Name] == nil then
		DebugLog("ApplyPreset Mod.Presets["..Name.."] is nil, aborting !")
		return false
	end

	UpdateMaterialFurMaskHand(Name, Mod.Presets[Name].Fur_MaskMap_Hand)
	
	UpdateHideSwapObjects(Name)

	ForceUpdate(Name)

	UpdateLantern(Name)

	return true
end

local function SetupArisen()
	if GetPlayerGameObject() == nil then
		return false
	end

	InitCharactersTableWithModCharaId()

	if not UpdatePlayerGameObject() then
		return false
	end

	if PopulateCharacters(ModCharaId.Arisen) then
		LoadFromSavedPresets(ModCharaId[ModCharaId.Arisen])
		ApplyPreset(ModCharaId[ModCharaId.Arisen])
		SaveCurrentPreset(ModCharaId[ModCharaId.Arisen])
	end

	return true
end

local function SetupPawns()
	if ManagedSingleton.PawnManager == nil then UpdateAppSingleton("PawnManager") end
	if ManagedSingleton.PawnManager == nil then
		DebugLog("SetupPawns ManagedSingleton.PawnManager is nil, aborting !")
		return false
	end

	InitPawnsModCharaId()

	local PawnSetup = 0
	local AllPartyPawn = ManagedSingleton.PawnManager:getAllPartyPawn():ToArray()--:get_elements()
	--DebugLog("ManagedSingleton.PawnManager:getAllPartyPawn() AllPartyPawn : "..tostring(AllPartyPawn))
	--DebugLog("ManagedSingleton.PawnManager:getAllPartyPawn() AllPartyPawn get_type_definition get_full_name : "..tostring(AllPartyPawn:get_type_definition():get_full_name()))
	for key, value in pairs(AllPartyPawn) do
		--DebugLog("ManagedSingleton.PawnManager:getAllPartyPawn() AllPartyPawn key : "..tostring(key).." | value : "..tostring(value))

		local PawnID = value:get_PawnID()
		if PawnID == nil or PawnID < 0 then
			DebugLog("SetupPawns Pawn PawnID : "..PawnID..", skiping !")
			break
		end
		local PawnIDName = "UnkPawn"
		for k, v in pairs(ExtractedEnums.PawnID) do
			--DebugLog("SetupPawns PawnIDName i : "..tostring(i).." | v[1] : "..tostring(v[1]).." | v[2] : "..tostring(v[2]))
			if v[2] == PawnID then
				PawnIDName = v[1]
				break
			end
		end

		local PawnModCharaId = PawnID + 2 --just to be safe (+2 to convert PawnID to ModCharaId)
		if ModCharaId[PawnIDName] ~= nil then
			PawnModCharaId = ModCharaId[PawnIDName]
		end

		InitCharactersTable(PawnIDName) -- we do not need to set index because InitCharactersTable will retrieve it in ModCharaId and we did update ModCharaId with InitPawnsModCharaId
		local PawnGameObject = value:get_CachedGameObject()
		if PawnGameObject ~= nil then
			Characters[PawnModCharaId].GameObject = PawnGameObject
			Characters[PawnModCharaId].PawnID = PawnID
			if PopulateCharacters(PawnModCharaId) then
				PawnSetup = PawnSetup +1
				LoadFromSavedPresets(PawnModCharaId)
				ApplyPreset(ModCharaId[PawnModCharaId])
				SaveCurrentPreset(PawnModCharaId)
			end
		else
			DebugLog("SetupPawns Pawn "..PawnIDName.." GameObject is nil")
		end

	end

	DebugLog("SetupPawns : "..PawnSetup.." Pawn have been setup")

	return true
end

local function AddOnTickCounter(Name, Second, Functions)
	if Name == nil or Second == nil or Functions == nil then
		DebugLog("AddToOnTickCounterZero missing param, aborting !")
		return false
	end

	local FunctionsTable = {}
	if type(Functions) == "table" then
		FunctionsTable = Functions
	else
		table.insert(FunctionsTable, Functions)
	end

	if OnTickCounterZero[Name] == nil then
		OnTickCounterZero[Name] = { TargetTime = os.clock() + tonumber(Second), FuncTable = FunctionsTable }
	else
		DebugLog("AddToOnTickCounterZero there is already a "..Name.." in the queu, aborting !")
		return false
	end
	return true
end

local function Setup()
	if ManagedSingleton.CharacterManager == nil then UpdateAppSingleton("CharacterManager") end
	if ManagedSingleton.BattleManager == nil then UpdateAppSingleton("BattleManager") end
	if ManagedSingleton.PawnManager == nil then UpdateAppSingleton("PawnManager") end

	if not SetupArisen() then
		return false
	end

	AddOnTickCounter("DoSetupPawns", 2.0, { [1] = SetupPawns, [2] = ForceUpdateAll })

	return true
end

local function ApplyAllInfLanternOil()
	for key, value in pairs(Characters) do
		if value.Human ~= nil and value.PawnID == nil then
			ApplyInfLanternOil(ModCharaId[key])
		end
	end
	DebugLog("ApplyAllInfLanternOil done!")
end

local function UpdateAllLantern()
	for key, value in pairs(Characters) do
		if value.LanternMesh ~= nil then
			UpdateLantern(ModCharaId[key])
		end
	end
	DebugLog("UpdateAllLantern done!")
end

local function SetupLantern()
	UpdateAllLantern()
	ApplyAllInfLanternOil()
end


re.on_pre_application_entry("UpdateBehavior", function()
	if Characters[ModCharaId.Arisen].GameObject == nil then
		if TickCounter == 0 then
			Setup()
		end
		if TickCounter > Mod.Variable.TicksToWait then
			TickCounter = 0
		else
			TickCounter = TickCounter + 1
		end
	else
		local DoChecks = false
		for key, value in pairs(OnTickCounterZero) do
			DoChecks = true
			break
		end
		if DoChecks == true then
			if TickCounter == 0 then
				for key, value in pairs(OnTickCounterZero) do
					if value.TargetTime <= os.clock() then
						for index, func in ipairs(value.FuncTable) do
							func()
						end
						OnTickCounterZero[key] = nil
					end
				end
			end
			if TickCounter > Mod.Variable.TicksToWait then
				TickCounter = 0
			else
				TickCounter = TickCounter + 1
			end
		end
	end
end)

local function testfunction(arg)
	-- No Spoiler
end

-- Hooks

sdk.hook(
    sdk.find_type_definition("app.PawnManager"):get_method("setupAsPartyPawn"),
    function(args)
    end,
    function(retval)
		AddOnTickCounter("DoSetupPawns", 2.0, { [1] = SetupPawns, [2] = ForceUpdateAll })
		return retval
	end
)

sdk.hook(
    sdk.find_type_definition("app.PawnManager"):get_method("removeSavedPartyPawn"),
    function(args)
    end,
    function(retval)
		AddOnTickCounter("DoSetupPawns", 2.0, { [1] = SetupPawns, [2] = ForceUpdateAll })
		return retval
	end
)

sdk.hook(
    sdk.find_type_definition("app.CaughtController"):get_method("setupEscape"),
    function(args)
		if Mod.Cfg.InfCarryTime > 1 then
			if sdk.to_managed_object(args[2]):get_field("CatchChara"):get_CharaIDString() == "ch000000_00" then
				if Mod.Cfg.InfCarryTime == 2 then
					args[3]= sdk.float_to_ptr(-1)
					DebugLog("hook app.CaughtController setupEscape spoofed !")
					return sdk.PreHookResult.CALL_ORIGINAL
				elseif Mod.Cfg.InfCarryTime == 3 then
					DebugLog("hook app.CaughtController setupEscape skiped !")
					return sdk.PreHookResult.SKIP_ORIGINAL
				end
			end
		end
    end,
    function(retval)
		return sdk.to_ptr(0)
	end
)

sdk.hook(
	sdk.find_type_definition("app.HumanStaminaController"):get_method("calcConsumeStaminaValue"),
	function(args)
		if Mod.Cfg.InfStamina == 3 then
			sdk.to_managed_object(args[2]).StaminaManager:recoverAll()
			return sdk.PreHookResult.SKIP_ORIGINAL
		end
	end,
	function(retval)
		--DebugLog("HumanStaminaController calcConsumeStaminaValue retval : "..tostring(sdk.to_float(retval))) --spam
		if Mod.Cfg.InfStamina > 1 then
			if Mod.Cfg.InfStamina == 3 then
				return sdk.float_to_ptr(0.0)
			elseif Mod.Cfg.InfStamina == 2 then
				if sdk.to_float(retval) < 0.0 then
					if ManagedSingleton.BattleManager == nil then UpdateAppSingleton("BattleManager") end
					if ManagedSingleton.BattleManager:get_field("_BattleMode") == 0 then
						return sdk.float_to_ptr(0.0)
					end
				end
			end
		end
		return retval
	end
)

sdk.hook(
	sdk.find_type_definition("app.TurnLantern"):get_method("execTurn"),
	function(args) end,
	function(retval)
		AddOnTickCounter("DoSetupLantern", 2.0, SetupLantern)
		return retval
	end
)

----- GUI

local CfgChanged = {}
local PresetChanged = {}
local IgnoredValues = {} --store values we don't save directly or don't save at all
local HeaderState = {
	Gameplay = true,
	Visual = true,
	Debug = false,
	Infinite = true,
	Characters = true,
	CharactersArisen = true,
	SwapObjectsToHideArisen = true,
	CharactersMainPawn = true,
	SwapObjectsToHideMainPawn = true,
	CharactersSubPawn01 = false,
	SwapObjectsToHideSubPawn01 = true,
	CharactersSubPawn02 = false,
	SwapObjectsToHideSubPawn02 = true
}

re.on_draw_ui(function()
	if imgui.button(Mod.Info.Name.."'s Menu") then
		Mod.Cfg.DrawWindow = not Mod.Cfg.DrawWindow
		SaveCfg()
	end
end)

re.on_frame(function()
	if Mod.Cfg.DrawWindow == nil then Mod.Cfg.DrawWindow = true end
	if Mod.Cfg.DrawWindow and (reframework:is_drawing_ui() or Mod.Cfg.IgnoreReframeworkDrawUI) then
		Mod.Cfg.DrawWindow = imgui.begin_window(Mod.Info.Name, true)
		if Mod.Cfg.DrawWindow == false then SaveCfg() end
		imgui.push_item_width(-1.0)
		imgui.set_next_item_open(HeaderState["Gameplay"])
		HeaderState["Gameplay"] = imgui.collapsing_header("Gameplay")
		if HeaderState["Gameplay"] then
			imgui.indent()
			imgui.set_next_item_open(HeaderState["Infinite"])
			HeaderState["Infinite"] = imgui.collapsing_header("Infinite")
			if HeaderState["Infinite"] then
				imgui.indent()
				imgui.text("Lantern Oil ")
				imgui.same_line()
				CfgChanged["InfLanternOil"], Mod.Cfg.InfLanternOil = imgui.checkbox("##InfLanternOil", Mod.Cfg.InfLanternOil)
				if CfgChanged["InfLanternOil"] == true then
					ApplyAllInfLanternOil()
				end
				imgui.text("Stamina ")
				imgui.same_line()
				CfgChanged["InfStamina"], Mod.Cfg.InfStamina = imgui.combo("##InfStamina", Mod.Cfg.InfStamina, { "Off", "OutOfBattle", "Always" })
				imgui.text("NPC Carry Time ")
				imgui.same_line()
				CfgChanged["InfCarryTime"], Mod.Cfg.InfCarryTime = imgui.combo("##InfPickUpTime", Mod.Cfg.InfCarryTime, { "Off", "StillResist", "On" })
				imgui.unindent()
			end
			imgui.unindent()
		end
		imgui.set_next_item_open(HeaderState["Visual"])
		HeaderState["Visual"] = imgui.collapsing_header("Visual")
		if HeaderState["Visual"] then
			imgui.indent()
			imgui.set_next_item_open(HeaderState["Characters"])
			HeaderState["Characters"] = imgui.collapsing_header("Characters")
			if HeaderState["Characters"] then
				imgui.indent()
				for index, Character in ipairs(Characters) do
					if Mod.Presets[Character.Name] ~= nil then
						imgui.set_next_item_open(HeaderState["Characters"..Character.Name])
						HeaderState["Characters"..Character.Name] = imgui.collapsing_header(Character.Name..Character.Meta.NameAndNickString)
						if HeaderState["Characters"..Character.Name] then
							imgui.indent()
							imgui.text("Desired Body Fur Mask Map : ")
							imgui.same_line()
							PresetChanged["Fur_MaskMap_Hand"..Character.Name], Mod.Presets[Character.Name].Fur_MaskMap_Hand = imgui.drag_float("##Fur_MaskMap_Hand"..Character.Name, Mod.Presets[Character.Name].Fur_MaskMap_Hand, 0.01, 0.0, 1.0)
							if imgui.is_item_hovered() then
								imgui.begin_tooltip()
								imgui.set_tooltip("0.0 : is the default value and will make body part invisible\n0.05 : will show the body but hide the fur\n1.0 : Will show the body and the full fur no matter what, it create clipping issue between armor and fur")
								imgui.end_tooltip()
							end
							imgui.text("Hide Lantern : ")
							imgui.same_line()
							PresetChanged["HideLantern"..Character.Name], Mod.Presets[Character.Name].HideLantern = imgui.checkbox("##HideLantern"..Character.Name, Mod.Presets[Character.Name].HideLantern)
							imgui.set_next_item_open(HeaderState["SwapObjectsToHide"..Character.Name])
							HeaderState["SwapObjectsToHide"..Character.Name] = imgui.collapsing_header("Hide Parts")
							if HeaderState["SwapObjectsToHide"..Character.Name] then
								imgui.indent()
									if imgui.begin_table(Character.Name.."CharactersSwapObjectsToHideTable", 3) then
										local i = 0
										imgui.table_next_row()
										for k, v in pairs(ExtractedEnums.SwapObjects) do
											if i > 2 then
												i = 0
												imgui.table_next_row()
											end
											imgui.table_set_column_index(i)
											PresetChanged["CharactersSwapObjectsToHideTable"..Character.Name.."_"..v[1]], IgnoredValues["CharactersSwapObjectsToHideTable"..Character.Name.."_"..v[1]] = imgui.checkbox(v[1].."##CharactersSwapObjectsToHideTable_"..Character.Name.."_"..v[1], Mod.Presets[Character.Name].SwapObjectsToHide[v[1]])
											if PresetChanged["CharactersSwapObjectsToHideTable"..Character.Name.."_"..v[1]] == true then
												if IgnoredValues["CharactersSwapObjectsToHideTable"..Character.Name.."_"..v[1]] then
													Mod.Presets[Character.Name].SwapObjectsToHide[v[1]] = "Hiden"
												else
													Mod.Presets[Character.Name].SwapObjectsToHide[v[1]] = nil
												end
											end
											i = i+1
										end
										imgui.end_table()
									end
								imgui.unindent()
							end
							imgui.unindent()
						end
					end
				end
				imgui.unindent()
			end
			imgui.unindent()
		end
		imgui.set_next_item_open(HeaderState["Debug"])
		HeaderState["Debug"] = imgui.collapsing_header("Debug")
		if HeaderState["Debug"] then
			imgui.indent()
			imgui.text("Config :")
			imgui.same_line()
			if imgui.button("Load##LoadCfg") then
				LoadCfg()
			end
			imgui.same_line()
			if imgui.button("Save##SaveCfg") then
				SaveCfg()
			end
			imgui.spacing()
			imgui.text("Presets :")
			imgui.same_line()
			if imgui.button("Load##LoadPreset") then
				for Name, value in pairs(Mod.Presets) do
					LoadFromSavedPresets(Name)
					ApplyPreset(Name)
				end
			end
			imgui.same_line()
			if imgui.button("Save##SavePreset") then
				for Name, value in pairs(Mod.Presets) do
					ApplyPreset(Name)
					SaveCurrentPreset(Name)
				end
			end
			imgui.spacing()
			imgui.text("IgnoreReframeworkDrawUI : ")
			imgui.same_line()
			CfgChanged["IgnoreReframeworkDrawUI"], Mod.Cfg.IgnoreReframeworkDrawUI = imgui.checkbox("##IgnoreReframeworkDrawUI", Mod.Cfg.IgnoreReframeworkDrawUI)
			imgui.spacing()
			imgui.text("Debug : ")
			imgui.same_line()
			CfgChanged["Debug"], Mod.Cfg.Debug = imgui.checkbox("##Debug", Mod.Cfg.Debug)
			if CfgChanged["Debug"] and Mod.Cfg.Debug == true then
				ClearLogFile()
			end
			imgui.spacing()
			if imgui.button("ForceUpdateAll##ForceUpdateAll") then
				ForceUpdateAll()
			end
			imgui.spacing()
			if imgui.button("TEST##testfunction") then
				testfunction()
			end
			imgui.spacing()
			imgui.text("Ticks Counter : "..tostring(Mod.Variable.TicksToWait - TickCounter))
			imgui.spacing()
			imgui.text("Version : "..Mod.Info.Version)
			imgui.text("Source : "..Mod.Info.Source)
			if imgui.is_mouse_clicked(1) then
				imgui.set_clipboard(Mod.Info.Source)
			end
			if imgui.is_item_hovered() then
				imgui.begin_tooltip()
				imgui.set_tooltip("Right click to copy to clipboard")
				imgui.end_tooltip()
			end
			imgui.unindent()
		end
		imgui.end_window()
		for k,v in pairs(CfgChanged) do
			if v == true then
				SaveCfg()
				break
			end
		end
		for k,v in pairs(PresetChanged) do
			if v == true then
				for Name, value in pairs(Mod.Presets) do
					ApplyPreset(Name)
					SaveCurrentPreset(Name)
				end
				break
			end
		end
	end
end)

DebugLog("-- END OF FILE --")