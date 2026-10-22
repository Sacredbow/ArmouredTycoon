--[[

 _   _                ____  _                   _
| \ | | _____      __/ ___|(_) __ _ _ __   __ _| |
|  \| |/ _ \ \ /\ / /\___ \| |/ _` | '_ \ / _` | |
| |\  |  __/\ V  V /  ___) | | (_| | | | | (_| | |
|_| \_|\___| \_/\_/  |____/|_|\__, |_| |_|\__,_|_|
                              |___/

Me when I Signal for Newgens

Made by Jerryx77 aka Jerryx0709

This Project is licensed under the MIT License, see LICENSE for more details.

This project is still work in progress and may still contain some bugs.

]]

-- Version: 3.1.1

--!strict
--!optimize 2

-- Config

type FireMethods = "FireAsync" | "FireDeferred" | "FireSafe"

local DefaultFireMethod: FireMethods = "FireAsync"

export type Connection<T... = ()> = {
	Disconnect: (self: Connection<T...>) -> (),

	[number]: any, -- Internal slots:
	--[[

	[1]: boolean -- Connected
	[2]: Signal<T...> -- Signal Parent
	[3]: (T...) -> () -- Callback
	[4]: Connection<T...>? -- Previous
	[5]: Connection<T...>? -- Next
	[6]: number? -- Pending State (nil, 1 for Add, 2 for Remove)

	]]
}

export type Signal<T... = ()> = {
	Connect: (self: Signal<T...>, Callback: (T...) -> ()) -> Connection<T...>,
	Once: (self: Signal<T...>, Callback: (T...) -> ()) -> Connection<T...>,
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	FireAsync: (self: Signal<T...>, T...) -> (),
	FireSafe: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),


	[number]: any, -- Internal slots:
	--[[

	[1]: Connection<T...>? -- Head
	[2]: Connection<T...>? -- Tail
	[3]: boolean? -- Firing (nil if not finring, true if firing)
	[4]: {Kind: number, Connection<T...>?}? -- Mutation Queue (Kind: 1 for Add, 2 for Remove, 3 for Disconnect All)
	[5]: {thread}? -- Reentrants Queue (Will be changed to {FireKind: number, Args: {...: any}?}?)
	[6]: number? -- Reentrant Head
	[7]: number? -- Reentrant Tail
	[8]: {[thread]: boolean}? -- Waiting Threads
	[9]: {Connection<T...>}? -- Connection Cleanup Queue
	[10]: string? -- Registry Id

	]]
}



-- Classes

