local Mod = { Name = "EkiToolsBox", version = "0.3.4", Contributors = "Ekibunnel", Source = "https://github.com/Ekibunnel/DD2-EkiToolsBox" }
local Cfg = { Debug = false, DontSpoofFurMask = false, DrawWindow = nil, IgnoreReframeworkDrawUI = false, InfStamina = 1, InfLanternOil = false, InfCarryTime = 1, CharacterObjects = { Arisen = {}, MainPawn = {} } }

--- UTILS

local function ClearLogFile()
	if Cfg.Debug then
		local Logfile = io.open(Mod.Name.."\\"..Mod.Name..".log", "w")
		Logfile:write("--- "..Mod.Name.." v"..Mod.version.." Debug:"..tostring(Cfg.Debug).." ("..os.date("%x-%X")..") ---\n")
		Logfile:close()
	end
end

local function DebugLog(String)
	if Cfg.Debug then
		local DebugString = "["..Mod.Name.."] "..tostring(String)
		log.debug(DebugString)
		local Logfile = io.open(Mod.Name.."\\"..Mod.Name..".log", "a")
		Logfile:write(DebugString.."\n")
		Logfile:close()
	end
end

local function LoadCfg()
	local jsonCfg = json.load_file(Mod.Name.."\\"..Mod.Name..".config.json")
	if jsonCfg ~= nil then
		for k,v in pairs(jsonCfg) do
			if Cfg[k] ~= nil then
				Cfg[k] = v
			end
		end
		DebugLog("LoadCfg from file : "..json.dump_string(Cfg, 4))
		return true
	end
	DebugLog("LoadCfg default : "..json.dump_string(Cfg, 4))
	return false
end

local function SaveCfg()
	DebugLog("SaveCfg : "..json.dump_string(Cfg, 4))
	json.dump_file(Mod.Name.."\\"..Mod.Name..".config.json", Cfg)
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

local EnumSwapObjects = ExtractEnum("app.charaedit.ch000.Define.SwapObjects")

if not LoadCfg() then
	Cfg.CharacterObjects.Arisen = InitTableFromEnum(EnumSwapObjects)
	Cfg.CharacterObjects.MainPawn = InitTableFromEnum(EnumSwapObjects)
	SaveCfg()
else
	if Cfg.CharacterObjects.Arisen == nil then
		Cfg.CharacterObjects.Arisen = InitTableFromEnum(EnumSwapObjects)
	end
	if Cfg.CharacterObjects.MainPawn == nil then
		Cfg.CharacterObjects.MainPawn = InitTableFromEnum(EnumSwapObjects)
	end
	SaveCfg()
end

ClearLogFile()

DebugLog("- START -")

local EnumCharacterID = {}
EnumCharacterID["ch000000_00"] = ExtractEnum("app.CharacterID","ch000000_00")
EnumCharacterID["ch100000_00"] = ExtractEnum("app.CharacterID","ch100000_00")
local HideSwapObjects = { Arisen = nil, MainPawn = nil }
local PartSwappers = { Arisen = nil, MainPawn = nil }
local PartSwappersMokupModel = { Arisen = nil, MainPawn = nil } -- ToDo : also do MokupModels for menus?

local BattleManager = nil
local InfStaminaRegen = sdk.float_to_ptr(65536)


--- MAIN

-- Functions

local function forceUpdate(CharacterName)
	if PartSwappers[CharacterName] ~= nil then
		PartSwappers[CharacterName]:forceUpdateStatusOfSwapObjects()

		DebugLog("forceUpdate called for PartSwappers."..CharacterName.."!")
	end
	if PartSwappersMokupModel[CharacterName] ~= nil then
		PartSwappersMokupModel[CharacterName]:forceUpdateStatusOfSwapObjects()
		DebugLog("forceUpdate called for PartSwappersMokupModel."..CharacterName.."!")
	end
end

