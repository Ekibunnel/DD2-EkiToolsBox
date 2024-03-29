local Mod = { Name = "EkiToolsBox", Debug = true }
local Cfg = { InfStamina = 2, InfLanternOil = true}

--- UTILS

local function DebugLog(String)
	if Mod["Debug"] then
		log.debug("["..Mod["Name"].."] "..tostring(String))
	end
end

local function LoadCfg()
	local jsonCfg = json.load_file(Mod["Name"]..".json")
	if jsonCfg ~= nil then
		Cfg = jsonCfg
		DebugLog("LoadCfg from file : "..json.dump_string(Cfg, 0))
		return false
	end
	DebugLog("LoadCfg default : "..json.dump_string(Cfg, 0))
	return true
end

local function SaveCfg()
	DebugLog("SaveCfg : "..json.dump_string(Cfg, 0))
	json.dump_file(Mod["Name"]..".json", Cfg)
end

--- INIT

DebugLog("- START -")

local BattleManager = nil
local InfStaminaRegen = sdk.float_to_ptr(65536)

if LoadCfg() then SaveCfg() end

--- MAIN

sdk.hook(
	sdk.find_type_definition("app.StaminaManager"):get_method("add"),
	function(args)
		if Cfg["InfStamina"] == 1 then
			args[3] = InfStaminaRegen
			return sdk.PreHookResult.CALL_ORIGINAL
		elseif Cfg["InfStamina"] == 2 then
			if sdk.to_float(args[3]) < 0.0 then
				if not BattleManager then
					BattleManager = sdk.get_managed_singleton('app.AppSingleton`1<app.BattleManager>'):call('get_Instance')
					DebugLog("BattleManager : "..tostring(BattleManager))
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
		if Cfg["InfLanternOil"] == true then
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

--- GUI

local DrawWindow = false
local CfgChanged = {}
local IgnoredChanged = {} --store "Changed" values we don't care to save

re.on_draw_ui(function()
	if imgui.button(Mod["Name"]) then 
		DrawWindow = not DrawWindow
	end	
end)

re.on_frame(function()
	if DrawWindow then
		DrawWindow = imgui.begin_window(Mod["Name"], true)
		imgui.spacing()
		imgui.push_item_width(-1.0)
		imgui.text("Debug : ")
		imgui.same_line()
		IgnoredChanged["Debug"], Mod["Debug"] = imgui.checkbox("##Debug", Mod["Debug"])
		imgui.text("Config :")
		imgui.same_line()
		if imgui.button("Load") then 
			LoadCfg()
		end
		imgui.same_line()
		if imgui.button("Save") then 
			SaveCfg()
		end
		imgui.text("InfLanternOil : ")
		imgui.same_line()
		CfgChanged["InfLanternOil"], Cfg["InfLanternOil"] = imgui.checkbox("##InfLanternOil", Cfg["InfLanternOil"])
		imgui.text("InfStamina : ")
		imgui.same_line()
		CfgChanged["InfStamina"], Cfg["InfStamina"] = imgui.combo("##InfStamina", Cfg["InfStamina"], { "Always", "OutOfBattle", "Off" })
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
