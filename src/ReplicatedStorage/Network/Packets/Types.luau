--!strict
--[[
	@class PacketTypes

	@desc
	All shared type definitions for the Bytenet packet/query namespace.
	Extracted from init.luau so type consumers don't need to require the
	entire runtime namespace just to read type definitions.
]]

export type Packet<T> = {
	sendToAll: (data: T) -> (),
	sendTo: (data: T, target: Player) -> (),
	sendToList: (data: T, targets: { Player }) -> (),
	send: (data: T) -> (),
	listen: (callback: (data: T, player: Player?) -> ()) -> () -> (),
	listenOnce: (callback: (data: T, player: Player?) -> ()) -> (),
	disconnectAll: () -> (),
}

export type Query<Request, Response> = {
	invoke: (request: Request) -> Response,
	listen: (callback: (request: Request, player: Player?) -> Response) -> () -> (),
	listenOnce: (callback: (request: Request, player: Player?) -> Response) -> (),
	disconnectAll: () -> (),
}

--[[
	Notification payload — pure UI toast/popup.
	Rendered by NotificationStack; never drives gameplay logic.
]]
export type NotificationPayload = {
	["type"]: string,
	message: string?,
	duration: number?,
}

--[[
	Tutorial payload — onboarding beam guidance.
	Consumed by Onboarding.client.luau for procedural beam rendering.
]]
export type TutorialPayload = {
	["type"]: string,
	target: string?,
}

--[[
	GameEvent payload — gameplay state transitions and UI actions.
	This is NOT for toasts — use Notification for that.

	Valid types (see GameEventPackets):
	- "CanRebirth"    → state flag for UI logic (PlayerRuntimeState)
	- "NotFollowing"  → lootbox panel open (MainInterface)
	- "Prompt"        → gamepass purchase prompt (MainInterface)
	- "SystemMessage" → text chat system message (Rocket, MainInterface)
]]
export type GameEventPayload = {
	["type"]: string,
	message: string?,
	valueBoolean: boolean?,
	valueNumber: number?,
	valueString: string?,
	amount: number?,
	position: Vector3?,
}

--[[
	Weather payload — full weather state sent to MapFramework for
	VFX/audio/nature transitions. Also consumed by GameStore for
	weather-change toast deduplication.
]]
export type WeatherPayload = {
	["type"]: string,
	duration: number,
	windDirection: Vector3,
	windSpeed: number,
	windPower: number,
	rainIntensity: number,
	thunderChance: number,
	lightingWeight: number,
}

export type WeatherChangedPayload = {
	weatherId: string,
	displayName: string,
	duration: number,
}

export type WeaponStatePayload = {
	["type"]: string,
	weaponName: string?,
	stance: number?,
	lean: number?,
}

export type CashCollectedPayload = {
	amount: number,
	origin: Vector3,
}

export type StatSyncPayload = {
	stat: string,
	value: number,
}

export type FriendBoostPayload = {
	["type"]: string,
	percent: number,
}

export type KOTHAnnouncementPayload = {
	playerName: string,
	teamColor: Color3,
	minutes: number?,
}

export type NPCConversationPayload = {
	action: string,
	conversationId: string?,
	npcName: string?,
	npcLine: string?,
	turnCount: number?,
	maxTurns: number?,
	reason: string?,
	options: { { id: string, text: string, tone: string } }?,
}

export type NPCConversationChoicePayload = {
	action: string,
	conversationId: string,
	optionId: string?,
}

export type NPCSpeechPayload = {
	adornee: Instance,
	message: string,
}

export type NukeCinematicPayload = {
	action: string,
	sessionId: string?,
	role: string?,
	phase: string?,
	message: string?,
	launcherName: string?,
	defenderName: string?,
	launcherUserId: string?,
	defenderUserId: string?,
	winnerName: string?,
	targetPosition: Vector3?,
	sourcePosition: Vector3?,
	distance: number?,
	deathRange: number?,
	timeLeft: number?,
	launcherScore: number?,
	defenderScore: number?,
}

export type NukeClickBatchPayload = {
	sessionId: string,
	count: number,
	clientWindow: number,
}

export type NukeTargetPayload = {
	target: string,
}

export type InventoryActionPayload = {
	action: string,
	tool: Instance?,
}

export type ActionRequest = {
	action: string,
	payload: string?,
}

export type CodeRedeemRequest = {
	code: string,
}

export type ActionResponse = {
	success: boolean,
	message: string,
}
