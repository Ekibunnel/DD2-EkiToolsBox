local Mod = {
	Info = {
		Name = "EkiToolsBox",
		Version = "0.5.0",
		Contributors = "Ekibunnel",
		Source = "https://github.com/Ekibunnel/DD2-EkiToolsBox"
	},
	Cfg = {
		Debug = false,
		DrawWindow = nil,
		IgnoreReframeworkDrawUI = false,
		IgnoreCleanup = false,
		InfStamina = 1,
		InfLanternOil = false,
		InfCarryTime = 1,
		FroceHideSwapInSpa = false
	},
	Constant = {
		TicksToWait = 40,
		DefaultFurMaskMapHand = 0.05,
		DefaultConsumeOilSecSpeed = 0.0125,
		DefaultDragonGradeOpacity = 0.650
	},
	Variable = {},
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
		WeaponMesh = nil,
		PartSwapMesh = nil,
		Human = nil,
		LanternController = nil,
		LanternMesh = nil,
		Character = nil,
		HideSwapObjects = nil,
		BackupHideSwapObjects = nil,
		CaughtController = nil,
		PartSwapper = nil,
		PartSwapItem = {}
	}
}

local ManagedSingleton = { CharacterManager = nil, BattleManager = nil, PawnManager = nil, SpaManager = nil }

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
	if Characters[NewIndex] == nil then
		DebugLog("HookCharacterOnDestroy Characters["..ModCharaId[NewIndex].."] is nil, aborting!")
		return false
	end
	if Characters[NewIndex].Character == nil then
		DebugLog("HookCharacterOnDestroy Character is null, aborting!")
		return false
	end
	sdk.hook_vtable(
		Characters[NewIndex].Character, Characters[NewIndex].Character:get_type_definition():get_method("onDestroy"),
		function(args) end,
		function(retval)
			if Characters[NewIndex] ~= nil then
				Characters[NewIndex].GameObject = nil -- This will recall Setup and then clean the whole Characters Table if Arisen
				DebugLog("Characters["..NewIndex.."] onDestroy called !")
			end
			return retval
		end
	)
	DebugLog("HookCharacterOnDestroy Characters["..ModCharaId[NewIndex].."] onDestroy is hooked !")
	return true
end

-- Functions

local function InitModVariable()
	Mod.Variable = {
		BackupConsumeOilSecSpeed = nil,
		IsSpaMode = false
	}
	if ManagedSingleton.SpaManager ~= nil then
		Mod.Variable.IsSpaMode = ManagedSingleton.SpaManager:get_IsActiveSpa()
	end
end


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
		WeaponMesh = nil,
		PartSwapMesh = nil,
		Human = nil,
		LanternController = nil,
		LanternMesh = nil,
		Character = nil,
		HideSwapObjects = nil,
		BackupHideSwapObjects = nil,
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
		Fur_MaskMap_Hand = -1,
		DragonGrade_Opacity = -1,
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

	Mod.Presets[NewName] = nil
	InitPreset(NewName)

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
	if Characters[NewIndex] == nil then
		DebugLog("UpdateCharactersComponent Characters["..NewIndex.."] is nil, aborting !")
		return false
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
	if Characters[NewIndex] == nil then
		DebugLog("UpdateLanternController Characters["..NewIndex.."] is nil, aborting ! ")
		return false
	end
	if Characters[NewIndex].Human == nil then
		DebugLog("UpdateLanternController Human is nil, aborting ! ")
		return false
	end
	local LanterController = Characters[NewIndex].Human:get_LanternCtrl()
	if LanterController ~= nil then
		DebugLog("UpdateLanternController Characters["..NewIndex.."] LanternController : "..tostring(LanterController))
		Characters[NewIndex].LanternController = LanterController
		return true
	end
	return false
end