local function UpdateHideSwapObjects(CharacterName)
	local UpdatedHideSwapObjects = nil
	if Cfg.CharacterObjects[CharacterName] ~= nil then
		for k, v in pairs(Cfg.CharacterObjects[CharacterName]) do
			if v ~= nil then
				local EnumSwapObjectsValue = nil
				for kk, vv in pairs(EnumSwapObjects) do
					-- DebugLog("EnumSwapObjects vv[1] : "..vv[1].." | EnumSwapObjects vv[1] : "..tostring(vv[2]))
					if k == vv[1] then
						EnumSwapObjectsValue = vv[2]
						break
					end
				end
				if EnumSwapObjectsValue == nil then
					DebugLog("Updated HideSwapObjects error EnumSwapObjectsValue is nil!")
					DebugLog("Cfg.CharacterObjects["..CharacterName.."] : '"..k.."' is a correct enum keyname?")
					break
				end
				if UpdatedHideSwapObjects == nil then UpdatedHideSwapObjects = 0 end
				UpdatedHideSwapObjects = UpdatedHideSwapObjects | EnumSwapObjectsValue
			end
		end
	end
	DebugLog("Updated HideSwapObjects for "..CharacterName.." is "..tostring(UpdatedHideSwapObjects))
	HideSwapObjects[CharacterName] = UpdatedHideSwapObjects
	if PartSwappers[CharacterName] ~= nil then
		forceUpdate(CharacterName)
	else
		DebugLog("UpdateHideSwapObjects PartSwappers."..CharacterName.." is nil skiping forceUpdate")
	end
end

local function ForceUpdateAll()
	for key, value in pairs(PartSwappers) do
		forceUpdate(key)
	end
	DebugLog("ForceUpdateAll done!")
end

local function testfunction()
end

-- Hooks



sdk.hook(
    sdk.find_type_definition("app.CaughtController"):get_method("setupEscape"),
    function(args)
		if sdk.to_managed_object(args[2]):get_field("CatchChara").CharacterID == EnumCharacterID.ch000000_00 then
			if Cfg.InfCarryTime == 2 then
				args[3]= sdk.float_to_ptr(-1)
				DebugLog("setup Escape spoofed !")
				return sdk.PreHookResult.CALL_ORIGINAL
			elseif Cfg.InfCarryTime == 3 then
				DebugLog("setup Escape skiped !")
				return sdk.PreHookResult.SKIP_ORIGINAL
			end
		end
    end,
    function(retval)
		return sdk.to_ptr(0)
	end
)

sdk.hook(
	sdk.find_type_definition("app.StaminaManager"):get_method("add"),
	function(args)
		if Cfg.InfStamina == 3 then
			args[3] = InfStaminaRegen
			return sdk.PreHookResult.CALL_ORIGINAL
		elseif Cfg.InfStamina == 2 then
			if sdk.to_float(args[3]) < 0.0 then
				if BattleManager == nil then
					BattleManager = sdk.get_managed_singleton('app.AppSingleton`1<app.BattleManager>'):call('get_Instance')
					DebugLog("BattleManager : "..tostring(BattleManager).." @"..tostring(BattleManager:get_address()))
				end
				if BattleManager:get_field("_BattleMode") == 0 then
					--DebugLog("Stamina loss skiped !") --spam
					return sdk.PreHookResult.SKIP_ORIGINAL
				end
			end
		else
			return sdk.PreHookResult.CALL_ORIGINAL
		end
	end,
	function(retval)
		return sdk.to_ptr(0)
	end
)

sdk.hook(
    sdk.find_type_definition("app.HumanLanternController"):get_method("consumeOil"),
    function(args)
		if Cfg.InfLanternOil == true then
			--DebugLog("Consume Oil skiped !") --spam
			return sdk.PreHookResult.SKIP_ORIGINAL
		else
			return sdk.PreHookResult.CALL_ORIGINAL
		end
    end,
    function(retval)
		return sdk.to_ptr(0)
	end
)

sdk.hook(
    sdk.find_type_definition("via.render.RenderTargetOperator"):get_method("set_OperandTexture"),
    function(args)
		--DebugLog("RenderTargetOperator : args[2] to_managed_object get_address : "..tostring(sdk.to_managed_object(args[2]):get_address())) --spam
		if Cfg.DontSpoofFurMask == false then
			for PS, PSvalue in pairs(PartSwappers) do
				if HideSwapObjects[PS] ~= nil then
					if sdk.to_managed_object(args[2]) == PSvalue:get_field("_RenderTargetOperator") then
						args[3] = sdk.to_ptr(0)
						DebugLog("RenderTargetOperator set_OperandTexture spoofed for PartSwappers."..PS.."!")
						return sdk.PreHookResult.CALL_ORIGINAL
					end
				end
			end
		end
    end,
    function(retval)
		return retval
	end
)

