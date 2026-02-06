# Entity Wars — Beta Offline Pack (Godot 4.x)

This pack gives you a **fully offline** MVP skeleton:
- **Bo3 combat** with HP (deterministic simulation)
- 6 Entities (Sulfur, Mercury, Sodium, Aether, Vitriol, Gold)
- 8 Build Items (2 equipped + 2 sideboard)
- 8 Homunculi (1 equipped; invoked each round)
- 3 Attack Techniques + 3 Defense Techniques (pre-game selection)
- **Winner-only swap**: after each won round, you may swap **one** equipped item with one from sideboard
- **Surrender** button (counts as a loss; applies costs/point loss)

## How to use
1. Create a Godot 4 project in your repo.
2. Copy the folders from this pack into your project:
   - `data/`, `scripts/`, `scenes/`
3. Open `scenes/Main.tscn` and run it.

## Notes
- Economy/ranked are **offline stubs** intended for the closed beta.
- Timers for upgrades are stubbed (data structures + placeholders). We'll wire real timers/server later.

## File map
- `scripts/data_registry.gd` loads JSON from `data/`
- `scripts/combat_sim.gd` runs Bo3 sim
- `scripts/economy_stub.gd` costs/rewards, "Sacks", Season points, Prestige
- `scripts/main_ui.gd` minimal UI flow
