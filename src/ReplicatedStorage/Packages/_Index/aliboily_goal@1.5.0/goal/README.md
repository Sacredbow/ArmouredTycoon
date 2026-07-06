# Goal

[![CI](https://github.com/aliboIly/goal/actions/workflows/ci.yaml/badge.svg)](https://github.com/aliboIly/goal/actions/workflows/ci.yaml)
[![Release](https://github.com/aliboIly/goal/actions/workflows/release.yaml/badge.svg)](https://github.com/aliboIly/goal/actions/workflows/release.yaml)
[![Wally](https://img.shields.io/badge/wally-aliboily%2Fgoal-red)](https://wally.run/package/aliboily/goal)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A universal Goal-Oriented Action Planning (GOAP) system for Roblox with integrated HTN Planning, Utility AI, Perception, Memory, Personality, and Navigation systems.

## Table of Contents

- [What is GOAP?](#what-is-goap)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Modules](#core-modules)
  - [State](#state)
  - [Action](#action)
  - [Goal](#goal-1)
  - [ActionSequence](#actionsequence)
  - [Planner](#planner)
  - [Logger](#logger)
- [AI Systems](#ai-systems)
  - [Consideration (Utility AI)](#consideration-utility-ai)
  - [Memory](#memory)
  - [Blackboard](#blackboard)
  - [Perception](#perception)
  - [Personality](#personality)
  - [Navigation](#navigation)
- [HTN Planning](#htn-planning)
  - [Tasks](#tasks)
  - [Methods](#methods)
  - [HTN Domain](#htn-domain)
  - [HTN Planner](#htn-planner)
- [Advanced Features](#advanced-features)
  - [Cooldown System](#cooldown-system)
  - [Resource Costs](#resource-costs)
  - [Interrupt Handling](#interrupt-handling)
  - [State Persistence](#state-persistence)
  - [Performance Optimizations](#performance-optimizations)
  - [Debug Logging](#debug-logging)
- [Examples](#examples)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [License](#license)

## What is GOAP?

**Goal-Oriented Action Planning (GOAP)** is an AI architecture that allows NPCs to dynamically determine what actions to take to achieve their goals. Unlike traditional behavior trees or state machines where you explicitly define transitions, GOAP lets the AI figure out the best sequence of actions on its own.

Key concepts:
- **State**: The current state of the world (key-value pairs)
- **Goals**: Desired world states the AI wants to achieve
- **Actions**: Things the AI can do, with preconditions and effects
- **Planning**: Using A* search to find the optimal action sequence

GOAP was originally developed for the game F.E.A.R. and has since become popular for creating believable, emergent AI behavior in games.

## Features

### Core GOAP
- **A* Planning Algorithm** - Finds optimal action sequences
- **Action Sequences/Chains** - Multi-step behaviors like combat combos
- **Cooldown System** - Time-based or turn-based cooldowns
- **Resource Costs** - Actions can consume mana, stamina, items, etc.
- **Interrupt Handling** - Dynamic goal switching for responsive AI
- **State Serialization** - Save/load NPC states (JSON format)
- **Performance Optimizations** - Caching and batch evaluation for 100+ NPCs
- **Profiling Support** - Built-in timing and statistics
- **Debug Logging** - Configurable logging with multiple severity levels

### HTN Planning
- **Hierarchical Task Network** - Structured procedural behaviors
- **Primitive Tasks** - Single actions backed by GOAP Actions
- **Compound Tasks** - Decompose into subtasks via methods
- **Method Selection** - Precondition-based method filtering
- **Backtracking** - Automatic retry with alternate methods on failure
- **GOAP Integration** - Use Actions from your existing GOAP setup

### Utility AI (Consideration)
- **Response Curves** - Linear, quadratic, exponential, logistic, bell curves
- **Curve Parameters** - Slope, exponent, midpoint, steepness customization
- **Combination Modes** - Multiply, min, max, average, sum for multi-factor decisions
- **Factory Methods** - Pre-built patterns for health, distance, resources

### Memory System
- **Working Memory** - Short-term tactical decisions (configurable duration)
- **Episodic Memory** - Event history with importance weighting
- **Semantic Memory** - Long-term facts with confidence levels
- **Pattern Detection** - Learn player behaviors (e.g., "flanks left 70% of time")

### Blackboard System
- **Shared Knowledge** - Squad coordination and communication
- **Claiming System** - Target claiming to prevent NPC clustering
- **Expiration** - Auto-cleanup of stale information
- **Subscriptions** - React to knowledge changes with callbacks

### Perception System
- **Vision** - FOV, range, peripheral vision, obstruction checks
- **Hearing** - Sound detection with volume and type awareness
- **Awareness States** - Unaware → Curious → Suspicious → Alert → Combat
- **Awareness Decay** - Natural decay over time without stimuli

### Personality System
- **Traits** - Aggression, courage, caution, patience, loyalty, etc.
- **Presets** - Berserker, Tactician, Coward, Veteran, Guard, Scout
- **Mood System** - Temporary modifiers (angry, fearful, confident)
- **Decision Modifiers** - Traits affect attack priority, retreat thresholds

### Navigation System
- **A* Pathfinding** - Grid-based tactical pathfinding
- **Cover Evaluation** - Find and score cover positions
- **Flanking Routes** - Calculate approaches from sides/rear
- **High Ground** - Find elevation advantages
- **Flee Paths** - Escape route calculation from multiple threats
- **Threat Avoidance** - Automatic avoidance zones

## Installation

### Using Wally

Add to your `wally.toml`:

```toml
[dependencies]
goal = "aliboily/goal@1.5.0"
```

Then run:

```bash
wally install
```

### Using Rojo

If you're using [Rojo](https://rojo.space/) for development:

#### Option 1: Sync directly to Studio

1. Clone or download this repository
2. Start the Rojo server:
   ```bash
   rojo serve default.project.json
   ```
3. Connect the Rojo plugin in Roblox Studio
4. The package will be available at `ReplicatedStorage.Packages.Goal`

#### Option 2: Build as .rbxm file

Build a model file that you can import into any place:

```bash
rojo build default.project.json -o Goal.rbxm
```

Then drag `Goal.rbxm` into Roblox Studio.

#### Option 3: Include in your own Rojo project

Add Goal as a submodule or copy the `src/` folder, then reference it in your `default.project.json`:

```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Packages": {
        "$className": "Folder",
        "Goal": {
          "$path": "path/to/goal/src"
        }
      }
    }
  }
}
```

### Manual Installation

1. Download the latest release
2. Place the `src` folder contents in `ReplicatedStorage.Packages.Goal`
3. Require it in your scripts:
   ```lua
   local Goal = require(ReplicatedStorage.Packages.Goal)
   ```

### Project Structure

```
src/
├── init.lua          -- Main module entry point
├── State.lua         -- World state management
├── Goal.lua          -- Goal definitions
├── Action.lua        -- Action definitions
├── ActionSequence.lua
├── Planner.lua       -- A* GOAP planner
├── Utilities.lua
├── Logger.lua
├── AI/               -- Utility AI systems
│   ├── init.lua
│   ├── Consideration.lua
│   ├── Memory.lua
│   ├── Blackboard.lua
│   ├── Perception.lua
│   └── Personality.lua
├── Navigation/       -- Pathfinding systems
│   ├── init.lua
│   ├── Navigation.lua
│   ├── NavigationGrid.lua
│   ├── PathfindingAdapter.lua
│   └── SpatialGrid.lua
├── HTN/              -- Hierarchical Task Network
│   ├── init.lua
│   ├── Task.lua
│   ├── Method.lua
│   ├── HTNDomain.lua
│   └── HTNPlanner.lua
└── Actor/            -- Parallel execution (lazy-loaded)
    ├── init.lua
    ├── SharedBlackboard.lua
    ├── ActorPool.lua
    └── NPCScheduler.lua
```

## Quick Start

```lua
local Goal = require(path.to.goal)

-- Create a planner
local planner = Goal.Planner.new()

-- Define actions
local gatherWood = Goal.Action.new({
    name = "GatherWood",
    cost = 2,
    preconditions = {},
    effects = { hasWood = true },
})

local makeFire = Goal.Action.new({
    name = "MakeFire",
    cost = 1,
    preconditions = { hasWood = true },
    effects = { hasFire = true },
})

planner:registerActions({ gatherWood, makeFire })

-- Define a goal
local warmthGoal = Goal.Goal.new({
    name = "GetWarm",
    desiredState = { hasFire = true },
    priority = 1,
})

-- Create world state
local worldState = Goal.State.new({
    hasWood = false,
    hasFire = false,
})

-- Generate a plan
local plan = planner:plan(worldState, warmthGoal)

if plan.success then
    print(Goal.formatPlan(plan))
    -- Output:
    -- Plan SUCCESS (cost: 3.00, iterations: 3)
    -- Actions:
    --   1. GatherWood
    --   2. MakeFire
end
```

## Core Modules

### State

Represents the world state as key-value pairs.

```lua
local state = Goal.State.new({
    health = 100,
    hasWeapon = true,
})

state:get("health") -- 100
state:set("health", 80)
state:has("hasWeapon") -- true
state:satisfies(otherState) -- boolean
state:isDirty() -- true if modified
state:markClean() -- mark as unmodified
```

### Action

Represents an action with preconditions, effects, cooldowns, and resource costs.

```lua
local action = Goal.Action.new({
    name = "Attack",
    cost = 1,
    preconditions = { hasWeapon = true, enemyInRange = true },
    effects = { enemyDead = true },

    -- Cooldown (optional)
    cooldownTime = 3,
    cooldownMode = "seconds", -- or "turns"

    -- Resource costs (optional)
    resourceCosts = {
        { resource = "stamina", amount = 20 },
        { resource = "mana", amount = 10 },
    },

    -- Interrupt handling (optional)
    interruptible = true,
    onInterrupt = function(agent, context)
        print("Attack interrupted!")
    end,

    -- Grouping (optional)
    group = "combat",
    tags = { "offensive", "melee" },

    -- Dynamic cost (optional)
    costFn = function(worldState, agent)
        return worldState:get("enemyHealth") / 10
    end,

    -- Runtime validation (optional)
    validateFn = function(worldState, agent)
        return agent.stamina > 10
    end,

    -- Execution logic (optional)
    executeFn = function(agent, context)
        agent:playAnimation("attack")
        return true
    end,
})
```

### Goal

Represents a goal with desired state, priority, and interrupt handling.

```lua
local goal = Goal.Goal.new({
    name = "DefeatEnemy",
    desiredState = { enemyDead = true },
    priority = 10,

    -- Dynamic priority (optional)
    priorityFn = function(worldState)
        if worldState:get("lowHealth") then
            return 100 -- Max priority when low health
        end
        return 10
    end,

    -- Interrupt handling (optional)
    interruptible = true,
    onInterrupt = function(worldState)
        print("Goal interrupted!")
    end,

    -- Grouping (optional)
    group = "combat",
    tags = { "offensive" },

    -- Priority threshold (optional)
    minPriority = 5, -- Ignore if priority falls below this
})
```

### ActionSequence

Chains multiple actions for complex multi-step behaviors.

```lua
local comboSequence = Goal.ActionSequence.new({
    name = "ComboAttack",
    actions = { lightAttack, lightAttack, heavyAttack, finisher },
    failureStrategy = "abort", -- "skip", "retry", or "abort"
    maxRetries = 3,
    interruptible = true,

    onStepComplete = function(stepIndex, action, success)
        print(string.format("Step %d: %s", stepIndex, success and "OK" or "FAILED"))
    end,

    onSequenceComplete = function(success, completedSteps)
        print(string.format("Combo %s after %d steps", success and "complete" or "failed", completedSteps))
    end,

    onInterrupt = function(stepIndex, action)
        print("Combo interrupted at step " .. stepIndex)
    end,
})

-- Execute the sequence
local success, completedSteps = comboSequence:executeAll(agent, context)

-- Or execute step by step
while comboSequence:isExecuting() do
    local stepSuccess, status = comboSequence:executeStep(agent, context)
end
```

### Planner

The A* planner with performance optimizations.

```lua
local planner = Goal.Planner.new({
    maxIterations = 1000,
    maxPlanLength = 20,
    heuristicWeight = 1.0,

    -- Performance options
    performanceMode = true,
    priorityThreshold = 5, -- Ignore goals below this priority
    maxEvaluationsPerTick = 10, -- Limit evaluations per update
    cacheTTL = 0.5, -- Priority cache time-to-live
    enableProfiling = true,
})

-- Register actions
planner:registerActions({ action1, action2, action3 })

-- Get actions by group or tag
local combatActions = planner:getActionsByGroup("combat")
local offensiveActions = planner:getActionsByTag("offensive")

-- Plan for a single goal
local plan = planner:plan(worldState, goal, agent, context)

-- Plan for the best available goal
local plan, selectedGoal = planner:planBestGoal(worldState, goals, agent, context)

-- Batch evaluate multiple NPCs efficiently
local results = planner:batchEvaluate({
    { agent = npc1, state = state1, goals = goals1 },
    { agent = npc2, state = state2, goals = goals2 },
}, context)

-- Check for interrupts
local interruptGoal = planner:findInterruptingGoal(currentGoal, allGoals, worldState)

-- Get profiling data
local profilingData = planner:getProfilingData()
print(Goal.formatProfiling(profilingData))
```

### Logger

Debug logging system with configurable severity levels.

```lua
local Logger = Goal.Logger

-- Set global log level
Logger.setLevel(Logger.Level.DEBUG)

-- Available levels: NONE, ERROR, WARN, INFO, DEBUG, TRACE
Logger.info("Game", "Starting AI system")
Logger.debug("Planner", "Planning for goal: %s", goal:getName())
Logger.error("Action", "Failed to execute: %s", action:getName())

-- Category-specific levels
Logger.setCategoryLevel("Planner", Logger.Level.TRACE)
Logger.setCategoryLevel("Action", Logger.Level.WARN)

-- Scoped logger (no need to specify category each time)
local log = Logger.scoped("Combat")
log.debug("Attacking enemy: %s", enemy.name)
log.info("Combat complete")

-- Check before expensive operations
if Logger.isEnabled(Logger.Level.TRACE, "Planner") then
    Logger.trace("Planner", "Full state: %s", formatState(state))
end
```

## AI Systems

### Consideration (Utility AI)

Response curves for nuanced decision-making. Transform raw values into utility scores.

```lua
local healthUrgency = Goal.Consideration.new({
    name = "HealthUrgency",
    curve = "inverse_quadratic",  -- Low health = high urgency
    curveParams = { exponent = 2.5 },
    inputFn = function(state, agent)
        return state:get("health") / agent.maxHealth
    end,
})

-- Evaluate the consideration
local urgency = healthUrgency:evaluate(worldState, agent)

-- Combine multiple considerations
local attackUtility = Goal.Consideration.combine(
    { healthConsideration, ammoConsideration, distanceConsideration },
    "multiply",  -- or "min", "max", "average"
    worldState,
    agent
)
```

**Available Curves:** `linear`, `quadratic`, `inverse`, `inverse_quadratic`, `exponential`, `logistic`, `step`, `smoothstep`, `bell`, `custom`

### Memory

Short-term and long-term memory for intelligent agents.

```lua
local memory = Goal.Memory.new({
    workingMemoryDuration = 15,  -- 15 seconds short-term
    maxEpisodicMemories = 200,
})

-- Record events
memory:recordEvent("player_attack", { direction = "left", damage = 25 }, 0.8)

-- Check recent events
if memory:hasRecentEvent("player_attack", 5) then
    -- Player attacked in last 5 seconds
end

-- Store long-term facts
memory:recordFact("player_prefers_flanking", true, 0.7)

-- Get learned patterns
local patterns = memory:getPatterns("attack")
-- Returns: { pattern = "left_flank", confidence = 0.7, occurrences = 5 }
```

### Blackboard

Shared knowledge system for squad coordination.

```lua
local squadBoard = Goal.Blackboard.new({
    name = "Alpha Squad",
    defaultExpiration = 60,
})

-- Post target information
squadBoard:post("primary_target", {
    id = "player_1",
    position = Vector3.new(10, 0, 5),
}, "guard_1", 30)  -- Expires in 30 seconds

-- Claim a target (prevents others from taking it)
if squadBoard:claim("primary_target", "guard_2") then
    -- I'm now responsible for this target
end

-- Subscribe to changes
squadBoard:subscribe("alert_*", function(key, value)
    print("Alert received:", key, value)
end)
```

### Perception

Vision, hearing, and awareness system.

```lua
local perception = Goal.Perception.new({
    vision = { range = 60, angle = 120 },  -- FOV
    hearing = { range = 40, sensitivity = 1.2 },
    awareness = {
        decayRate = 5,  -- Awareness per second
        thresholds = { alert = 60, combat = 80 },
    },
})

-- Check if can see target
local canSee, distance, zone = perception:canSee(
    myPosition, myForward, targetPosition, true
)  -- zone: "center", "peripheral", "hidden"

-- Process visual detection (updates awareness)
local detected, awarenessGain = perception:processVisualDetection(
    "player_1", myPosition, myForward, targetPosition
)

-- Get awareness state
local state = perception:getAwarenessState("player_1")
-- Returns: "unaware", "curious", "suspicious", "alert", or "combat"

-- Update (decays awareness over time)
perception:update(deltaTime)
```

### Personality

Trait-based behavior variation.

```lua
-- Create from preset with variance
local guard = Goal.Personality.fromPreset("guard", 0.1)  -- 10% variance

-- Or define custom traits
local berserker = Goal.Personality.new({
    name = "Berserker",
    traits = {
        aggression = 0.9,
        courage = 0.95,
        caution = 0.1,
        patience = 0.2,
    },
})

-- Get trait values
local aggression = berserker:getTrait("aggression")  -- 0.9

-- Get decision modifiers
local attackMod = berserker:getModifier("attack")  -- Higher due to aggression
local retreatMod = berserker:getModifier("retreat")  -- Lower due to courage

-- Get retreat threshold (health % to flee)
local retreatAt = berserker:getRetreatThreshold()  -- ~0.1 for berserker

-- Set temporary mood
berserker:setMood("angry", 30)  -- 30 seconds of rage
```

**Presets:** `berserker`, `guard`, `coward`, `tactician`, `support`, `balanced`, `scout`, `veteran`

### Navigation

Tactical pathfinding with cover, flanking, and flee routes.

```lua
local navigation = Goal.Navigation.new({
    gridSize = 4,
    maxIterations = 500,
    moveSpeed = 16,
    minCoverHeight = 3,
})

-- Basic pathfinding
local path = navigation:findPath(startPos, goalPos)
if path.pathFound then
    navigation:setPath(path)
    -- Follow path
    local waypoint = navigation:getNextWaypoint()
end

-- Find cover from threats
local cover = navigation:findBestCover(myPos, { threat1Pos, threat2Pos })
if cover then
    print("Cover quality:", cover.quality)  -- 0-1
    print("Cover height:", cover.height)
end

-- Calculate flanking route
local flankPath = navigation:findFlankingRoute(myPos, targetPos, targetFacing)

-- Find high ground
local highGround = navigation:findHighGround(myPos, 40)

-- Calculate flee path
local fleePath = navigation:findFleePath(myPos, threats, 30)  -- 30 studs minimum distance

-- Get safest direction
local escapeDir = navigation:findSafestDirection(myPos, threats)
```

## HTN Planning

Hierarchical Task Network (HTN) planning provides structured, procedural behaviors that complement GOAP's emergent decision-making. HTN excels at multi-step sequences where the order matters, while GOAP handles reactive, goal-driven behavior.

### Tasks

Tasks are either primitive (backed by an Action) or compound (decompose into subtasks).

```lua
-- Primitive task (executes an Action)
local shootTask = Goal.Task.newPrimitive({
    name = "Shoot",
    action = Goal.Action.new({
        name = "Shoot",
        preconditions = { hasAmmo = true, targetVisible = true },
        effects = { targetDamaged = true },
        executeFn = function(agent) return true end
    })
})

-- Compound task (decomposes via methods)
local engageTask = Goal.Task.newCompound({
    name = "EngageEnemy",
    methods = {
        attackMethod,
        reloadFirstMethod,
    }
})
```

### Methods

Methods define how compound tasks decompose into subtasks. The planner selects the first valid method.

```lua
local directAttack = Goal.Method.new({
    name = "DirectAttack",
    preconditions = { hasAmmo = true },
    subtasks = { "Shoot" },  -- Task names
    cost = 1,
})

local reloadFirst = Goal.Method.new({
    name = "ReloadFirst",
    preconditions = { hasAmmo = false },
    subtasks = { "Reload", "Shoot" },
    cost = 2,
})
```

### HTN Domain

A domain is a registry of all tasks available for planning.

```lua
local domain = Goal.HTNDomain.new({ name = "Combat" })

domain:registerTask(shootTask)
domain:registerTask(reloadTask)
domain:registerTask(engageTask)

-- Validate domain (checks for missing task references)
local valid, errors = domain:validate()
if not valid then
    for _, err in errors do
        warn(err)
    end
end
```

### HTN Planner

The HTN planner uses depth-first decomposition with backtracking.

```lua
local htnPlanner = Goal.HTNPlanner.new({
    domain = domain,
    maxDepth = 20,           -- Max decomposition depth
    maxIterations = 1000,    -- Max planning iterations
    enableBacktracking = true,
})

-- Plan from a root task
local state = Goal.State.new({ hasAmmo = false, targetVisible = true })
local plan = htnPlanner:plan("EngageEnemy", state)

if plan.success then
    print("Plan found with", #plan.actions, "actions")
    for i, action in plan.actions do
        print(i, action:getName())  -- 1: Reload, 2: Shoot
    end

    -- Execute the plan
    htnPlanner:executePlan(plan, agent, context)
end
```

### GOAP vs HTN: When to Use Each

| Use Case | Recommended |
|----------|-------------|
| Reactive combat (attack nearest enemy) | GOAP |
| Multi-step rituals (cast spell sequence) | HTN |
| Dynamic goal selection | GOAP |
| Scripted boss phases | HTN |
| Emergent behavior | GOAP |
| Guaranteed action ordering | HTN |

Both systems can be combined - use GOAP for high-level goal selection and HTN for executing complex procedures.

## Advanced Features

### Cooldown System

Actions can have cooldowns (time-based or turn-based):

```lua
local healSpell = Goal.Action.new({
    name = "Heal",
    cooldownTime = 5,
    cooldownMode = "seconds", -- Real-time cooldown
})

local powerAttack = Goal.Action.new({
    name = "PowerAttack",
    cooldownTime = 3,
    cooldownMode = "turns", -- Turn-based cooldown
})

-- Check cooldown
if not action:isOnCooldown(currentTime, currentTurn) then
    action:executeWithResources(agent, context)
end

-- Get remaining cooldown
local remaining = action:getRemainingCooldown(currentTime, currentTurn)
```

### Resource Costs

Actions can require and consume resources:

```lua
local fireball = Goal.Action.new({
    name = "Fireball",
    resourceCosts = {
        { resource = "mana", amount = 40 },
    },
})

-- Agent needs resources table or getResource/consumeResource methods
local agent = {
    resources = { mana = 100, stamina = 50 },
}

-- Check and consume resources
if action:checkResources(agent) then
    action:consumeResources(agent)
    action:execute(agent, context)
end

-- Or use executeWithResources (handles cooldowns too)
action:executeWithResources(agent, context)
```

### Interrupt Handling

Goals and actions can be interrupted by higher-priority events:

```lua
-- Check if current goal should be interrupted
local interruptGoal = planner:findInterruptingGoal(currentGoal, goals, worldState)

if interruptGoal then
    currentGoal:interrupt(worldState)
    interruptGoal:markActive()
    -- Replan with new goal
end

-- Non-interruptible actions (like finishers)
local finisher = Goal.Action.new({
    name = "Finisher",
    interruptible = false, -- Cannot be interrupted
})
```

### State Persistence

Save and load NPC states across sessions:

```lua
-- Save state
local json, err = state:toJSON()
if json then
    dataStore:SetAsync(npcId, json)
end

-- Load state
local json = dataStore:GetAsync(npcId)
local state, err = Goal.State.fromJSON(json)

if state then
    -- State restored successfully
else
    warn("Failed to load state:", err)
end
```

### Performance Optimizations

For managing many NPCs efficiently:

```lua
-- Use performance planner
local planner = Goal.createPerformancePlanner({
    maxEvaluationsPerTick = 20,
    cacheTTL = 0.5,
    enableProfiling = true,
})

-- Batch evaluate (respects evaluation limits, uses dirty flags)
local results = planner:batchEvaluate(agentDataArray, context)

-- Only replan when state changes
if worldState:isDirty() then
    local plan = planner:planBestGoal(worldState, goals, agent)
    worldState:markClean()
end

-- View profiling data
local data = planner:getProfilingData()
print(string.format("Average plan time: %.4fs", data.averagePlanTime))
```

### Debug Logging

Enable logging to trace AI behavior:

```lua
local Logger = Goal.Logger

-- Enable debug output
Logger.setLevel(Logger.Level.DEBUG)

-- Or use custom output function
Logger.setOutputFunction(function(level, category, message)
    -- Send to custom logging system
    MyLogger:Log(level, category, message)
end)

-- Reset to defaults
Logger.reset()
```

## Examples

### NPC Showcase (main_example.server.lua)

**[examples/main_example.server.lua](examples/main_example.server.lua)** - Comprehensive demo of all Goal systems working together:

- **GOAP Planning** - A* action planning with dynamic costs
- **Perception** - Vision, hearing, awareness states (unaware → combat)
- **Memory** - Event recording, pattern learning
- **Personality** - Different archetypes (Veteran, Tactician, Berserker, Guard)
- **Blackboard** - Squad coordination, target claiming
- **Consideration** - Utility curves for smart decisions
- **Navigation** - Cover, flanking, flee paths
- **Parallel Execution** - Efficient batch NPC processing

See [examples/README.md](examples/README.md) for detailed documentation.

## API Reference

See [docs/API.md](docs/API.md) for complete API documentation.

### Module Exports

#### Core Modules

| Property | Type | Description |
|----------|------|-------------|
| `State` | class | World state management |
| `Goal` | class | Goal definitions |
| `Action` | class | Action definitions |
| `ActionSequence` | class | Action chains |
| `Planner` | class | A* planner |
| `Logger` | class | Debug logging |
| `Utilities` | module | Helper functions |

#### AI Modules (`Goal.AI.*`)

| Property | Type | Description |
|----------|------|-------------|
| `Consideration` | class | Utility AI response curves |
| `Memory` | class | Short/long-term memory |
| `Blackboard` | class | Shared knowledge system |
| `Perception` | class | Vision, hearing, awareness |
| `Personality` | class | Trait-based behaviors |

#### Navigation Modules (`Goal.Navigation.*`)

| Property | Type | Description |
|----------|------|-------------|
| `Navigation` | class | Tactical pathfinding |
| `NavigationGrid` | class | Spatial grid representation |
| `PathfindingAdapter` | class | Roblox PathfindingService bridge |
| `SpatialGrid` | class | Spatial hashing for O(1) proximity queries |

#### HTN Modules (`Goal.HTN.*`)

| Property | Type | Description |
|----------|------|-------------|
| `Task` | class | Primitive and compound task definitions |
| `Method` | class | Task decomposition methods |
| `HTNDomain` | class | Task and method registry |
| `HTNPlanner` | class | HTN planning with backtracking |

#### Actor Modules (lazy-loaded)

| Property | Type | Description |
|----------|------|-------------|
| `ActorPool` | class | Actor pool for parallel work |
| `SharedBlackboard` | class | Thread-safe blackboard |
| `NPCScheduler` | class | Batch NPC AI scheduling |

#### Meta

| Property | Type | Description |
|----------|------|-------------|
| `VERSION` | string | Package version (1.5.0) |

### Helper Functions

| Function | Description |
|----------|-------------|
| `createSetup(config)` | Quick setup with planner and state |
| `createActionSequence(name, actions, options)` | Create action chain |
| `createPerformancePlanner(config)` | Optimized planner for many NPCs |
| `formatPlan(plan)` | Format plan for debugging |
| `formatProfiling(data)` | Format profiling data |
| `formatState(state)` | Format state for debugging |
| `formatAction(action)` | Format action for debugging |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Made with care for the Roblox developer community.