--[=[
@class Signal

A Signal is a class that is used to substitute the use of Bindable Events, this implementation
tries to handle most of the edge cases that could happen, while being as performant as possible,
with additional features for Advanced users such as selectable disconnect mode.

This implementation tries to have similar API to the standard signal module, [GoodSignal](https://devforum.roblox.com/t/lua-signal-class-comparison-optimal-goodsignal-class/1387063),
with some additional features.

Quick example:
```lua
local NewSignal = require(path.to.NewSignal)

-- Create a signal
local Signal = NewSignal.new()

-- Connect a listener
local Connection = Signal:Connect(function(Param)
    print(`The Signal Got fired, param: {Param}`)
end)

-- Fire the signal with the default method
Signal:Fire("Hello")

-- Disconnect the listener
Connection:Disconnect()
```
]=]
local Signal = {}
Signal.__index = Signal

--[=[
@class Connection

A Connection is a Class used to manage the connection between a listener and a signal,
it is returned when connecting to a signal, and can be used to disconnect the listener from the signal.
]=]
local Connection = {}
Connection.__index = Connection


-- Thread reusing protocol

local CachedThread: thread? = nil
local ThreadPool = {} :: {thread}

const function CallThread(Thread: thread, Callback: (...any) -> (), ...: any): ()
	Callback(...)

	if CachedThread then
		ThreadPool[#ThreadPool + 1] = Thread
	else
		CachedThread = Thread
	end
end

const function YieldThread(): ()
	while true do
		CallThread(coroutine.yield())
	end
end

const function GetThread(): thread
	if CachedThread then
		local RunnerThread = CachedThread
		CachedThread = nil

		if coroutine.status(RunnerThread) == "suspended" then
			return RunnerThread
		end
	end

	local Amount = #ThreadPool
	if Amount == 0 then return task.spawn(YieldThread) end

	local RunnerThread = ThreadPool[Amount]
	ThreadPool[Amount] = nil

	if coroutine.status(RunnerThread) ~= "suspended" then
		return task.spawn(YieldThread)
	end

	return RunnerThread
end

-- Private Functions

const function QueueMutation<T...>(ConnectionObj: Connection<T...>? | number, Kind: number, SignalObj: Signal<T...>): () -- number in ConnectionObj to allow DisconnectAll
	local Queue : {any} = SignalObj[4]

	if not Queue then
		Queue = {}
		SignalObj[4] = Queue
	end

	local Tail = #Queue
	Queue[Tail + 1] = Kind
	Queue[Tail + 2] = ConnectionObj
end

const function QueueDisconnectedCleanup<T...>(SignalObj: Signal<T...>, ConnectionObj: Connection<T...>): ()
	local Queue: {Connection<T...>}? = SignalObj[9]

	if not Queue then
		Queue = {}
		SignalObj[9] = Queue
	end

	local CleanupQueue = Queue :: {Connection<T...>}
	CleanupQueue[#CleanupQueue + 1] = ConnectionObj
end

const function CleanupDisconnectedConnections<T...>(SignalObj: Signal<T...>): ()
	local Queue: {Connection<T...>}? = SignalObj[9]
	if not Queue then return end

	for _, ConnectionObj in Queue do
		ConnectionObj[2] = nil
		ConnectionObj[3] = nil
		ConnectionObj[4] = nil
		ConnectionObj[5] = nil
	end

	table.clear(Queue)
end


const function DisconnectConnection<T...>(ConnectionObj: Connection<T...>): ()
	if not ConnectionObj[1] then return end

	ConnectionObj[1] = false
	ConnectionObj[6] = nil

	local SignalObj: Signal<T...> = ConnectionObj[2]

	local Previous: Connection<T...>? = ConnectionObj[4]
	local Next: Connection<T...>? = ConnectionObj[5]

	if Next then
		Next[4] = Previous
	else
		SignalObj[2] = Previous
	end

	if Previous then
		Previous[5] = Next
	else
		SignalObj[1] = Next
	end

	if SignalObj[3] then
		QueueDisconnectedCleanup(SignalObj, ConnectionObj)
	else
		ConnectionObj[2] = nil
		ConnectionObj[3] = nil
		ConnectionObj[4] = nil
		ConnectionObj[5] = nil
	end

end

const function AddConnection<T...>(ConnectionObj: Connection<T...>): ()
	local SignalObj: Signal<T...> = ConnectionObj[2]

	local Tail: Connection<T...>? = SignalObj[2]
	ConnectionObj[6] = nil
	ConnectionObj[4] = Tail
	ConnectionObj[5] = nil

	if Tail then
		Tail[5] = ConnectionObj
	else
		SignalObj[1] = ConnectionObj
	end

	SignalObj[2] = ConnectionObj
end

const function CreateConnection<T...>(SignalObj: Signal<T...>, Callback: (T...) -> ()): Connection<T...>
	local NewConnection: Connection<T...> = setmetatable({
		[1] = true, -- Connected
		[2] = SignalObj, -- Signal Parent
		[3] = Callback, -- Callback
		[4] = nil, -- Previous
		[5] = nil, -- Next
		[6] = nil, -- Pending (nil, Add (1), Remove (2))
	}, Connection) :: Connection<T...>

	if SignalObj[3] then
		NewConnection[6] = 1
		QueueMutation(NewConnection, 1, SignalObj)
	else
		AddConnection(NewConnection)
	end

	return NewConnection
end

const function AddReentrantFire<T...>(SignalObj: Signal<T...>): ()
	local Reentrants = SignalObj[5]
	if not Reentrants then
		Reentrants = {}
		SignalObj[5] = Reentrants
		SignalObj[6] = 1
		SignalObj[7] = 0
	end

	local Tail = (SignalObj[7] or 0) + 1
	SignalObj[7] = Tail
	Reentrants[Tail] = coroutine.running()
	coroutine.yield()
end

const function DisconnectExisting<T...>(SignalObj: Signal<T...>): ()
	local CurrConnection: Connection<T...>? = SignalObj[2]
	if not CurrConnection then
		return
	end

	while CurrConnection do
		local Previous = CurrConnection[4]

		CurrConnection[1] = false
		CurrConnection[6] = nil
		if SignalObj[3] then
			QueueDisconnectedCleanup(SignalObj, CurrConnection)
		else
			CurrConnection[2] = nil
			CurrConnection[3] = nil
			CurrConnection[4] = nil
			CurrConnection[5] = nil
		end

		CurrConnection = Previous
	end

	SignalObj[1] = nil
	SignalObj[2] = nil
end

const function ProcessMutations<T...>(SignalObj: Signal<T...>): ()
	local Queue = SignalObj[4]
	if not Queue then return end

	local Size = #Queue
	if Size == 0 then return end

	local Index = 1
	while Index <= Size do
		local Kind = Queue[Index]
		local ConnectionObj: Connection<T...> = Queue[Index + 1]

		if Kind == 1 then
			ConnectionObj[6] = nil

			if ConnectionObj[1] then
				AddConnection(ConnectionObj)
			end

		elseif Kind == 2 then

			if ConnectionObj[6] == 1 then
				ConnectionObj[1] = false
				ConnectionObj[2] = nil
				ConnectionObj[3] = nil
				ConnectionObj[6] = nil
			elseif ConnectionObj[1] then
				DisconnectConnection(ConnectionObj)
			end

		elseif Kind == 3 then
			DisconnectExisting(SignalObj)
		end

		Index += 2
	end

	table.clear(Queue)
end

const function ResumeReentrant<T...>(SignalObj: Signal<T...>): ()
	local Head: number = SignalObj[6] or 1
	local Tail: number = SignalObj[7] or 0

	if Head <= Tail then
		local Reentrants = SignalObj[5]
		local ReentrantThread = Reentrants[Head]
		Reentrants[Head] = nil

		Head += 1
		if Head > Tail then
			SignalObj[6] = 1
			SignalObj[7] = 0
		else
			SignalObj[6] = Head
		end

		SignalObj[3] = true
		-- Slight Deferred behaviour to match up with Scheduler
		-- coroutine.resume Could be used here
		task.spawn(ReentrantThread)
	else
		CleanupDisconnectedConnections(SignalObj)
		SignalObj[3] = nil
	end
end

const function ProtectedInvoke(Callback: (...any) -> (), ...: any): ()
	local ErrorMessage: string? = nil

	const function TracebackHandler(Error: any): string
		ErrorMessage = debug.traceback(tostring(Error), 2)
		return ErrorMessage
	end

	local Success = xpcall(Callback, TracebackHandler, ...)
	if not Success then
		warn(`[NewSignal] Error calling connection callback: {ErrorMessage or "unknown error"}`)
	end
end

const function StartFiring<T...>(SignalObj: Signal<T...>): ()
	if SignalObj[3] then
		AddReentrantFire(SignalObj)
	else
		SignalObj[3] = true
	end
end

const function EndFiring<T...>(SignalObj: Signal<T...>): ()
	ProcessMutations(SignalObj)
	ResumeReentrant(SignalObj)
end


-- Public API

-- Connection Class

--[=[
Disconnects a connection from a Signal, any future `:Fire` calls
will not invoke this connection's listener.

@within Connection
```lua
local Connection = Signal:Connect(function(Args) end)
Connection:Disconnect()
```
]=]
function Connection:Disconnect<T...>(): ()
	self = self :: Connection<T...>
	if not self[1] then return end
	local SignalObj: Signal<T...> = self[2]

	local PendingStatus: number? = self[6]

	if SignalObj[3] then
		if PendingStatus == 1 then
			self[1] = false
			self[2] = nil
			self[3] = nil
			self[6] = nil
			return
		end

		if self[6] == 2 then return end

		self[6] = 2
		QueueMutation(self, 2, SignalObj)
		return
	end

	DisconnectConnection(self)
end

-- Signal Class

local Signals: {[string]: Signal<...any>} = {}

--[=[
Creates a new Signal object

@function new
@within Signal
@return Signal
```lua
local Signal = NewSignal.new()
```
]=]
const function New<T...>(): Signal<T...>
	return setmetatable({}, Signal) :: Signal<T...>
end

--[=[
Gets an existing Signal object with the given Id, or creates a new one if it doesn't exist.

@function get
@within Signal
@return Signal
```lua
local Signal = NewSignal.get("MySignal")
```
]=]
const function Get<T...>(Id: string): Signal<T...>
	local Existing = Signals[Id]
	if Existing then
		return Existing
	end

	local Created = New()
	Created[10] = Id
	Signals[Id] = Created

	return Created
end

--[=[
Connects a function to the signal, which will be called everytime the signal is fired.

@param Callback (...) -> ()
@return Connection
```lua
Signal:Connect(function(Message, Number)
	print(Message, Number)
end)

Signal:Fire("Hello", 25)
```
]=]
function Signal:Connect<T...>(Callback: (T...) -> ()): Connection<T...>
	return CreateConnection(self, Callback)
end

--[=[
Connects a function to the signal, which will be called once and disconnected immediatly.

@param Callback (...) -> ()
@return Connection
```lua
Signal:Once(function(Message, Number)
	print(Message, Number)
end)

Signal:Fire("Hello", 25)
Signal:Fire("This message will not get printed", 10)
```
]=]
function Signal:Once<T...>(Callback: (T...) -> ()): Connection<T...>
	local Called = false
	local ConnectionObj: Connection<T...>
	ConnectionObj = CreateConnection(self, function(...)
		if Called then return end
		Called = true
		DisconnectConnection(ConnectionObj)
		Callback(...)
	end)

	return ConnectionObj
end

--[=[
Yields the current thread until `:Fire` occurs, and returns the arguments fired from the signal.

@return ... any
@yields
```lua
task.spawn(function()
	print(Signal:Wait()) --> "Test", 89, nil, false
end)
Signal:Fire("Test", 89, nil, false)
```
]=]
function Signal:Wait<T...>(): T...
	local YieldedThreads: {[thread]: boolean} = self[8]
	if not YieldedThreads then
		YieldedThreads = {}
		self[8] = YieldedThreads
	end

	local WaitingThread = coroutine.running()
	YieldedThreads[WaitingThread] = true

	local Fired = false
	local PackedArgs: {any}? = nil
	local ArgCount = 0

	local ConnectionObj: Connection<T...>
	ConnectionObj = CreateConnection(self, function(...)
		if Fired then return end

		Fired = true
		DisconnectConnection(ConnectionObj)
		YieldedThreads[WaitingThread] = nil

		PackedArgs = table.pack(...)
		ArgCount = (PackedArgs or ({} :: {n: number, [number]: any})).n or 0

		if coroutine.status(WaitingThread) == "suspended" then
			task.spawn(WaitingThread, table.unpack(PackedArgs, 1, ArgCount))
		end
	end)

	if Fired and PackedArgs then
		return table.unpack(PackedArgs, 1, ArgCount)
	end

	return coroutine.yield()
end

--[=[
Fires a Signal object Asynchronously with the arguments passed.

@param ... any
```lua
Signal:Connect(function(Text)
	print(Text) --> "Something..."
end)

Signal:FireAsync("Something...")
```
]=]
function Signal:FireAsync<T...>(...: T...): ()

	StartFiring(self)

	local CurrentConnection: Connection<T...>? = self[1]

	while CurrentConnection do
		local NextConnection = CurrentConnection[5]
		if CurrentConnection[1] then
			local RunnerThread = GetThread()
			task.spawn(RunnerThread, RunnerThread, CurrentConnection[3], ...)
		end
		CurrentConnection = NextConnection
	end

	EndFiring(self)
end

--[=[
Fires a Signal object with the arguments passed with a `task.defer`.
Doesn't take use of the thread recicling protocol.

@param ... any
```lua
Signal:Connect(function(Text)
	print(Text) --> "Something..."
end)

Signal:FireDeferred("Something...")
```
]=]
function Signal:FireDeferred<T...>(...: T...): ()

	StartFiring(self)

	local CurrentConnection: Connection<T...>? = self[1]

	while CurrentConnection do
		local NextConnection = CurrentConnection[5]
		if CurrentConnection[1] then
			task.defer(CurrentConnection[3], ...)
		end
		CurrentConnection = NextConnection
	end

	EndFiring(self)
end

--[=[
Fires a Signal object asynchronously with the arguments passed using a `xpcall`.

@param ... any
```lua
Signal:Connect(function(Text)
	print(Text) --> "Something..."
end)

Signal:FireSafe("Something...")
```
]=]
function Signal:FireSafe<T...>(...: T...): ()

	StartFiring(self)

	local CurrentConnection: Connection<T...>? = self[1]

	while CurrentConnection do
		local NextConnection = CurrentConnection[5]
		if CurrentConnection[1] then
			local RunnerThread = GetThread()
			task.spawn(RunnerThread, RunnerThread, ProtectedInvoke, CurrentConnection[3], ...)
		end
		CurrentConnection = NextConnection
	end

	EndFiring(self)
end

--[=[
Disconnects all current Connections from the Signal.

```lua
Signal:Connect(function(Args) end)

Signal:DisconnectAll()
```
]=]
function Signal:DisconnectAll<T...>(): ()

	if self[3] then
		QueueMutation(0, 3, self)
	else
		DisconnectExisting(self)
	end

	local YieldedThreads: {[thread]: boolean}? = self[8]
	if not YieldedThreads then return end

	for Thread in YieldedThreads do
		if coroutine.status(Thread) == "suspended" then
			warn(debug.traceback(Thread, "Signal Disconnected. Yielded thread cancelled", 2))
			task.cancel(Thread)
		end
	end

	table.clear(YieldedThreads)
end

--[=[
Destroys a Signal object, disconnecting all connections and making it unusable.

```lua
Signal:Connect(function(Args) end)

Signal:Destroy() -- Destroys the signal and disconnects all connections
```
]=]
function Signal:Destroy<T...>()
	local Id = self[10]
	if Id and Signals[Id] == self then
		Signals[Id] = nil
	end

	local MutationQueue: {any}? = self[4]
	if MutationQueue then
		local Size = #MutationQueue
		local Index = 1

		while Index <= Size do
			local Kind = MutationQueue[Index]

			if Kind == 1 or Kind == 2 then
				local ConnectionObj = MutationQueue[Index + 1] :: Connection<T...>

				ConnectionObj[1] = false
				ConnectionObj[4] = nil
				ConnectionObj[5] = nil
				ConnectionObj[6] = nil
			end

			Index += 2
		end

		table.clear(MutationQueue)
	end

	DisconnectExisting(self)

	local Reentrants: {thread}? = self[5]
	if Reentrants then
		for _, Thread in Reentrants do
			if coroutine.status(Thread) == "suspended" then
				task.cancel(Thread)
			end
		end

		table.clear(Reentrants)
	end

	local YieldedThreads: {[thread]: boolean}? = self[8]
	if YieldedThreads then
		for Thread in YieldedThreads do
			if coroutine.status(Thread) == "suspended" then
				warn(debug.traceback(Thread, "Signal Destroyed. Yielded thread cancelled", 2))
				task.cancel(Thread)
			end
		end

		table.clear(YieldedThreads)
	end

	CleanupDisconnectedConnections(self)

	table.clear(self)
	setmetatable(self, nil)
end



--[=[
Alias for FireAsync by default.
Can be changed to any of the other fire methods by modiying the `DefaultFireMethod` variable.

@within Signal
@method Fire
```lua
Signal:Connect(function(Text)
	print(Text) --> "Something..."
end)

Signal:Fire("Something...") -- Same behaviour as `FireAsync` by default
```
]=]
Signal.Fire = Signal[DefaultFireMethod]

return table.freeze({
	new = New,
	get = Get,
})