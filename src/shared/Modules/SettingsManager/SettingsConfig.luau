local SettingsConfig = {
	
	-- configuration
	datastore_key = "PlayerSettingsDataStore", -- If there's ever a problem with the datastore, change this key to reset all player data
	default_settings_tab = "Audio",
	slider_speed = 0.1,
	
	-- option customization
	option_config = {
		
		hovered = {
			transparency 				= 0.9,
			color 						= Color3.fromRGB(255, 255, 255),	
		},
		
		unhovered = {
			transparency 				= 1,
			color 						= Color3.fromRGB(255, 255, 255),	
		},
		
	},
	
	-- component customization
	component_config = {	
		
		boolean = {		
			-- enabled
			enabled_position 			= UDim2.new(0.75, 0, 0.5, 0),		
			enabled_backgroundcolor 	= Color3.fromRGB(255, 255, 255),
			enabled_textcolor 			= Color3.fromRGB(0, 0, 0),
			enabled_fontface 			= Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			
			-- disabled
			disabled_position 			= UDim2.new(0.25, 0, 0.5, 0),		
			disabled_backgroundcolor 	= Color3.fromRGB(0, 0, 0),
			disabled_textcolor 			= Color3.fromRGB(255, 255, 255),
			disabled_fontface 			= Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
		},
		
	},
	
	-- tab customization
	button_config = {
		
		active = {	
			background_transparency 	= 0,
			transparency 				= 0,
			color 						= Color3.fromRGB(0, 0, 0),
			fontface					= Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		},
		
		hovered = {	
			background_transparency 	= 1,
			transparency 				= 0,
			color 						= Color3.fromRGB(255, 255, 255),	
			fontface					= Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
		},
		
		unselected = {	
			background_transparency 	= 1,
			transparency 				= 0.75,
			color 						= Color3.fromRGB(255, 255, 255),		
			fontface					= Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		},
		
	},
	
	--[[
	
		TUTORIAL 
		
		
		All component classes:
		
		{class="range", default=1, min=0, max=2}, 							-- choose between a range of 0-1
		{class="boolean", default=false},											-- choose between boolean (true/false)
		{class="choice", default="Normal", choices={"Low", "Normal", "Highest"}},}	-- select between options (low, normal, and highest)

		IMPORTANT:
		
		1. If you ever add a new settings option it's vital you put the data in 'settings_options' and set the default value of it in 'default_settings' (beware: spelling errors may break or bug the system)

	]]
	
	-- settings data presets
	settings_tabs = {	
		
		{		
			name="Audio",
			image_id = "rbxassetid://7203392850"		
		},
		{
			name="Graphics",
			image_id = "rbxassetid://71693628644645"	
		},
		{
			name="Gameplay",
			image_id = "rbxassetid://11894535915"	
		},
		
	},
	settings_options = {
		
		["Audio"] = {
			{
				name="Music Volume",
				component={class="range", default=1, min=0, max=1, suffix="%"},
			},
			{
				name="Mute Music",
				component={class="boolean", default=false},
			},
			{
				name="SFX Volume",
				component={class="range", default=1, min=0, max=1, suffix="%"},
			},
			{
				name="Mute SFX",
				component={class="boolean", default=false},
			},
		},

		["Graphics"] = {
			{
				name="Shadows",
				component={class="boolean", default=true},
			},
			{
				name="Shadow Quality",
				component={class="choice", default="Normal", choices={"Lowest", "Normal", "Highest"}},
			},
			{
				name="Bloom",
				component={class="boolean", default=true},
			},
			{
				name="Sun Rays",
				component={class="boolean", default=true},
			},
		},

		["Gameplay"] = {
			{
				name="Field of View",
				component={class="range", default=60, min=30, max=90},
			},
		}
		
	},
	default_settings = {
		
		["Music Volume"] = 1,
		["Mute Music"] = false,
		["SFX Volume"] = 1,
		["Mute SFX"] = false,
			
		["Shadows"] = true,
		["Shadow Quality"] = "Normal",
		["Bloom"] = true,
		["Sun Rays"] = true,
		
		["Field of View"] = 60,
		
	},
	
}

return SettingsConfig
