# Entity Wars — Alpha Deployment Phase (Godot 4.6) - V Alpha-0.1

This pack gives you a MVP skeleton:
- **Bo3 combat** with HP (deterministic simulation)
- 6 Entities (Sulfur, Mercury, Sodium, Aether, Vitriol, Gold)
- 8 Build Items (2 equipped + 2 sideboard)
- 8 Homunculi (1 equipped; invoked each round)
- 3 Attack Techniques + 3 Defense Techniques (pre-game selection)
- LabHub implemented for leveling, managing and farming systems and logic
- Many things still in development

## How to use
1. Create a Godot 4 project in your repo.
2. Copy the folders from this pack into your project:
   - `data/`, `scripts/`, `scenes/` and so on
3. Open `scenes/MainMenu.tscn` and run it (f6). Debug mode may be hard-code activated depending on the code phase.

## Notes
- Economy/ranked/resources are being coded with Bun.js backend, using PostgresSQL and Redis.
- Timers for upgrades are stubbed (data structures + placeholders). We'll wire real timers/server later.