local function UpdateMesh(NameOrIndex)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex] == nil then
		DebugLog("UpdateMesh Characters["..NewIndex.."] is nil, aborting ! ")
		return false
	end
	if Characters[NewIndex].GameObject == nil then
		DebugLog("UpdateMesh GameObject is nil, aborting ! ")
		return false
	end

	local CharacterTransform = Characters[NewIndex].GameObject:get_Transform()
	local CharacterTransformChilds = GetChildsFromTransform(CharacterTransform)

	Characters[NewIndex].WeaponMesh = {}
	Characters[NewIndex].PartSwapMesh = {}

	for key, value in pairs(CharacterTransformChilds) do
		local ValueGameObj = value:get_GameObject()
		local ValueGameObjName = ValueGameObj:get_Name()
		local ValueFolder = ValueGameObj:get_FolderSelf()
		local ValueFolderName = nil
		if ValueFolder then
			ValueFolderName = ValueFolder:get_Name()
		end
		if ValueFolderName == "Equipment" then
			if ValueGameObj:call("getComponent(System.Type)", sdk.typeof("app.Weapon")) ~= nil then
				Characters[NewIndex].WeaponMesh[ValueGameObjName] = ValueGameObj:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
			end
		elseif ValueFolderName == "PartSwap" then
			Characters[NewIndex].PartSwapMesh[ValueGameObjName] = ValueGameObj:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
		end
		-- DebugLog("CharacterTransformChilds['"..tostring(key).."'] : GameObj name : "..tostring(ValueGameObjName).." | FolderSelf name : "..tostring(ValueFolderName))
	end
	DebugLog("UpdateMesh done !")
	return true
end

local function UpdateMaterialFloat(Mesh, MaterialName, VariableName, VariableValue)
	if Mesh == nil  or VariableName == nil or VariableValue == nil then
		DebugLog("UpdateMaterialFloat At least one of the non-nil Arg is nil, aborting !")
		return false
	end

	local MaterialIndexTable = {}

	if MaterialName ~= nil then
		local MaterialNames = Mesh:get_MaterialNames()
		--DebugLog("UpdateMaterial MaterialNames : "..tostring(MaterialNames))
		local IndexOfBodyMat = MaterialNames:IndexOf(MaterialName)
		--DebugLog("UpdateMaterial IndexOfBodyMat from "..MaterialName.." : "..tostring(IndexOfBodyMat))
		if IndexOfBodyMat < 0 then
			DebugLog("UpdateMaterialFloat IndexOfBodyMat is "..tostring(IndexOfBodyMat).." for "..tostring(MaterialName)..", aborting !")
			return false
		end
		table.insert(MaterialIndexTable, IndexOfBodyMat)
	else
		local MaterialNum = Mesh:call("get_MaterialNum")
		for i = 0, MaterialNum - 1 do
			table.insert(MaterialIndexTable, i)
		end
	end

	for index, value in ipairs(MaterialIndexTable) do
		local MaterialVariableNum = Mesh:getMaterialVariableNum(value)
		for i = 0, MaterialVariableNum - 1 do
			local MaterialVariableName = Mesh:getMaterialVariableName(value, i)
			--DebugLog("UpdateMaterial MaterialVariableName : "..tostring(MaterialVariableName))
			if MaterialVariableName ~= nil then
				if MaterialVariableName == VariableName then
					Mesh:setMaterialFloat(value, i, VariableValue)
					--DebugLog("UpdateMaterialFloat Material index "..tostring(value).." : "..VariableName.." set to "..tostring(VariableValue).." for Mesh @"..Mesh:get_address().." !")
				end
			end
		end
	end

	return true
end

local function UpdateMaterialFurMaskHand(NameOrIndex, Value)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex] == nil then
		DebugLog("UpdateMaterialFurMaskHand Characters["..NewIndex.."] is nil, aborting ! ")
		return false
	end
	if Characters[NewIndex].Mesh == nil then
		DebugLog("UpdateMaterialFurMaskHand Mesh is nil, aborting !")
		return false
	end

	local NewFurMaskMapHand = Mod.Constant.DefaultFurMaskMapHand
	if Value ~= nil then
		if Value >= 0 then
			NewFurMaskMapHand = RoundNumber(Value)
		else
			NewFurMaskMapHand = 0.0
		end
	end

	if UpdateMaterialFloat(Characters[NewIndex].Mesh, "body_mat", "Fur_MaskMap_Hand", NewFurMaskMapHand) == true then
		if Value ~= nil and Value < 0 then
			Mod.Presets[ModCharaId[NewIndex]].Fur_MaskMap_Hand = nil
		else
			Mod.Presets[ModCharaId[NewIndex]].Fur_MaskMap_Hand = NewFurMaskMapHand
		end
		return true
	end

	return false