----- This work and I feel no shame
----- I couldn't find out a way to get parent or child so I had to do this
----- if you have a marginally better way to get the ch000000_00 PartSwapper feel free to do a PR on github
sdk.hook(
	sdk.find_type_definition("app.PartSwapper"):get_method("lateUpdate"),
	function (args)
		if PartSwappers.Arisen == nil or PartSwappersMokupModel.Arisen == nil or PartSwappers.MainPawn == nil or PartSwappersMokupModel.MainPawn == nil then
			local PartSwapper = sdk.to_managed_object(args[2])
			local CharacterID = PartSwapper:get_CharacterID()
			local PartSwapperName = nil
			if CharacterID == EnumCharacterID.ch000000_00 then
				PartSwapperName = "Arisen"
			elseif CharacterID == EnumCharacterID.ch100000_00 then
				PartSwapperName = "MainPawn"
			end
			if PartSwapperName ~= nil then
				if PartSwappers[PartSwapperName] == nil and PartSwapper:get_field("_Human") ~= nil then
					PartSwappers[PartSwapperName] = PartSwapper
					DebugLog("PartSwappers."..PartSwapperName.." : "..tostring(PartSwappers[PartSwapperName]).." @"..tostring(PartSwapper:get_address()))
					sdk.hook_vtable(
						PartSwapper, PartSwapper:get_type_definition():get_method("onDestroy"),
						function(args)
							PartSwappers[PartSwapperName] = nil
							DebugLog("PartSwappers."..PartSwapperName.." onDestroy called")
						end, function(retval) return retval end
					)
					sdk.hook_vtable(
						PartSwapper, PartSwapper:get_type_definition():get_method("get_HideSwapObjects"),
						function(args) end,
						function(retval)
							if HideSwapObjects[PartSwapperName] ~= nil then
								--DebugLog("PartSwappers."..PartSwapperName.." get_HideSwapObjects spoofed!") --spam
								return sdk.to_ptr(HideSwapObjects[PartSwapperName])
							end
							return retval
						end
					)
					UpdateHideSwapObjects(PartSwapperName)
				elseif PartSwappersMokupModel[PartSwapperName] == nil and PartSwapper:get_field("_MockupBuilder") ~= nil then
					PartSwappersMokupModel[PartSwapperName] = PartSwapper
					DebugLog("PartSwappersMokupModel."..PartSwapperName.." : "..tostring(PartSwappersMokupModel[PartSwapperName]).." @"..tostring(PartSwapper:get_address()))
					sdk.hook_vtable(
						PartSwapper, PartSwapper:get_type_definition():get_method("onDestroy"),
						function(args)
							PartSwappersMokupModel[PartSwapperName] = nil
							DebugLog("PartSwappersMokupModel."..PartSwapperName.." onDestroy called")
						end, function(retval) return retval end
					)
					UpdateHideSwapObjects(PartSwapperName)
				end
			end
		end
		return sdk.PreHookResult.CALL_ORIGINAL
	end,
	function (retval)
		return retval
	end
)

----- GUI

local CfgChanged = {}
local IgnoredValues = {} --store values we don't save directly or don't save at all
local HeaderState = { Gameplay = true, Visual = true, Debug = false, Infinite = true, CharacterObjects = true, CharacterObjectsArisen = true, CharacterObjectsMainPawn = true  }

re.on_draw_ui(function()
	if imgui.button(Mod.Name.."'s Menu") then
		Cfg.DrawWindow = not Cfg.DrawWindow
		SaveCfg()
	end
end)

