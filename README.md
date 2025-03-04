# BB_fire_mage


things to do:
- [ ] Improve logic for handling spellfire sphere -> glorious incandescense around combustion timing
- [ ] Improve logic for spending glorious incandescence in relation to fireblast charges
- [ ] Implement flamestrike targeting logic
- [ ] Implement flamestrike as a spender
- [ ] Implement decision making between flamestrike/pyroblast
- [ ] Improve end of combat logic (refreshing spellfire spheres)
- [ ] Improve end of combat logic for spending resources
- [ ] Implement shifting power logic (and option to stop movement)
- [ ] Implement targeting system for fireblast
- [ ] Improve trinket/potion usage with combustion


# Fire Mage Rotation Pattern System Analysis

## Pattern Manager Overview

The pattern manager in this Fire Mage rotation addon is the core orchestration system that manages spell casting sequences. It's designed around a state machine architecture, allowing the addon to execute optimized spell sequences based on current game conditions.

### Core Purpose and Philosophy

The pattern_manager serves as a sophisticated decision engine that:

1. **Maintains a registry of spell patterns** - Each pattern represents an optimized spell sequence for specific situations
2. **Dynamically selects appropriate patterns** - Based on player state, buffs, target conditions, and priorities
3. **Manages pattern execution** - Tracks pattern states and handles transitions between states
4. **Provides clean separation of concerns** - Isolates different spell sequences in their own modules

This approach allows the addon to handle complex Fire Mage mechanics like Hot Streak procs, Combustion windows, and movement-based decisions in a modular, maintainable way.

## Pattern Manager Flow

The pattern_manager follows this execution flow:

1. **Registration** - All patterns are registered during initialization
2. **Selection** - Each update cycle, if no pattern is active, one is selected based on priority
3. **Execution** - The active pattern executes its current state logic
4. **State Transitions** - Patterns transition between internal states based on spell casts and conditions
5. **Completion/Reset** - When patterns complete or are interrupted, they reset and the cycle begins again

## State Transitions Within Patterns

Each pattern implements a state machine. For example, the `PyroFireBlastPattern` moves through these states:

1. **NONE** - Initial state before pattern activation
2. **WAITING_FOR_GCD** - Waiting for global cooldown after Pyroblast cast
3. **FIRE_BLAST_CAST** - Casting Fire Blast during GCD
4. **PYROBLAST_CAST** - Casting Pyroblast with Hot Streak proc

Transitions happen in two primary ways:
- In the `execute` method based on time, resources, or player state
- In the `on_spell_cast` method when specific spells are cast

## Main.lua Integration

The main.lua file orchestrates the entire addon by:

1. Importing all necessary modules including pattern_manager and individual patterns
2. Registering patterns with the pattern_manager
3. Implementing the main update loop that:
   - Checks for spell interruptions and resets patterns if needed
   - Executes active patterns or selects new ones
   - Falls back to basic rotation logic when no pattern applies
4. Handling spell cast events and forwarding them to the pattern_manager

This structure creates a clean separation between decision logic (when to use patterns) and execution logic (how patterns work).

## Implementing a New Pattern

To implement a new pattern and integrate it with main.lua:

1. **Create a pattern module file** in the patterns directory:
   ```lua
   local BasePattern = require("patterns/base_pattern")
   local NewPattern = BasePattern:new("New Pattern Name")
   
   -- Define states
   NewPattern.STATES = {
       NONE = "NONE",
       FIRST_STATE = "FIRST_STATE",
       SECOND_STATE = "SECOND_STATE"
   }
   
   -- Set initial state
   NewPattern.state = NewPattern.STATES.NONE
   ```

2. **Implement core methods**:
   ```lua
   -- Decide if pattern should start
   function NewPattern:should_start(player, context)
       -- Check conditions like spell cooldowns, buffs, etc.
       return conditions_met
   end
   
   -- Initialize pattern
   function NewPattern:start()
       self.active = true
       self.state = self.STATES.FIRST_STATE
       self.start_time = core.time()
       self:log("STARTED - State: " .. self.state, 1)
   end
   
   -- Execute pattern logic
   function NewPattern:execute(player, target)
       if not self.active then return false end
       
       -- Logic based on current state
       if self.state == self.STATES.FIRST_STATE then
           -- First state logic
       elseif self.state == self.STATES.SECOND_STATE then
           -- Second state logic
       end
       
       return true -- Continue pattern execution
   end
   
   -- Handle spell casts
   function NewPattern:on_spell_cast(spell_id)
       -- Update state based on cast spells
   end
   
   -- Reset pattern
   function NewPattern:reset()
       self.active = false
       self.state = self.STATES.NONE
       self.start_time = 0
       self:log("RESET", 1)
   end
   ```

3. **Register in main.lua**:
   ```lua
   local new_pattern = require("patterns/new_pattern")
   pattern_manager:register_pattern("new_pattern", new_pattern)
   ```

4. **Update pattern priority** in pattern_manager.lua:
   ```lua
   function PatternManager:get_pattern_priority(context)
       local is_combustion_active = context.combustion_active or false
   
       if is_combustion_active then
           return {
               "combustion_opener",
               "new_pattern",  -- Add your pattern where appropriate
               "pyro_fb",
               -- other patterns...
           }
       else
           return {
               "combustion_opener",
               "new_pattern",  -- Add your pattern where appropriate
               "scorch_pattern",
               -- other patterns...
           }
       end
   end
   ```

## Conclusion

The pattern_manager provides an elegant solution for handling Fire Mage's complex spell interactions. By breaking down spell sequences into distinct patterns with their own state machines, the addon becomes more modular, testable, and maintainable. This approach allows for easy extension with new patterns as the game evolves, without having to modify core rotation logic.

The system's strength lies in its ability to dynamically select the most appropriate spell sequence for any situation, while maintaining clean separation between decision logic and execution details.