end

local function UpdateMaterialDragonGradeOpacity(NameOrIndex, Value)
	local NewIndex = nil
	if type(NameOrIndex) == "string" then
		NewIndex = ModCharaId[NameOrIndex]
	else
		NewIndex = NameOrIndex
	end
	if Characters[NewIndex] == nil then
		DebugLog("UpdateMaterialDragonGradeOpacity Characters["..ModCharaId[NewIndex].."] is nil, aborting ! ")
		return false
	end
	if Characters[NewIndex].WeaponMesh == nil and Characters[NewIndex].PartSwapMesh == nil then
		DebugLog("UpdateMaterialDragonGradeOpacity Mesh are nil, aborting !")
		return false
	end

	local UpdatedMeshCount = 0
	local NewDragonGradeOpacity = Mod.Constant.DefaultDragonGradeOpacity

	if Value ~= nil then
		if Value >= 0 then
			NewDragonGradeOpacity = RoundNumber(Value)
		end
		for key, value in pairs(Characters[NewIndex].WeaponMesh) do
			if UpdateMaterialFloat(value, nil, "DragonGrade_Opacity", NewDragonGradeOpacity) == true then
				UpdatedMeshCount = UpdatedMeshCount + 1
			end
		end

		for key, value in pairs(Characters[NewIndex].PartSwapMesh) do
			if UpdateMaterialFloat(value, nil, "DragonGrade_Opacity", NewDragonGradeOpacity) == true then
				UpdatedMeshCount = UpdatedMeshCount + 1
			end
		end
	end

	if Value ~= nil and Value < 0 then
		Mod.Presets[ModCharaId[NewIndex]].DragonGrade_Opacity = nil
		return true
	elseif UpdatedMeshCount > 0 then
		Mod.Presets[ModCharaId[NewIndex]].DragonGrade_Opacity = NewDragonGradeOpacity
		DebugLog("UpdateMaterialDragonGradeOpacity (value:"..tostring(Value)..") Updated "..tostring(UpdatedMeshCount).." Mesh !")
		return true
	end

	DebugLog("UpdateMaterialDragonGradeOpacity NO Mesh updated !")
	return false
end

local function UpdateMeshFromWeapon(Weapon)
	local WeaponParentGameObj = Weapon:get_GameObject():get_Transform():get_Parent():get_GameObject()
	-- DebugLog("UpdateMeshFromWeapon call from "..WeaponParentGameObj:get_Name().." !")
	for index, value in ipairs(Characters) do
		if value.GameObject == WeaponParentGameObj then
			UpdateMesh(index)
			UpdateMaterialDragonGradeOpacity(index, Mod.Presets[value.Name].DragonGrade_Opacity)
			break
		end
	end
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
	elseif CurrentConsumeOilSecSpeed ~= 0 and RoundNumber(CurrentConsumeOilSecSpeed, 3 ) ~= RoundNumber(Mod.Constant.DefaultConsumeOilSecSpeed, 3) then
		Mod.Variable.BackupConsumeOilSecSpeed = RoundNumber(CurrentConsumeOilSecSpeed, 3 )
		DebugLog("ApplyInfLanternOil BackupConsumeOilSecSpeed : "..tostring(CurrentConsumeOilSecSpeed))
	end

	local NewConsumeOilSecSpeed = Mod.Constant.DefaultConsumeOilSecSpeed

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
	if Characters[NewIndex] == nil then
		DebugLog("PopulateCharacters Characters["..NewIndex.."] is nil, aborting !")
		return false
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

	UpdateMesh(NameOrIndex)

	if ExtractComponentToCharacters(NameOrIndex, "app.PartSwapper") then
		Characters[NewIndex].BackupHideSwapObjects = Characters[NewIndex].PartSwapper._HideSwapObjects
		--HookPartSwapperHideSwapObjects(NameOrIndex)
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
	if Mod.Cfg.FroceHideSwapInSpa == false and Mod.Variable.IsSpaMode == true then
		DebugLog("ForceUpdate skipped, IsSpaMode is ON !")
		return false
	end
	if Characters[ModCharaId[CharacterName]].PartSwapper ~= nil then
		local NewHideSwapObjects = 0
		if Characters[ModCharaId[CharacterName]].HideSwapObjects ~= nil then
			NewHideSwapObjects = Characters[ModCharaId[CharacterName]].HideSwapObjects
		end
		local status, Error = pcall(function ()
			Characters[ModCharaId[CharacterName]].PartSwapper:set_HideSwapObjects(NewHideSwapObjects)
			Characters[ModCharaId[CharacterName]].PartSwapper:call("forceUpdateStatusOfSwapObjects")
		end)
		if not status then
			DebugLog("ForceUpdate failled, status :"..tostring(status).." | error : "..type(Error).." : "..tostring(Error))
			return false
		end

		DebugLog("ForceUpdate called for Characters[ModCharaId["..CharacterName.."]] !")
		return true
	end
