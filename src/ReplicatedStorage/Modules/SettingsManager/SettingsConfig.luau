local SettingsConfig = {
	
	-- configuration
	datastore_key = "PlayerSettingsDataStore", 
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
				name="Third Person",
				component={class="boolean", default=true},
			},
			{
				name="Field of View",
				component={class="range", default=60, min=30, max=90},
			},
			
			{
				name="User Announcements",
				component={class="boolean", default = true},
			},
			{
				name="Allow Button Directions",
				component={class="boolean", default = true},
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
		
		["Third Person"] = true,
		["Field of View"] = 60,
		
		["User Announcements"] = true,
		["Allow Button Directions"] = true,
		
	},
	
}

return SettingsConfig
