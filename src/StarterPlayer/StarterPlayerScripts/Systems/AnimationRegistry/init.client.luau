--[[

 AnimationRegistry
    
    Manages the registration of animations for NPCs in the game.
    
    Features:
    - Register and unregister animations for NPCs.
    - Scan NPC folders and tycoon NPCs to register animations.
    - Retrieve registered animations for specific NPCs.
    
    Usage:
    1. Create an instance of AnimationRegistry using AnimationRegistry.new().
    2. Use the provided methods to manage animations for NPCs.]]


  --]] 



const AnimationManager = require(script.AnimationManager)

local AnimationRegistry = AnimationManager.new()

AnimationRegistry:Start()