end

local function ForceUpdateAll()
	for index, value in pairs(Characters) do
		if value.PartSwapper ~= nil then
			ForceUpdate(value.Name)
		end
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


	if Mod.Presets[Name].DragonGrade_Opacity ~= nil then
		UpdateMaterialDragonGradeOpacity(Name, Mod.Presets[Name].DragonGrade_Opacity)
	end


	if UpdateHideSwapObjects(Name) ~= nil then
		if Mod.Presets[Name].Fur_MaskMap_Hand ~= nil and Mod.Presets[Name].Fur_MaskMap_Hand >= 0 then
			UpdateMaterialFurMaskHand(Name, Mod.Presets[Name].Fur_MaskMap_Hand)
		else
			UpdateMaterialFurMaskHand(Name, Mod.Constant.DefaultFurMaskMapHand)
		end
	elseif Mod.Presets[Name].Fur_MaskMap_Hand ~= nil then
		UpdateMaterialFurMaskHand(Name, Mod.Presets[Name].Fur_MaskMap_Hand)
	end

	ForceUpdate(Name)

	UpdateLantern(Name)

	return true
end

local function LoadAllPresets(Apply)
	local DoApply = true
	if Apply ~= nil then DoApply = Apply end

	for Name, value in pairs(Mod.Presets) do
		LoadFromSavedPresets(Name)
		if DoApply == true then ApplyPreset(Name) end
	end
end

local function SaveAllPresets(Apply)
	local DoApply = true
	if Apply ~= nil then DoApply = Apply end

	for Name, value in pairs(Mod.Presets) do
		if DoApply == true then ApplyPreset(Name) end
		SaveCurrentPreset(Name)
	end
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

	for k, v in pairs(ExtractedEnums.PawnID) do
		if (v[1] ~= "None" and v[1] ~= "Max") and v[2] >= 0 then
			Characters[ModCharaId[v[1]]] = nil
			Mod.Presets[v[1]] = nil
		end
	end

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

local function AddOnTickCounter(Name, Second, Functions, Force)
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

	if OnTickCounterZero[Name] == nil or Force == true then
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
	if ManagedSingleton.SpaManager == nil then UpdateAppSingleton("SpaManager") end

	if not SetupArisen() then
		return false
	end

	InitModVariable()

	AddOnTickCounter("DoSetupPawns", 1.0, SetupPawns)
	AddOnTickCounter("DoForceUpdateAll", 2.0, ForceUpdateAll)

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
			if not Setup() then
				TickCounter = TickCounter + 1
			end
		elseif TickCounter > Mod.Constant.TicksToWait then
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
				local OnTickCounterZeroKeyNum = 0
				for key, value in pairs(OnTickCounterZero) do
					OnTickCounterZeroKeyNum = OnTickCounterZeroKeyNum + 1
					if value.TargetTime <= os.clock() then
						for index, func in ipairs(value.FuncTable) do
							func()
						end
						OnTickCounterZero[key] = nil
						OnTickCounterZeroKeyNum = OnTickCounterZeroKeyNum - 1
					end
				end
				if OnTickCounterZeroKeyNum > 0 then
					TickCounter = TickCounter + 1
				end
			elseif TickCounter > Mod.Constant.TicksToWait then
				TickCounter = 0
			else
				TickCounter = TickCounter + 1
			end
		end
	end
