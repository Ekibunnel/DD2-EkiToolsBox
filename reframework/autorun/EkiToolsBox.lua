local Mod = { Name = "EkiToolsBox", version = "0.3.3", Contributors = "Ekibunnel", Source = "https://github.com/Ekibunnel/DD2-EkiToolsBox" }
local Cfg = { Debug = false, DrawWindow = nil, IgnoreReframeworkDrawUI = false, InfStamina = 1, InfLanternOil = false, InfPickupTime = 1, HideObjects = { Arisen = {}, MainPawn = {}} }

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
		Cfg = jsonCfg
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
	Cfg.HideObjects.Arisen = InitTableFromEnum(EnumSwapObjects)
	Cfg.HideObjects.MainPawn = InitTableFromEnum(EnumSwapObjects)
	SaveCfg()
else
	if Cfg.HideObjects.Arisen == nil then
		Cfg.HideObjects.Arisen = InitTableFromEnum(EnumSwapObjects)
	end
	if Cfg.HideObjects.MainPawn == nil then
		Cfg.HideObjects.MainPawn = InitTableFromEnum(EnumSwapObjects)
	end
end

ClearLogFile()

DebugLog("- START -")

local EnumCharacterID = {}
EnumCharacterID["ch000000_00"] = ExtractEnum("app.CharacterID","ch000000_00")
EnumCharacterID["ch100000_00"] = ExtractEnum("app.CharacterID","ch100000_00")
local HideSwapObjects = { Arisen = nil, MainPawn = nil }
local PartSwappers = { Arisen = nil, ArisenMokupModel = nil, MainPawn = nil, MainPawnMokupModel = nil } -- ToDo : also do MokupModels for menus?

local BattleManager = nil
local InfStaminaRegen = sdk.float_to_ptr(65536)


--- MAIN

-- Functions

local function forceUpdate(CharacterName) -- todo : no stac overflow
	if PartSwappers[CharacterName] ~= nil then
		PartSwappers[CharacterName]:get_HideSwapObjects()
		PartSwappers[CharacterName]:forceUpdateStatusOfSwapObjects()
		PartSwappers[CharacterName]:requestFurMask()
		DebugLog("forceUpdate called for "..CharacterName.."!")
	end
end

local function UpdateHideSwapObjects(CharacterName)
	local UpdatedHideSwapObjects = nil
	if Cfg.HideObjects[CharacterName] ~= nil then
		for k, v in pairs(Cfg.HideObjects[CharacterName]) do
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
					DebugLog("Cfg.HideObjects["..CharacterName.."] : '"..k.."' is a correct enum keyname?")
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
		DebugLog("UpdateHideSwapObjects PartSwappers is nil skiping forceUpdate")
	end
end

local function test_feature()
	--still cooking the worst code you've ever witness
	forceUpdate("Arisen")
	forceUpdate("MainPawn")
end

-- Hooks

