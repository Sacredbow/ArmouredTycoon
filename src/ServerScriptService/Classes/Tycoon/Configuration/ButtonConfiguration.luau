--!strict

export type ButtonKind = "Basic" | "Rebirth"

export type PurchaseConfig = {
	Price: number?,
	Kind: ButtonKind,
	Gamepass: string?,
}

export type BuildConfig = {
	Items: { string },
}

export type ProgressionConfig = {
	Reveals: { string },
	StartsVisible: boolean?,
}

export type ButtonConfig = {
	Purchase: PurchaseConfig,
	Build: BuildConfig,
	Progression: ProgressionConfig,
}

local ButtonConfiguration = {}

local InstanceMetadata = {
	"Price",
	"Type",
	"Dependency",
	"Dependencies",
	"Unlocks",
	"Gamepass",
}

local function Button(Config: ButtonConfig): ButtonConfig
	return Config
end

ButtonConfiguration.Buttons = {
	Button1 = Button({
		Purchase = { Price = 0, Kind = "Basic" },
		Build = { Items = { "NormalDropper1" } },
		Progression = { Reveals = { "Button2", "Button3" }, StartsVisible = true },
	}),
	Button2 = Button({
		Purchase = { Price = 150, Kind = "Basic" },
		Build = { Items = { "NormalDropper2" } },
		Progression = { Reveals = { "Button4", "Button5" } },
	}),
	Button3 = Button({
		Purchase = { Price = 750, Kind = "Basic" },
		Build = { Items = { "IronDropper1" } },
		Progression = { Reveals = { "Button7" } },
	}),
	Button4 = Button({
		Purchase = { Kind = "Basic", Gamepass = "GoldenDropper" },
		Build = { Items = { "GoldenDropper" } },
		Progression = { Reveals = {  } },
	}),
	Button5 = Button({
		Purchase = { Price = 500, Kind = "Basic" },
		Build = { Items = { "BasicUpgrader" } },
		Progression = { Reveals = { "Button6" } },
	}),
	Button6 = Button({
		Purchase = { Price = 2750, Kind = "Basic" },
		Build = { Items = { "EnchancedUpgrader" } },
		Progression = { Reveals = {} },
	}),
	Button7 = Button({
		Purchase = { Price = 4250, Kind = "Basic" },
		Build = { Items = { "EliteDropper" } },
		Progression = { Reveals = { "Button12" } },
	}),
	Button8 = Button({
		Purchase = { Price = 1000, Kind = "Basic" },
		Build = { Items = { "Padding" } },
		Progression = { Reveals = { "Button9", "Button10", "Button11", "Button52" } },
	}),
	Button9 = Button({
		Purchase = { Price = 6500, Kind = "Basic" },
		Build = { Items = { "M4A1" } },
		Progression = { Reveals = {} },
	}),
	Button10 = Button({
		Purchase = { Price = 4000, Kind = "Basic" },
		Build = { Items = { "Micro Uzi" } },
		Progression = { Reveals = {} },
	}),
	Button11 = Button({
		Purchase = { Price = 1500, Kind = "Basic" },
		Build = { Items = { "Glock 18C" } },
		Progression = { Reveals = {} },
	}),
	Button12 = Button({
		Purchase = { Price = 100, Kind = "Basic" },
		Build = { Items = { "BackWall", "WallSide", "WallSide2" } },
		Progression = { Reveals = { "Button13" } },
	}),
	Button13 = Button({
		Purchase = { Price = 1250, Kind = "Basic" },
		Build = { Items = { "DoorSupport", "DoorSupport2", "WindowsHolder", "WindowsSupport", "WindowsSupport(Right)" } },
		Progression = { Reveals = {"Button14"} },
	}),
	Button14 = Button({
		Purchase = { Price = 3800, Kind = "Basic" },
		Build = { Items = { "WindowBASE", "WindowsBase2" } },
		Progression = { Reveals = { "Button15" } },
	}),
	Button15 = Button({
		Purchase = { Price = 3900, Kind = "Basic" },
		Build = { Items = { "BaseRoof", "BaseRoof2", "BaseRoof3", "BaseRoof4" } },
		Progression = { Reveals = { "Button8", "Button30", "Button31", "Button38" } },
	}),
	Button16 = Button({
		Purchase = { Price = 7000, Kind = "Basic" },
		Build = { Items = { "Stairs" } },
		Progression = { Reveals = { "Button17", "Button39" } },
	}),
	Button17 = Button({
		Purchase = { Price = 15000, Kind = "Basic" },
		Build = { Items = { "FloorBase1", "FloorBase2", "FloorBase3", "FloorBase4", "FloorBase5", "FloorBase6" } },
		Progression = { Reveals = { "Button29", "Button44" } },
	}),
	Button18 = Button({
		Purchase = { Price = 20000, Kind = "Basic" },
		Build = { Items = { "Windows1", "Windows2", "Windows3", "Windows4" } },
		Progression = { Reveals = { "Button19" } },
	}),
	Button19 = Button({
		Purchase = { Price = 7000, Kind = "Basic" },
		Build = { Items = { "BaseHolder1", "BaseHolder2", "BaseHolder3", "BaseHolder4" } },
		Progression = { Reveals = { "Button20" } },
	}),
	Button20 = Button({
		Purchase = { Price = 4000, Kind = "Basic" },
		Build = { Items = { "BH1", "TopBar1", "TopBar2", "TopBar3", "TopBar4", "TopBar5", "TopBar6" } },
		Progression = { Reveals = { "Button21" } },
	}),
	Button21 = Button({
		Purchase = { Price = 16000, Kind = "Basic" },
		Build = { Items = { "Windows7", "Windows8" } },
		Progression = { Reveals = { "Button22" } },
	}),
	Button22 = Button({
		Purchase = { Price = 35000, Kind = "Basic" },
		Build = { Items = { "Holder1", "Holder2", "Holder3", "Holder4", "Holder5", "Holder6" } },
		Progression = { Reveals = { "Button23", "Button33", "Button34", "Button35", "Button36" } },
	}),
	Button23 = Button({
		Purchase = { Price = 125000, Kind = "Basic" },
		Build = { Items = { "DoorPart1", "DoorPart2", "DoorPart3" } },
		Progression = { Reveals = { "Button24" } },
	}),
	Button24 = Button({
		Purchase = { Price = 75000, Kind = "Basic" },
		Build = { Items = { "BasePart1", "BasePart2", "BasePart3", "TopFloor1", "TopFloor2" } },
		Progression = { Reveals = { "Button47" } },
	}),
	Button25 = Button({
		Purchase = { Price = 5000, Kind = "Basic" },
		Build = { Items = { "RoofHolder1", "RoofHolder2" } },
		Progression = { Reveals = { "Button26" } },
	}),
	Button26 = Button({
		Purchase = { Price = 85000, Kind = "Basic" },
		Build = { Items = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } },
		Progression = { Reveals = { "Button27", "Button51" } },
	}),
	Button27 = Button({
		Purchase = { Price = 14000,
		
		Kind = "Basic" 
	
	},
		Build = { Items = { "Teleporter" } },
		Progression = { Reveals = { "Button28" } },
	}),
	Button28 = Button({
		Purchase = { Price = 100000, Kind = "Basic" },
		Build = { Items = { "HighFloor1", "HighFloor2", "HighFloor3", "HighFloor4" } },
		Progression = { Reveals = {} },
	}),
	Button29 = Button({
		Purchase = { Price = 13500, Kind = "Basic" },
		Build = { Items = { "Lasers" } },
		Progression = { Reveals = { "Button41", "Button42" } },
	}),
	Button30 = Button({
		Purchase = { Price = 3000, Kind = "Basic" },
		Build = { Items = { "CeilingLights1" } },
		Progression = { Reveals = { "Button44", "Button45" } },
	}),
	Button31 = Button({
		Purchase = { Price = 3000, Kind = "Basic" },
		Build = { Items = { "CeilingLights2" } },
		Progression = { Reveals = {} },
	}),
	Button32 = Button({
		Purchase = { Price = 70000, Kind = "Basic" },
		Build = { Items = { "1b", "1g", "1r", "2b", "2g", "2r", "3b", "3g", "3r" } },
		Progression = { Reveals = { "Button17" } },
	}),
	Button33 = Button({
		Purchase = { Price = 20000, Kind = "Basic" },
		Build = { Items = { "M870" } },
		Progression = { Reveals = {} },
	}),
	Button34 = Button({
		Purchase = { Price = 10000, Kind = "Basic" },
		Build = { Items = { "Knife" } },
		Progression = { Reveals = {} },
	}),
	Button35 = Button({
		Purchase = { Price = 35000, Kind = "Basic" },
		Build = { Items = { "MP5" } },
		Progression = { Reveals = {} },
	}),
	Button36 = Button({
		Purchase = { Price = 15000, Kind = "Basic" },
		Build = { Items = { "AK-47" } },
		Progression = { Reveals = { "Button53" } },
	}),
	Button38 = Button({
		Purchase = { Price = 50000, Kind = "Basic" },
		Build = { Items = { "GunRange" } },
		Progression = { Reveals = {} },
	}),
	Button39 = Button({
		Purchase = { Price = 75000, Kind = "Basic" },
		Build = { Items = { "AmmoArea" } },
		Progression = { Reveals = {} },
	}),
	Button40 = Button({
		Purchase = { Price = 4000, Kind = "Basic" },
		Build = { Items = { "Accessories" } },
		Progression = { Reveals = { "Button16" } },
	}),
	Button41 = Button({
		Purchase = { Price = 80000, Kind = "Basic" },
		Build = { Items = { "Armour1" } },
		Progression = { Reveals = {} },
	}),
	Button42 = Button({
		Purchase = { Price = 120000, Kind = "Basic" },
		Build = { Items = { "Armour2" } },
		Progression = { Reveals = {} },
	}),
	Button43 = Button({
		Purchase = { Price = 60000, Kind = "Basic" },
		Build = { Items = { "FUSE_BOX" } },
		Progression = { Reveals = { "Button32" } },
	}),
	Button44 = Button({
		Purchase = { Price = 14000, Kind = "Basic" },
		Build = { Items = { "TycoonPathway" } },
		Progression = { Reveals = { "Button18", "Button40" } },
	}),
	Button45 = Button({
		Purchase = { Price = 150000, Kind = "Basic" },
		Build = { Items = { "Outer" } },
		Progression = { Reveals = { "Button43", "Button46" } },
	}),
	Button46 = Button({
		Purchase = { Price = 32000, Kind = "Basic" },
		Build = { Items = { "LabDoor" } },
		Progression = { Reveals = { "Button43", "Button46" } },
	}),
	Button47 = Button({
		Purchase = { Price = 80000, Kind = "Basic" },
		Build = { Items = { "MoneyDuplicator2" } },
		Progression = { Reveals = { "Button48", "Button49" } },
	}),
	Button48 = Button({
		Purchase = { Price = 80000, Kind = "Basic" },
		Build = { Items = { "MoneyDuplicator4" } },
		Progression = { Reveals = {} },
	}),
	Button49 = Button({
		Purchase = { Price = 80000, Kind = "Basic" },
		Build = { Items = { "MoneyDuplicator1" } },
		Progression = { Reveals = { "Button50" } },
	}),
	Button50 = Button({
		Purchase = { Price = 800000, Kind = "Basic" },
		Build = { Items = { "MoneyDuplicator3" } },
		Progression = { Reveals = { "Button25", "Button48", "Button49" } },
	}),
	Button51 = Button({
		Purchase = { Price = 1000000, Kind = "Basic" },
		Build = { Items = { "ButtonStand", "Rocket", "RocketConstruction" } },
		Progression = { Reveals = {} },
	}),
	Button52 = Button({
		Purchase = { Price = 1, Kind = "Rebirth" },
		Build = { Items = { "GoldenAK47" } },
		Progression = { Reveals = {} },
	}),
	Button53 = Button({
		Purchase = { Price = 3, Kind = "Rebirth" },
		Build = { Items = { "GoldenASVAL" } },
		Progression = { Reveals = { "Button54", "Button55" } },
	}),
	Button54 = Button({
		Purchase = { Price = 4, Kind = "Rebirth" },
		Build = { Items = { "GoldenHK33" } },
		Progression = { Reveals = {} },
	}),
	Button55 = Button({
		Purchase = { Price = 2, Kind = "Rebirth" },
		Build = { Items = { "Golden M1911" } },
		Progression = { Reveals = {} },
	}),
} :: { [string]: ButtonConfig }