end)

re.on_script_reset(function()
	if Mod.Cfg.IgnoreCleanup == true then
		DebugLog("on_script_reset called but IgnoreCleanup is true, ignoring cleanup!")
		return true
	end

	DebugLog("--- on_script_reset called doing cleanup!")

	for index, value in ipairs(Characters) do
		InitPreset(value.Name)
		UpdateLantern(value.Name)

		--DebugLog("--- on_script_reset HideSwapObjects : "..tostring(Characters[index].BackupHideSwapObjects).." | BackupHideSwapObjects : "..tostring(Characters[index].BackupHideSwapObjects))
		Characters[index].HideSwapObjects = Characters[index].BackupHideSwapObjects
		ForceUpdate(value.Name)

		UpdateMaterialDragonGradeOpacity(index, Mod.Constant.DefaultDragonGradeOpacity)
		UpdateMaterialFurMaskHand(index, 0.0)
	end

	DebugLog("--- on_script_reset cleanup done!")
	return true
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
		AddOnTickCounter("DoSetupPawns", 1.0, SetupPawns)
		AddOnTickCounter("DoForceUpdateAll", 2.0, ForceUpdateAll)
		return retval
	end
)

sdk.hook(
    sdk.find_type_definition("app.PawnManager"):get_method("removeSavedPartyPawn"),
    function(args)
    end,
    function(retval)
		AddOnTickCounter("DoSetupPawns", 1.0, SetupPawns)
		AddOnTickCounter("DoForceUpdateAll", 2.0, ForceUpdateAll)
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

sdk.hook(
	sdk.find_type_definition("app.Weapon"):get_method("setupReLibEPVStandardChild"),
	function(args)
		local Weapon = sdk.to_managed_object(args[2])
		UpdateMeshFromWeapon(Weapon)
	end,
	function(retval) return retval end
)

sdk.hook(
	sdk.find_type_definition("app.PartSwapper"):get_method("set_HideSwapObjects"),
	function(args)
		local CurrentPartSwapper = sdk.to_managed_object(args[2])
		for index, value in ipairs(Characters) do
			if value.PartSwapper == CurrentPartSwapper then
				local CalledHideSwapObjects = (sdk.to_int64(args[3]) & 0xFFFF)

				if value.HideSwapObjects ~= nil and CalledHideSwapObjects ~= value.HideSwapObjects then
					if not sdk.is_managed_object(args[3]) == true then
						Characters[index].BackupHideSwapObjects = CalledHideSwapObjects
						DebugLog("set_HideSwapObjects CallHideSwapObjects "..value.Name.." : "..tostring(CalledHideSwapObjects))
					end
				end

				if Mod.Cfg.FroceHideSwapInSpa == true or Mod.Variable.IsSpaMode == false then
					if value.HideSwapObjects ~= nil then
						CurrentPartSwapper:set_field("_HideSwapObjects", value.HideSwapObjects)
					else
						CurrentPartSwapper:set_field("_HideSwapObjects", 0)
					end
					CurrentPartSwapper:set_field("_UpdateStatusOfSwapObjects", true)
					-- DebugLog("PartSwapper set_HideSwapObjects spoofed for "..tostring(value.Name).." !")
					return sdk.PreHookResult.SKIP_ORIGINAL
				end
			end
		end
		-- DebugLog("PartSwapper set_HideSwapObjects is not from party !")
	end,
	function(retval) return sdk.to_ptr(0) end
)

sdk.hook(
	sdk.find_type_definition("app.CharacterEditManager"):get_method("registerSwapRequest"),
	function(args)
		local CurrentPartSwapperRootCharacter = sdk.to_managed_object(args[3]):get_Character()
		for index, value in ipairs(Characters) do
			if value.Character == CurrentPartSwapperRootCharacter then
				UpdateMesh(index)
				local DragonGrade_Opacity = nil
				if Mod.Presets[value.Name] ~= nil then
					DragonGrade_Opacity = Mod.Presets[value.Name].DragonGrade_Opacity
				end
				UpdateMaterialDragonGradeOpacity(index, DragonGrade_Opacity)
				DebugLog("CharacterEditManager registerSwapRequest Updated Mesh for "..value.Name.."  !")
				break
			end
		end
		--DebugLog("CharacterEditManager registerSwapRequest is not from party !")
	end,
	function(retval) return sdk.to_ptr(0) end
)

sdk.hook(
	sdk.find_type_definition("app.SpaController"):get_method("onStart"),
	function(args)
		if sdk.to_managed_object(args[2]):get_Owner():get_GameObject() == Characters[ModCharaId.Arisen].GameObject then
			DebugLog("SpaController onStart !")
			Mod.Variable.IsSpaMode = true
		end
	end,
	function(retval) return retval end
)

sdk.hook(
	sdk.find_type_definition("app.SpaController"):get_method("onDispose"),
	function(args)
		if sdk.to_managed_object(args[2]):get_Owner():get_GameObject() == Characters[ModCharaId.Arisen].GameObject then
			DebugLog("SpaController onDispose !")
			Mod.Variable.IsSpaMode = false
			ForceUpdateAll()
		end
	end,
	function(retval) return retval end
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
	CharactersArisenOverwrite = true,
	SwapObjectsToHideArisen = true,
	CharactersMainPawn = true,
	CharactersMainPawnOverwrite = true,
	SwapObjectsToHideMainPawn = true,
	CharactersSubPawn01 = false,
	CharactersSubPawn01Overwrite = true,
	SwapObjectsToHideSubPawn01 = true,
	CharactersSubPawn02 = false,
	CharactersSubPawn02Overwrite = true,
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
							imgui.text("Hide Lantern : ")
							imgui.same_line()
							PresetChanged["HideLantern"..Character.Name], Mod.Presets[Character.Name].HideLantern = imgui.checkbox("##HideLantern"..Character.Name, Mod.Presets[Character.Name].HideLantern)
							imgui.set_next_item_open(HeaderState["Characters"..Character.Name.."Overwrite"])
							HeaderState["Characters"..Character.Name.."Overwrite"] = imgui.collapsing_header("Overwrite")
							if HeaderState["Characters"..Character.Name.."Overwrite"] then
								imgui.text("Body Fur Mask Map")
								imgui.same_line()
								if Mod.Presets[Character.Name].Fur_MaskMap_Hand == -1 or Mod.Presets[Character.Name].Fur_MaskMap_Hand == nil then
									imgui.text("(Off) : ")
								else
									imgui.text("(On) : ")
								end
								imgui.same_line()
								PresetChanged["Fur_MaskMap_Hand"..Character.Name], IgnoredValues["Fur_MaskMap_Hand"..Character.Name] = imgui.drag_float("##Fur_MaskMap_Hand"..Character.Name, Mod.Presets[Character.Name].Fur_MaskMap_Hand, 0.01, 0.0, 1.0)
								if imgui.is_item_hovered() then
									if imgui.is_mouse_clicked(1) then
										Mod.Presets[Character.Name].Fur_MaskMap_Hand = -1
										PresetChanged["Fur_MaskMap_Hand"..Character.Name] = true
									elseif PresetChanged["Fur_MaskMap_Hand"..Character.Name] == true then
										Mod.Presets[Character.Name].Fur_MaskMap_Hand = IgnoredValues["Fur_MaskMap_Hand"..Character.Name]
									end
									imgui.begin_tooltip()
									imgui.set_tooltip("0.0 : is the default value and will make body part invisible\n0.05 : will show the body but hide the fur\n1.0 : Will show the body and the full fur no matter what, it create clipping issue between armor and fur\n\nRight-Click to turn off the overwrite")
									imgui.end_tooltip()
								end
								imgui.text("DragonGrade Opacity")
								imgui.same_line()
								if Mod.Presets[Character.Name].DragonGrade_Opacity == -1 or Mod.Presets[Character.Name].DragonGrade_Opacity == nil then
									imgui.text("(Off) : ")
								else
									imgui.text("(On) : ")
								end
								imgui.same_line()
								PresetChanged["DragonGrade_Opacity"..Character.Name], IgnoredValues["DragonGrade_Opacity"..Character.Name] = imgui.drag_float("##DragonGrade_Opacity"..Character.Name, Mod.Presets[Character.Name].DragonGrade_Opacity, 0.01, 0.0, 1.0)
								if imgui.is_item_hovered() then
									if imgui.is_mouse_clicked(1) then
										Mod.Presets[Character.Name].DragonGrade_Opacity = -1
										PresetChanged["DragonGrade_Opacity"..Character.Name] = true
									elseif PresetChanged["DragonGrade_Opacity"..Character.Name] == true then
										Mod.Presets[Character.Name].DragonGrade_Opacity = IgnoredValues["DragonGrade_Opacity"..Character.Name]
									end
									imgui.begin_tooltip()
									imgui.set_tooltip("0.0 : disable the effect\n\nRight-Click to turn off the overwrite")
									imgui.end_tooltip()
								end
							end
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
				AddOnTickCounter("DoLoadAllPresets", 0.5, LoadAllPresets, true)
			end
			imgui.same_line()
			if imgui.button("Save##SavePreset") then
				AddOnTickCounter("DoSaveAllPresets", 0.5, SaveAllPresets, true)
			end
			imgui.spacing()
			imgui.text("IgnoreReframeworkDrawUI : ")
			imgui.same_line()
			CfgChanged["IgnoreReframeworkDrawUI"], Mod.Cfg.IgnoreReframeworkDrawUI = imgui.checkbox("##IgnoreReframeworkDrawUI", Mod.Cfg.IgnoreReframeworkDrawUI)
			imgui.spacing()
			imgui.text("IgnoreCleanup : ")
			imgui.same_line()
			CfgChanged["IgnoreCleanup"], Mod.Cfg.IgnoreCleanup = imgui.checkbox("##IgnoreCleanup", Mod.Cfg.IgnoreCleanup)
			imgui.spacing()
			imgui.text("FroceHideSwapInSpa : ")
			imgui.same_line()
			CfgChanged["FroceHideSwapInSpa"], Mod.Cfg.FroceHideSwapInSpa = imgui.checkbox("##FroceHideSwapInSpa", Mod.Cfg.FroceHideSwapInSpa)
			imgui.same_line()
			if Mod.Variable.IsSpaMode == true then
				imgui.text("(IsSpaMode : On)")
			else
				imgui.text("(IsSpaMode : Off)")
			end
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
			imgui.text("Ticks Counter : "..tostring(Mod.Constant.TicksToWait - TickCounter))
			imgui.spacing()
			imgui.text("Version : "..Mod.Info.Version)
			imgui.text("Source : "..Mod.Info.Source)
			if imgui.is_item_hovered() then
				if imgui.is_mouse_clicked(1) then
					imgui.set_clipboard(Mod.Info.Source)
				end
				imgui.begin_tooltip()
				imgui.set_tooltip("Right click to copy to clipboard")
				imgui.end_tooltip()
			end
			imgui.unindent()
		end
		imgui.end_window()
		for k,v in pairs(CfgChanged) do
			if v == true then
				AddOnTickCounter("DoSaveCfg", 0.5, SaveCfg, true)
				break
			end
		end
		for k,v in pairs(PresetChanged) do
			if v == true then
				AddOnTickCounter("DoSaveAllPresets", 0.5, SaveAllPresets, true)
				break
			end
		end
	end
end)

DebugLog("-- END OF FILE --")