re.on_frame(function()
	if Cfg.DrawWindow == nil then Cfg.DrawWindow = true end
	if Cfg.DrawWindow and (reframework:is_drawing_ui() or Cfg.IgnoreReframeworkDrawUI) then
		Cfg.DrawWindow = imgui.begin_window(Mod.Name, true)
		if Cfg.DrawWindow == false then SaveCfg() end
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
				CfgChanged["InfLanternOil"], Cfg.InfLanternOil = imgui.checkbox("##InfLanternOil", Cfg.InfLanternOil)
				imgui.text("Stamina ")
				imgui.same_line()
				CfgChanged["InfStamina"], Cfg.InfStamina = imgui.combo("##InfStamina", Cfg.InfStamina, { "Off", "OutOfBattle", "Always" })
				imgui.text("NPC Carry Time ")
				imgui.same_line()
				CfgChanged["InfCarryTime"], Cfg.InfCarryTime = imgui.combo("##InfPickUpTime", Cfg.InfCarryTime, { "Off", "StillResist", "On" })
				imgui.unindent()
			end
			imgui.unindent()
		end
		imgui.set_next_item_open(HeaderState["Visual"])
		HeaderState["Visual"] = imgui.collapsing_header("Visual")
		if HeaderState["Visual"] then
			imgui.indent()
			imgui.set_next_item_open(HeaderState["CharacterObjects"])
			HeaderState["CharacterObjects"] = imgui.collapsing_header("Character Objects")
			if HeaderState["CharacterObjects"] then
				imgui.indent()
				for PS, PSvalue in pairs(PartSwappers) do
					if PSvalue ~= nil or Cfg.Debug then
						imgui.set_next_item_open(HeaderState["CharacterObjects"..PS])
						HeaderState["CharacterObjects"..PS] = imgui.collapsing_header(PS)
						if HeaderState["CharacterObjects"..PS] then
							imgui.indent()
							
								if imgui.begin_table(PS.."CharacterObjectsTable", 3) then
									local i = 0
									imgui.table_next_row()
									for k, v in pairs(EnumSwapObjects) do
										if i > 2 then
											i = 0
											imgui.table_next_row()
										end
										imgui.table_set_column_index(i)
										CfgChanged["CharacterObjects_"..PS.."_"..v[1]], IgnoredValues["CharacterObjects_"..PS.."_"..v[1]] = imgui.checkbox(v[1].."##CharacterObjects_"..PS.."_"..v[1], Cfg.CharacterObjects[PS][v[1]])
										if CfgChanged["CharacterObjects_"..PS.."_"..v[1]] == true then
											if IgnoredValues["CharacterObjects_"..PS.."_"..v[1]] then
												Cfg.CharacterObjects[PS][v[1]] = "Hiden"
											else
												Cfg.CharacterObjects[PS][v[1]] = nil
											end
											UpdateHideSwapObjects(PS)
										end
										i = i+1
									end
									imgui.end_table()
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
			if imgui.button("Load") then 
				LoadCfg()
			end
			imgui.same_line()
			if imgui.button("Save") then 
				SaveCfg()
			end
			imgui.spacing()
			imgui.text("DontSpoofFurMask : ")
			imgui.same_line()
			CfgChanged["DontSpoofFurMask"], Cfg.DontSpoofFurMask = imgui.checkbox("##DontSpoofFurMask", Cfg.DontSpoofFurMask)
			if imgui.is_item_hovered() then
				imgui.begin_tooltip()
				imgui.set_tooltip("If your fur clip through your armor when Hide Objects is active try enabling this.\nIt can break and make part of the body invisible")
				imgui.end_tooltip()
			end
			imgui.spacing()
			imgui.text("IgnoreReframeworkDrawUI : ")
			imgui.same_line()
			CfgChanged["IgnoreReframeworkDrawUI"], Cfg.IgnoreReframeworkDrawUI = imgui.checkbox("##IgnoreReframeworkDrawUI", Cfg.IgnoreReframeworkDrawUI)
			imgui.spacing()
			imgui.text("Debug : ")
			imgui.same_line()
			CfgChanged["Debug"], Cfg.Debug = imgui.checkbox("##Debug", Cfg.Debug)
			if CfgChanged["Debug"] and Cfg.Debug == true then
				ClearLogFile()
			end
			imgui.spacing()
			if imgui.button("ForceUpdateAll") then
				ForceUpdateAll()
			end
			imgui.spacing()
			if imgui.button("TEST") then
				testfunction()
			end
			imgui.spacing()
			imgui.text("Version : "..Mod.version)
			imgui.text("Source : "..Mod.Source)
			if imgui.is_mouse_clicked(1) then
				imgui.set_clipboard(Mod.Source)
			end
			if imgui.is_item_hovered() then
				imgui.begin_tooltip()
				imgui.set_tooltip("Right click to copy to clipboard")
				imgui.end_tooltip()
			end
			imgui.unindent()
		end
		imgui.end_window()
		for i,v in pairs(CfgChanged) do
			if v == true then
				SaveCfg()
				break
			end
		end
	end
end)

DebugLog("-- END --")
