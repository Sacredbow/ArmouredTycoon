--!strict

local ServerDiagnostics = {}

type ReportBucket = {
	lastReport: number,
	suppressed: number,
}

local DEFAULT_REPORT_WINDOW = 5
local reportBuckets: { [string]: ReportBucket } = {}

local function message(scope: string, detail: string): string
	return (`[{scope}] {detail}`)
end

local function reportKey(scope: string, key: string): string
	return scope .. "\0" .. key
end

function ServerDiagnostics.requireValue<T>(value: T?, scope: string, detail: string): T
	if value == nil then
		error(message(`Fatal:{scope}`, detail), 2)
	end

	return value
end

function ServerDiagnostics.invariant(condition: boolean, scope: string, detail: string)
	if not condition then
		error(message(`Fatal:{scope}`, detail), 2)
	end
end

function ServerDiagnostics.fatal(scope: string, detail: string)
	error(message(`Fatal:{scope}`, detail), 2)
end

function ServerDiagnostics.report(scope: string, detail: string)
	warn(message(scope, detail))
end

function ServerDiagnostics.reportThrottled(scope: string, key: string, detail: string, window: number?)
	local now = os.clock()
	local bucketKey = reportKey(scope, key)
	local bucket = reportBuckets[bucketKey]
	local reportWindow = window or DEFAULT_REPORT_WINDOW

	if bucket and now - bucket.lastReport < reportWindow then
		bucket.suppressed += 1
		return
	end

	local suffix = ""
	if bucket and bucket.suppressed > 0 then
		suffix = (` ({bucket.suppressed} repeated reports suppressed)`)
	end

	reportBuckets[bucketKey] = {
		lastReport = now,
		suppressed = 0,
	}
	warn(message(scope, detail .. suffix))
end

function ServerDiagnostics.reject(player: Player, surface: string, reason: string, window: number?)
	local identity = (`{player.UserId}:{reason}`)
	ServerDiagnostics.reportThrottled(
		`Security:{surface}`,
		identity,
		(`Rejected request from {player.Name} ({player.UserId}): {reason}`),
		window
	)
end

return ServerDiagnostics
