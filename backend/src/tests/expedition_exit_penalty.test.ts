import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createHmac } from "node:crypto";
import { createExpeditionService } from "../expeditions_service";

test("exit settles mana and cooldown once, including at zero mana", () => {
  const db = new Database(":memory:");
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(migrations, file), "utf8"));
  const service = createExpeditionService({db, secret:"test", catalogs:{}, getPlayer:() => ({}), makeSetup:() => ({}), awardVictory:() => {}, captureHomunculus:() => ({duplicate:false})});
  for (const mana of [0, 0.1, 0.5, 0.9, 1, 6]) {
    const player = `player-${mana}`, run = `run-${mana}`, now = Date.now();
    db.query("INSERT INTO expedition_balances(player_id,mana,crystals,regen_at) VALUES(?,?,0,?)").run(player,mana,mana === 6 ? 0 : now + 1800000);
    const lease="a".repeat(64), hash=createHmac("sha256","test").update("expedition-lease:"+lease).digest("hex");
    db.query("INSERT INTO expedition_runs(run_id,player_id,status,revision,loadout_json,state_json,started_at,updated_at,lease_hash,heartbeat_at) VALUES(?,?,'ACTIVE',1,'{}','{}',?,?,?,?)").run(run,player,now,now,hash,now);
    const body = {run_id:run, expected_revision:1, client_action_id:`exit-${mana}`};
    const result = service.action(player,"exit",body,lease);
    expect(result.mana).toBe(Math.max(0, mana - 1));
    expect(result.remaining_cooldown_ms).toBe(60000);
    expect(service.action(player,"exit",body,lease)).toEqual(result);
    expect((db.query("SELECT mana FROM expedition_balances WHERE player_id=?").get(player) as any).mana).toBe(Math.max(0, mana - 1));
    expect(() => service.action(player,"exit",{...body,client_action_id:`again-${mana}`},lease)).toThrow();
  }
  db.close();
});
