--!strict
--[[
	@class OnboardingDefinitions

	@desc
	Single reference for the onboarding message types. Both the server
	(ClaimSystem) and the client (Onboarding.client.luau) read the message
	type strings from here instead of hardcoding magic strings in each file.

	The onboarding flow is server-driven via the Tutorial packet. The packet
	`type` field distinguishes each step; the client branches on it. Keeping
	these constants in one shared module prevents drift between the two sides
	(typos / renamed strings silently breaking the tutorial).
]]

--// Types

export type OnboardingStepKey =
	"ClaimComplete"
	| "PurchaseButton"
	| "ClaimMoney"
	| "Completed"

--// Step Message Types (Tutorial packet `type` values)

export type OnboardingStep = {
	Id: OnboardingStepKey,
	Message: string,
	Target: string?,
}

-- Ordered flow.
const STEPS: { OnboardingStep } = {
	{
		Id = "ClaimComplete",
		Message = "Perfect!",
		Target = nil,
	},
	{
		Id = "PurchaseButton",
		Message = "Now purchase your first button!",
		Target = "Buttons:Button1",
	},
	{
		Id = "ClaimMoney",
		Message = "Claim your money",
		Target = "MainItems:ATM:Display",
	},
	{
		Id = "Completed",
		Message = "Congrats! Tutorial Completed.",
		Target = nil,
	},
}

const STEP_BY_KEY: { [OnboardingStepKey]: OnboardingStep } = {
	ClaimComplete = STEPS[1],
	PurchaseButton = STEPS[2],
	ClaimMoney = STEPS[3],
	Completed = STEPS[4],
}

return {
	STEPS = STEPS,
	STEP_BY_KEY = STEP_BY_KEY,
}