function ButtonConfiguration.Get(ButtonName: string): ButtonConfig?
	return ButtonConfiguration.Buttons[ButtonName]
end

function ButtonConfiguration.GetPrice(Config: ButtonConfig): number?
	return Config.Purchase.Price
end

function ButtonConfiguration.GetKind(Config: ButtonConfig): ButtonKind
	return Config.Purchase.Kind
end

function ButtonConfiguration.GetGamepass(Config: ButtonConfig): string?
	return Config.Purchase.Gamepass
end

function ButtonConfiguration.GetBuildItems(Config: ButtonConfig): { string }
	return Config.Build.Items
end

function ButtonConfiguration.GetRevealedButtons(Config: ButtonConfig): { string }
	return Config.Progression.Reveals
end

function ButtonConfiguration.StartsVisible(Config: ButtonConfig): boolean
	return Config.Progression.StartsVisible == true
end

function ButtonConfiguration.RemoveInstanceMetadata(ButtonPart: BasePart)
	for _, ChildName in InstanceMetadata do
		local Child = ButtonPart:FindFirstChild(ChildName)
		if Child then
			Child:Destroy()
		end
	end
end

function ButtonConfiguration.ApplyVisual(ButtonPart: BasePart, Config: ButtonConfig)
	ButtonConfiguration.RemoveInstanceMetadata(ButtonPart)

	local Enabled = ButtonConfiguration.StartsVisible(Config)
	ButtonPart.Transparency = if Enabled then 0 else 1
	ButtonPart.CanCollide = Enabled
	ButtonPart.CanTouch = Enabled

	local Neon = ButtonPart:FindFirstChild("Neon")
	if Neon and Neon:IsA("BasePart") then
		Neon.Transparency = if Enabled then 0 else 1
	end
end

return ButtonConfiguration