sdk.hook(
    sdk.find_type_definition("app.CaughtController"):get_method("setupEscape"),
    function(args)
		if sdk.to_managed_object(args[2]):get_field("CatchChara").CharacterID == EnumCharacterID.ch000000_00 then
			if Cfg.InfPickupTime == 2 then
				args[3]= sdk.float_to_ptr(-1)
				DebugLog("setup Escape spoofed !")
				return sdk.PreHookResult.CALL_ORIGINAL
			elseif Cfg.InfPickupTime == 3 then
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
		DebugLog("Arisen RenderTargetOperator : args[2] to_managed_object get_address : "..tostring(sdk.to_managed_object(args[2]):get_address()))
		if PartSwappers.Arisen ~= nil and HideSwapObjects.Arisen ~= nil then
			if sdk.to_managed_object(args[2]) == PartSwappers.Arisen:get_field("_RenderTargetOperator") then
				args[3] = sdk.to_ptr(0)
				DebugLog("RenderTargetOperator set_OperandTexture spoofed for Arisen!")
				return sdk.PreHookResult.CALL_ORIGINAL
			end
		end
		if PartSwappers.MainPawn ~= nil and HideSwapObjects.MainPawn ~= nil then
			if sdk.to_managed_object(args[2]) == PartSwappers.MainPawn:get_field("_RenderTargetOperator") then
				args[3] = sdk.to_ptr(0)
				DebugLog("RenderTargetOperator set_OperandTexture spoofed for MainPawn!")
				return sdk.PreHookResult.CALL_ORIGINAL
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
		if PartSwappers.Arisen == nil or PartSwappers.ArisenMokupModel == nil or PartSwappers.MainPawn == nil or PartSwappers.MainPawnMokupModel == nil then
			local PartSwapper = sdk.to_managed_object(args[2])
			local CharacterID = PartSwapper:get_CharacterID()
			if CharacterID == EnumCharacterID.ch000000_00 then
				if PartSwappers.Arisen == nil and PartSwapper:get_field("_Human") ~= nil then
					PartSwappers.Arisen = PartSwapper
					DebugLog("PartSwappers.Arisen : "..tostring(PartSwappers.Arisen).." @"..tostring(PartSwapper:get_address()))
					sdk.hook_vtable(
						PartSwapper, PartSwapper:get_type_definition():get_method("onDestroy"),
						function(args)
							PartSwappers.Arisen = nil
							DebugLog("PartSwappers.Arisen onDestroy called")
						end, function(retval) return retval end
					)
					sdk.hook_vtable(
						PartSwapper, PartSwapper:get_type_definition():get_method("get_HideSwapObjects"),
						function(args) end,
						function(retval)
							if HideSwapObjects.Arisen ~= nil then
								--DebugLog("PartSwappers.Arisen get_HideSwapObjects spoofed!") --spam
								return sdk.to_ptr(HideSwapObjects.Arisen)
							end
							return retval
						end
					)
					UpdateHideSwapObjects("Arisen")
				elseif PartSwappers.ArisenMokupModel == nil and PartSwapper:get_field("_MockupBuilder") ~= nil then
					PartSwappers.ArisenMokupModel = PartSwapper
					DebugLog("PartSwappers.PlayerMokupModel : "..tostring(PartSwappers.ArisenMokupModel).." @"..tostring(PartSwapper:get_address()))
				end
			elseif CharacterID == EnumCharacterID.ch100000_00 then
				if PartSwappers.MainPawn == nil and PartSwapper:get_field("_Human") ~= nil then
					PartSwappers.MainPawn = PartSwapper
					DebugLog("PartSwappers.MainPawn : "..tostring(PartSwappers.MainPawn).." @"..tostring(PartSwapper:get_address()))
					sdk.hook_vtable(
						PartSwapper, PartSwapper:get_type_definition():get_method("onDestroy"),
						function(args)
							PartSwappers.MainPawn = nil
							DebugLog("PartSwappers.MainPawn onDestroy called!")
						end, function(retval) return retval end
					)
					sdk.hook_vtable(
						PartSwapper, PartSwapper:get_type_definition():get_method("get_HideSwapObjects"),
						function(args) end,
						function(retval)
							if HideSwapObjects.MainPawn ~= nil then
								--DebugLog("PartSwappers.MainPawn get_HideSwapObjects spoofed!") --spam
								return sdk.to_ptr(HideSwapObjects.MainPawn)
							end
							return retval
						end
					)
					UpdateHideSwapObjects("MainPawn")
				elseif PartSwappers.MainPawnMokupModel == nil and PartSwapper:get_field("_MockupBuilder") ~= nil then
					PartSwappers.MainPawnMokupModel = PartSwapper
					DebugLog("PartSwappers.PlayerMokupModel : "..tostring(PartSwappers.MainPawnMokupModel).." @"..tostring(PartSwapper:get_address()))
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
local HeaderState = {Gameplay = true, Visual = true, Debug = false, Infinite = true, HideObjects = true, HideObjectsArisen = true, HideObjectsMainPawn = true  }

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
				imgui.text("NPC Pickup Time ")
				imgui.same_line()
				CfgChanged["InfPickupTime"], Cfg.InfPickupTime = imgui.combo("##InfPickUpTime", Cfg.InfPickupTime, { "Off", "StillResist", "On" })
				imgui.unindent()
			end
			imgui.unindent()
		end
		imgui.set_next_item_open(HeaderState["Visual"])
		HeaderState["Visual"] = imgui.collapsing_header("Visual")
		if HeaderState["Visual"] then
			imgui.indent()
			imgui.set_next_item_open(HeaderState["HideObjects"])
			HeaderState["HideObjects"] = imgui.collapsing_header("Hide Objects")
			if HeaderState["HideObjects"] then
				imgui.indent()
				imgui.set_next_item_open(HeaderState["HideObjectsArisen"])
				HeaderState["HideObjectsArisen"] = imgui.collapsing_header("Arisen")
				if HeaderState["HideObjectsArisen"] then
					imgui.indent()
					if PartSwappers.Arisen ~= nil or Cfg.Debug then
						if imgui.begin_table("ArisenHideObjectsTable", 3) then
							local i = 0
							imgui.table_next_row()
							for k, v in pairs(EnumSwapObjects) do
								if i > 2 then
									i = 0
									imgui.table_next_row()
								end
								imgui.table_set_column_index(i)
								CfgChanged["HideObjects_Arisen_"..v[1]], IgnoredValues["HideObjects_Arisen_"..v[1]] = imgui.checkbox(v[1].."##HideObjects_Arisen_"..v[1], Cfg.HideObjects.Arisen[v[1]])
								if CfgChanged["HideObjects_Arisen_"..v[1]] == true then
									if IgnoredValues["HideObjects_Arisen_"..v[1]] then
										Cfg.HideObjects.Arisen[v[1]] = "Hiden"
									else
										Cfg.HideObjects.Arisen[v[1]] = nil
									end
									UpdateHideSwapObjects("Arisen")
								end
								i = i+1
							end
							imgui.end_table()
						end
					end
					imgui.unindent()
				end
				imgui.set_next_item_open(HeaderState["HideObjectsMainPawn"])
				HeaderState["HideObjectsMainPawn"] = imgui.collapsing_header("Main Pawn")
				if HeaderState["HideObjectsMainPawn"] then
					imgui.indent()
					if PartSwappers.MainPawn ~= nil or Cfg.Debug then
						if imgui.begin_table("MainPawnHideObjectsTable", 3) then
							local i = 0
							imgui.table_next_row()
							for k, v in pairs(EnumSwapObjects) do
								if i > 2 then
									i = 0
									imgui.table_next_row()
								end
								imgui.table_set_column_index(i)
								CfgChanged["HideObjects_MainPawn_"..v[1]], IgnoredValues["HideObjects_MainPawn_"..v[1]] = imgui.checkbox(v[1].."##HideObjects_MainPawn_"..v[1], Cfg.HideObjects.MainPawn[v[1]])
								if CfgChanged["HideObjects_MainPawn_"..v[1]] == true then
									if IgnoredValues["HideObjects_MainPawn_"..v[1]] then
										Cfg.HideObjects.MainPawn[v[1]] = "Hiden"
									else
										Cfg.HideObjects.MainPawn[v[1]] = nil
									end
									UpdateHideSwapObjects("MainPawn")
								end
								i = i+1
							end
							imgui.end_table()
						end
					end
					imgui.unindent()
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
			imgui.text("Debug : ")
			imgui.same_line()
			CfgChanged["Debug"], Cfg.Debug = imgui.checkbox("##Debug", Cfg.Debug)
			if CfgChanged["Debug"] and Cfg.Debug == true then
				ClearLogFile()
			end
			imgui.spacing()
			imgui.text("IgnoreReframeworkDrawUI : ")
			imgui.same_line()
			CfgChanged["IgnoreReframeworkDrawUI"], Cfg.IgnoreReframeworkDrawUI = imgui.checkbox("##IgnoreReframeworkDrawUI", Cfg.IgnoreReframeworkDrawUI)
			imgui.spacing()
			if imgui.button("test_feature") then
				test_feature()
			end
			if imgui.is_item_hovered() then
				imgui.begin_tooltip()
				imgui.set_tooltip("ignore this")
				imgui.end_tooltip()
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
