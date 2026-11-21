import type { Database } from "bun:sqlite";
import { createHmac } from "node:crypto";
import { gzipSync, gunzipSync } from "node:zlib";
import { buildExpeditionEnemy, createExpeditionCombatState, resolveExpeditionTurn, resolveExpeditionInspiration } from "./expeditions_combat";
import { expeditionDraw, expeditionEnemies, expeditionCaptures, EXPEDITION_EXIT_COOLDOWN_MS, EXPEDITION_CRYSTAL_CAP, regenerateExpeditionMana, changeExpeditionMana, expeditionCaptureChance } from "./expeditions_rules";
import { expeditionBackgroundAt } from "./expeditions_backgrounds";
import { deterministicDraw } from "./solo_hunt_combat";

export class ExpeditionError extends Error { constructor(public status: number, message: string) { super(message); } }
const fail = (status: number, message: string): never => { throw new ExpeditionError(status, message); };
const canonical = (v: any): string => Array.isArray(v) ? `[${v.map(canonical).join(",")}]` : v && typeof v === "object" ? `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${canonical(v[k])}`).join(",")}}` : JSON.stringify(v) ?? "null";
const replayPrefix = "gz1:";
const readReplay = (value: string) => JSON.parse(value.startsWith(replayPrefix) ? gunzipSync(Buffer.from(value.slice(replayPrefix.length), "base64")).toString("utf8") : value);

/** Exact replays are retained for seven days after a run ends. Older actions and runs
 * are removed in small batches; references to removed runs fail closed. */
export const EXPEDITION_REPLAY_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
export function maintainExpeditionReplays(db: Database, now: number): number {
  return db.transaction(() => {
    let changed = 0;
    // E5B rows predate expedition_run_id; migrate at most 50 per pass, including gzipped starts.
    const legacy = db.query(`SELECT player_id,client_action_id,payload_json,result_state_json FROM action_log
      WHERE action_type GLOB 'EXPEDITION_*' AND expedition_run_id IS NULL LIMIT 50`).all() as any[];
    const attach = db.prepare("UPDATE action_log SET expedition_run_id=?,expedition_replay_compacted=? WHERE player_id=? AND client_action_id=? AND expedition_run_id IS NULL");
    for (const row of legacy) {
      let runId = "";
      try { runId = JSON.parse(row.payload_json)?.run_id ?? (row.result_state_json ? readReplay(row.result_state_json)?.session?.run_id : "") ?? ""; } catch { /* malformed legacy result becomes an orphan tombstone */ }
      if (typeof runId !== "string") runId = "";
      changed += attach.run(runId, !row.result_state_json || row.result_state_json.startsWith(replayPrefix) ? 1 : 0, row.player_id, row.client_action_id).changes;
    }
    // Do not delete a run while any legacy row is awaiting association.
    if (!db.query("SELECT 1 FROM action_log WHERE action_type GLOB 'EXPEDITION_*' AND expedition_run_id IS NULL LIMIT 1").get()) {
      const finished = db.query("SELECT run_id FROM expedition_runs WHERE status <> 'ACTIVE' AND replay_compacted_at IS NULL AND finished_at <= ? ORDER BY finished_at LIMIT 1").get(now - 2 * 60 * 60 * 1000) as any;
      if (finished) {
        const rows = db.query("SELECT player_id,client_action_id,result_state_json FROM action_log WHERE expedition_run_id=? AND action_type GLOB 'EXPEDITION_*' AND expedition_replay_compacted=0 LIMIT 50").all(finished.run_id) as any[];
        const update = db.prepare("UPDATE action_log SET result_state_json=?,expedition_replay_compacted=1 WHERE player_id=? AND client_action_id=? AND expedition_replay_compacted=0");
        for (const row of rows) {
          const result = row.result_state_json && !row.result_state_json.startsWith(replayPrefix) ? replayPrefix + gzipSync(Buffer.from(row.result_state_json)).toString("base64") : row.result_state_json;
          changed += update.run(result,row.player_id,row.client_action_id).changes;
        }
        if (!db.query("SELECT 1 FROM action_log WHERE expedition_run_id=? AND action_type GLOB 'EXPEDITION_*' AND expedition_replay_compacted=0 LIMIT 1").get(finished.run_id)) changed += db.query("UPDATE expedition_runs SET replay_compacted_at=? WHERE run_id=? AND replay_compacted_at IS NULL").run(now,finished.run_id).changes;
      }
      const expired = db.query("SELECT run_id FROM expedition_runs WHERE status <> 'ACTIVE' AND finished_at <= ? ORDER BY finished_at LIMIT 1").get(now - EXPEDITION_REPLAY_RETENTION_MS) as any;
      if (expired) {
        changed += db.query("DELETE FROM action_log WHERE rowid IN (SELECT rowid FROM action_log WHERE expedition_run_id=? AND action_type GLOB 'EXPEDITION_*' LIMIT 50)").run(expired.run_id).changes;
        if (!db.query("SELECT 1 FROM action_log WHERE expedition_run_id=? AND action_type GLOB 'EXPEDITION_*' LIMIT 1").get(expired.run_id)) changed += db.query("DELETE FROM expedition_runs WHERE run_id=? AND status <> 'ACTIVE' AND finished_at <= ?").run(expired.run_id,now - EXPEDITION_REPLAY_RETENTION_MS).changes;
      }
      changed += db.query("DELETE FROM action_log WHERE rowid IN (SELECT rowid FROM action_log WHERE expedition_run_id='' AND action_type GLOB 'EXPEDITION_*' AND created_at <= ? LIMIT 50)").run(now - EXPEDITION_REPLAY_RETENTION_MS).changes;
    }
    return changed;
  }).immediate();
}

/** Each 21-element cycle is a permutation; swap its first entry if it repeats the previous cycle's last. */
export function expeditionEnemyAt(seed: Uint8Array, runId: string, index: number): string {
  if (!runId || !Number.isSafeInteger(index) || index < 0) throw new Error("INVALID_EXPEDITION_ENEMY_INDEX");
  const cycle = Math.floor(index / expeditionEnemies.length);
  const shuffle = (n: number) => {
    const bag = expeditionEnemies.map(e => e.id);
    for (let i = bag.length - 1; i > 0; i--) { const j = Math.floor(expeditionDraw(seed, JSON.stringify(["enemy-bag", runId, n]), i) * (i + 1)); [bag[i], bag[j]] = [bag[j], bag[i]]; }
    return bag;
  };
  const bag = shuffle(cycle);
  if (cycle && bag[0] === shuffle(cycle - 1).at(-1)) [bag[0], bag[1]] = [bag[1], bag[0]];
  return bag[index % bag.length];
}

const publicEvent = (event: any) => {
  if (event?.kind === "inspiration_chosen" && event.actor === "npc") { const { spell_id, slot, ...visible } = event; return visible; }
  return event;
};
function publicCombat(combat: any) {
  const { spell_ids, original_spell_ids, cooldowns, inspiration_offers, temporary_spell_id, temporary_replaced_slot, ...npc } = combat.npc;
  return { player: combat.player, npc, floor: combat.floor, turn: combat.turn, terminal_result: combat.terminal_result, physical_anomaly: combat.physical_anomaly ?? null, strategic_delayed: combat.strategic_delayed ?? [], weapons: (combat.weapons ?? []).map((w: any) => ({id:w.id})), active_weapon_slot: combat.active_weapon_slot ?? 0, item_id: combat.item_id ?? null, item_effects: combat.item_effects ?? {} };
}
function publicSession(row: any, state: any) {
  return { run_id: row.run_id, status: row.status, revision: row.revision, phase: state.phase, depth: state.depth, loadout: JSON.parse(row.loadout_json), background_key: state.background, choices: state.phase === "EXPLORE" ? state.choices.map((e: any, choice: number) => ({ choice, id:e.entity_id, name:e.name, types:e.types, preview_texture:e.preview_texture, capturable:e.capturable })) : [], ...(state.combat ? {combat_state:publicCombat(state.combat), battle_log:state.log.map(publicEvent)} : {}), ...(state.phase === "REWARD" ? {capture_candidate: state.candidate ? { id:state.candidate.id, name:state.candidate.name, type:state.candidate.type, rarity:state.candidate.rarity, preview_texture:state.candidate.preview_texture } : null, capture_attempts:state.capture_attempts ?? 0, capture_attempts_remaining:state.capture_closed === true ? 0 : Math.max(0, 3-(state.capture_attempts ?? 0)), capture_closed:state.capture_closed === true} : {}), ...(state.latest_reward ? {latest_reward:state.latest_reward} : {}), ...(state.phase === "ROUTE" ? { directions:["left","forward","right"], last_direction:state.last_direction ?? null } : {}) };
}

type Options = { db: Database; secret: string; catalogs: any; getPlayer: (playerId: string) => any; makeSetup: (playerId: string, snapshot: any, selection: any) => any; awardVictory: (playerId: string, loadoutJson: string, now: number) => void; captureHomunculus: (playerId: string, id: string, now: number) => { duplicate: boolean } };
export function createExpeditionService(options: Options) {
  const {db, secret, catalogs} = options;
  const seedFor = (runId: string) => createHmac("sha256", secret).update("expedition:" + runId).digest();
  const cooldown = (playerId: string, now: number) => Math.max(0, ((db.query("SELECT cooldown_until FROM expedition_player_cooldowns WHERE player_id=?").get(playerId) as any)?.cooldown_until ?? 0) - now);
  const balance = (playerId: string, now: number) => {
    db.query("INSERT OR IGNORE INTO expedition_balances(player_id) VALUES(?)").run(playerId);
    const row = db.query("SELECT mana,crystals,regen_at FROM expedition_balances WHERE player_id=?").get(playerId) as any;
    if (!row || !Number.isInteger(row.crystals) || row.crystals < 0 || row.crystals > EXPEDITION_CRYSTAL_CAP) throw new Error("INVALID_EXPEDITION_BALANCE");
    const regenerated = regenerateExpeditionMana(row,now);
    if (row.mana !== regenerated.mana || row.regen_at !== regenerated.regen_at) db.query("UPDATE expedition_balances SET mana=?,regen_at=? WHERE player_id=?").run(regenerated.mana,regenerated.regen_at,playerId);
    return {...regenerated,crystals:row.crystals};
  };
  const saveBalance = (playerId: string, value: any) => {
    if (!Number.isInteger(value.crystals) || value.crystals < 0 || value.crystals > EXPEDITION_CRYSTAL_CAP) throw new Error("INVALID_EXPEDITION_BALANCE");
    if (db.query("UPDATE expedition_balances SET mana=?,regen_at=?,crystals=? WHERE player_id=?").run(value.mana,value.regen_at,value.crystals,playerId).changes !== 1) throw new Error("EXPEDITION_BALANCE_UNAVAILABLE");
  };
  const response = (playerId: string, now: number, row?: any, state?: any, events?: any[]) => { const pool=balance(playerId,now); return { session: row && state ? publicSession(row, state) : null, mana:pool.mana, crystals:pool.crystals, next_regeneration_at:pool.regen_at || null, remaining_cooldown_ms:cooldown(playerId, now), server_time_unix_ms:now, ...(events ? {events:events.map(publicEvent)} : {}) }; };
  const makeNode = (state: any, setup: any, runId: string, seed: Uint8Array) => {
    const background = expeditionBackgroundAt(seed, runId, state.background_cursor++);
    const choices = [0,1].map(() => {
      const cursor = state.enemy_cursor++, id = expeditionEnemyAt(seed, runId, cursor);
      const key = `${runId}:node:${state.depth}:enemy:${cursor}`;
      const capturable = expeditionDraw(seed, JSON.stringify(["capturable", key]), 0) < 0.35;
      return buildExpeditionEnemy(seed, key, state.depth, capturable, setup, catalogs, id);
    });
    if (choices[0].entity_id === choices[1].entity_id || (state.background && state.background === background)) throw new Error("INVALID_EXPEDITION_ROTATION");
    Object.assign(state, {background, choices, phase:"EXPLORE", combat:null, log:[], candidate:null});
  };
  const validAction = (action: string, body: any) => {
    if (!body || typeof body !== "object" || Array.isArray(body)) fail(400,"Invalid expedition action.");
    const start = action === "start";
    const fields = start ? ["entity_id","weapon_ids","homunculus_id","spell_ids","mode"] : ["run_id","expected_revision",...(action === "select" ? ["choice"] : action === "advance" ? ["direction"] : ["turn","inspiration"].includes(action) ? ["decision"] : [])];
    if (Object.keys(body).some(k => !["client_action_id",...fields].includes(k)) || typeof body.client_action_id !== "string" || !body.client_action_id.trim() || body.client_action_id.trim().length > 64) fail(400,"Invalid expedition action.");
    if (start) {
      if (typeof body.entity_id !== "string" || !body.entity_id || !Array.isArray(body.weapon_ids) || body.weapon_ids.length !== 2 || body.weapon_ids.some((id: any) => id !== null && (typeof id !== "string" || !id)) || !(body.homunculus_id === null || typeof body.homunculus_id === "string" && !!body.homunculus_id) || !Array.isArray(body.spell_ids) || body.spell_ids.length !== 4 || body.spell_ids.some((id: any) => typeof id !== "string" || !id) || !["attack","defense"].includes(body.mode)) fail(400,"Invalid expedition loadout.");
    } else if (typeof body.run_id !== "string" || !body.run_id || !Number.isSafeInteger(body.expected_revision) || body.expected_revision < 1 || action === "select" && ![0,1].includes(body.choice) || action === "advance" && !["left","forward","right"].includes(body.direction) || ["turn","inspiration"].includes(action) && (!body.decision || typeof body.decision !== "object" || Array.isArray(body.decision))) fail(400,"Invalid expedition action.");
  };
  function state(playerId: string) {
    return db.transaction(() => { const now=Date.now(), row=db.query("SELECT * FROM expedition_runs WHERE player_id=? AND status='ACTIVE'").get(playerId) as any; return response(playerId,now,row,row ? JSON.parse(row.state_json) : null); }).immediate();
  }
  function action(playerId: string, action: string, body: any) {
    if (!["start","select","turn","inspiration","capture","skip","advance","exit"].includes(action)) fail(404,"Unknown expedition action.");
    validAction(action, body);
    const actionId=body.client_action_id.trim(), actionType=`EXPEDITION_${action.toUpperCase()}`, payload={...body}; delete payload.client_action_id;
    return db.transaction(() => {
      const now=Date.now();
      const prior=db.query("SELECT action_type,payload_json,result_state_json FROM action_log WHERE player_id=? AND client_action_id=?").get(playerId,actionId) as any;
      if (prior) {
        if (prior.action_type!==actionType || canonical(JSON.parse(prior.payload_json))!==canonical(payload)) fail(409,"Action ID already used with different content.");
        if (!prior.result_state_json) fail(409,"Expedition action no longer available.");
        return readReplay(prior.result_state_json);
      }
      let row: any, state: any, events: any[] = [];
      if (action === "start") {
        if (cooldown(playerId, now)>0) fail(409,"Expedition exit cooldown active.");
        if (db.query("SELECT 1 FROM expedition_runs WHERE player_id=? AND status='ACTIVE'").get(playerId)) fail(409,"An active expedition already exists.");
        if (balance(playerId,now).mana < 1) fail(409,"Not enough expedition mana.");
        const player=options.getPlayer(playerId);
        const snapshot={state_revision:player.state_revision,item_progress:player.item_progress ?? {},homunculus_progress:player.homunculus_progress ?? {},spell_progress:player.spell_progress ?? {},research_flags:player.research_flags ?? {}};
        const selection={entity_id:body.entity_id,weapon_ids:body.weapon_ids,homunculus_id:body.homunculus_id,spell_ids:body.spell_ids,mode:body.mode};
        const setup=options.makeSetup(playerId,snapshot,selection);
        if (setup?.error) fail(400,"Invalid or unsupported expedition loadout.");
        const runId=crypto.randomUUID(); state={phase:"EXPLORE",depth:1,enemy_cursor:0,background_cursor:0};
        makeNode(state,setup,runId,seedFor(runId));
        row={run_id:runId,player_id:playerId,status:"ACTIVE",revision:1,loadout_json:JSON.stringify(selection)};
        db.query("INSERT INTO expedition_runs(run_id,player_id,status,revision,snapshot_json,loadout_json,setup_json,state_json,started_at,updated_at) VALUES(?,?,'ACTIVE',1,?,?,?,?,?,?)").run(runId,playerId,JSON.stringify(snapshot),row.loadout_json,JSON.stringify(setup),JSON.stringify(state),now,now);
      } else {
        row=db.query("SELECT * FROM expedition_runs WHERE run_id=? AND player_id=?").get(body.run_id,playerId) as any;
        if (!row) fail(404,"Expedition not found.");
        if (row.status!=="ACTIVE" || row.revision!==body.expected_revision) fail(409,"Expedition unavailable or stale.");
        state=JSON.parse(row.state_json); const seed=seedFor(row.run_id);
        if (action === "select") {
          if (state.phase!=="EXPLORE") fail(409,"Enemy selection unavailable.");
          const selected=state.choices[body.choice]; const setup=JSON.parse(row.setup_json);
          const combat=createExpeditionCombatState(setup,selected,catalogs);
          if (combat.error) fail(409,"Expedition combat unavailable.");
          state.phase="COMBAT"; state.combat=combat; state.selected=selected; state.choices=[]; state.log=[];
        } else if (action === "turn" || action === "inspiration") {
          if (state.phase!=="COMBAT") fail(409,"Expedition combat unavailable.");
          const draw=(turn: number, count: number) => deterministicDraw(seed,`${row.run_id}:${state.depth}`,turn,count);
          const result=action === "turn" ? resolveExpeditionTurn(state.combat,body.decision,draw) : resolveExpeditionInspiration(state.combat,body.decision,draw);
          if (result.error) fail(400,result.error);
          state.combat=result.next_state; events=result.events; state.log.push(...events);
          if (state.combat.terminal_result === "WIN") {
            state.phase="REWARD";
            state.candidate=state.selected.capturable ? expeditionCaptures[Math.floor(expeditionDraw(seed,JSON.stringify(["capture-candidate",row.run_id,state.depth]),0)*expeditionCaptures.length)] : null;
            state.capture_attempts=0; state.capture_closed=false;
            const pool=balance(playerId,now); saveBalance(playerId,{...changeExpeditionMana(pool,1,now),crystals:pool.crystals});
            options.awardVictory(playerId,row.loadout_json,now);
          } else if (state.combat.terminal_result === "LOSS") {
            const pool=balance(playerId,now); saveBalance(playerId,{...changeExpeditionMana(pool,-1,now),crystals:pool.crystals});
            state.phase="LOSS"; row.status="LOSS";
          }
        } else if (action === "capture") {
          const attempts=state.capture_attempts ?? 0;
          if (state.phase !== "REWARD" || !state.selected?.capturable || !state.candidate || state.capture_closed === true || !Number.isInteger(attempts) || attempts < 0 || attempts >= 3) fail(409,"Capture unavailable.");
          const candidate=expeditionCaptures.find(h => h.id === state.candidate.id);
          if (!candidate || candidate.rarity !== state.candidate.rarity || candidate.preview_texture !== state.candidate.preview_texture) fail(409,"Invalid capture candidate.");
          const pool=balance(playerId,now);
          if (pool.crystals < 1) fail(409,"Not enough capture crystals.");
          const attempt=attempts+1;
          const success=expeditionDraw(seed,JSON.stringify(["capture",row.run_id,state.depth,candidate.id]),attempt-1) < expeditionCaptureChance(candidate.rarity);
          saveBalance(playerId,{...pool,crystals:pool.crystals-1});
          state.capture_attempts=attempt; state.capture_closed=success || attempt >= 3;
          const capture=success ? options.captureHomunculus(playerId,candidate.id,now) : null;
          const event={reward_id:`${row.run_id}:${state.depth}:capture:${attempt}`,kind:success ? "capture_success" : "capture_failure",candidate_id:candidate.id,attempt,remaining_attempts:success ? 0 : 3-attempt,...(success ? {preview_texture:candidate.preview_texture,duplicate:capture!.duplicate,duplicate_xp:capture!.duplicate ? 20 : 0} : {})};
          state.latest_reward=event; events=[event];
        } else if (action === "skip") {
          if (state.phase!=="REWARD") fail(409,"Reward decision unavailable.");
          state.phase="ROUTE"; state.combat=null; state.log=[]; state.selected=null; state.candidate=null;
        } else if (action === "advance") {
          if (state.phase!=="ROUTE" || !Number.isSafeInteger(state.depth+1)) fail(409,"Route unavailable.");
          const pool=balance(playerId,now);
          const granted=pool.crystals < EXPEDITION_CRYSTAL_CAP && expeditionDraw(seed,JSON.stringify(["crystal-drop",row.run_id,state.depth]),0) < 0.5;
          if (granted) saveBalance(playerId,{...pool,crystals:pool.crystals+1});
          const reward={reward_id:`${row.run_id}:${state.depth}:crystal`,kind:"crystal_drop",granted,amount:granted ? 1 : 0,...(granted ? {asset_key:"res://assets/entities/expeditions/capture.png"} : {})};
          state.latest_reward=reward; events=[reward];
          state.depth++; state.last_direction=body.direction; makeNode(state,JSON.parse(row.setup_json),row.run_id,seed);
        } else {
          db.query("INSERT INTO expedition_player_cooldowns(player_id,cooldown_until) VALUES(?,?) ON CONFLICT(player_id) DO UPDATE SET cooldown_until=excluded.cooldown_until").run(playerId,now+EXPEDITION_EXIT_COOLDOWN_MS);
          row.status="EXIT";
        }
        const oldRevision=row.revision; row.revision++;
        const terminal=row.status!=="ACTIVE";
        const updated=db.query("UPDATE expedition_runs SET status=?,revision=?,snapshot_json=CASE WHEN ? THEN NULL ELSE snapshot_json END,loadout_json=CASE WHEN ? THEN NULL ELSE loadout_json END,setup_json=CASE WHEN ? THEN NULL ELSE setup_json END,state_json=?,updated_at=?,finished_at=? WHERE run_id=? AND player_id=? AND status='ACTIVE' AND revision=?").run(row.status,row.revision,terminal?1:0,terminal?1:0,terminal?1:0,terminal?null:JSON.stringify(state),now,terminal?now:null,row.run_id,playerId,oldRevision);
        if (updated.changes!==1) fail(409,"Expedition changed.");
      }
      const result=response(playerId,now,row.status === "EXIT" ? null : row,row.status === "EXIT" ? null : state,events);
      db.query("INSERT INTO action_log(player_id,client_action_id,action_type,payload_json,result_state_json,created_at,expedition_run_id) VALUES(?,?,?,?,?,?,?)").run(playerId,actionId,actionType,JSON.stringify(payload),JSON.stringify(result),now,row.run_id);
      return result;
    }).immediate();
  }
  return {state,action};
}
