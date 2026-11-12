import { Database } from "bun:sqlite";
import { resolve, basename, relative, isAbsolute } from "node:path";
import { tmpdir } from "node:os";
import { realpathSync } from "node:fs";

const path = resolve(Bun.env.DB_PATH || "");
const rel = relative(realpathSync(tmpdir()), realpathSync(path));
if (Bun.env.FORGE_SMOKE_FIXTURE !== "1" || !rel || rel.startsWith("..") || isAbsolute(rel) || basename(path) !== "test.sqlite") throw new Error(`Refusing non-temporary fixture database: temp=${realpathSync(tmpdir())} db=${realpathSync(path)} relative=${rel}`);
const db = new Database(path);
const row = db.query("SELECT player_id, state_json FROM players WHERE display_name = ?").get("godot_forge_smoke") as { player_id: string; state_json: string } | null;
if (!row) throw new Error("Smoke account missing");
const state = JSON.parse(row.state_json);
state.wallet.essence = 100;
state.lab.buildings.build_forge = { level: 1, route: "" };
state.item_progress = {};
db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), row.player_id);
for (const [name, level] of [["combat_account_a", 10], ["combat_account_b", 0]] as const) {
  const account = db.query("SELECT player_id, state_json FROM players WHERE display_name = ?").get(name) as { player_id: string; state_json: string } | null;
  if (!account) throw new Error(`Combat fixture account missing: ${name}`);
  const combatState = JSON.parse(account.state_json);
  combatState.item_progress = { saltstone_charm: { level } };
  combatState.spell_progress = level === 10
    ? { learned_by_entity: { sulfur_01: ["steady_script"] }, equipped_by_mode: { attack: { sulfur_01: ["steady_script", "cinder_fist", "furnace_rush", "ash_temper"] } } }
    : { learned_by_entity: {}, equipped_by_mode: {} };
  db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(combatState), account.player_id);
}
const lost = db.query("SELECT player_id, state_json FROM players WHERE display_name = ?").get("lost_response_smoke") as { player_id: string; state_json: string } | null;
if (!lost) throw new Error("Lost-response fixture account missing");
const lostState = JSON.parse(lost.state_json);
lostState.wallet.essence = 100;
lostState.lab.buildings.build_forge = { level: 1, route: "" };
lostState.item_progress = {};
db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(lostState), lost.player_id);
const world = db.query("SELECT player_id, state_json FROM players WHERE display_name = ?").get("world_gate_smoke") as { player_id: string; state_json: string } | null;
if (!world) throw new Error("World Gate fixture account missing");
const worldState = JSON.parse(world.state_json);
worldState.wallet.essence = 100;
worldState.lab.buildings.world_gate = { level: 1, route: "" };
db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(worldState), world.player_id);
db.close();
console.log("PASS isolated fixture created");
