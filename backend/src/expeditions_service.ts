import { endSpectatingForStart, spectatorNames } from "./spectator_guard";
import { activePractice } from "./practice_service";
﻿import type { Database } from "bun:sqlite";
import { createHmac, randomBytes } from "node:crypto";
import { gzipSync, gunzipSync } from "node:zlib";
import { buildExpeditionEnemy, createExpeditionCombatState, resolveExpeditionTurn, resolveExpeditionInspiration } from "./expeditions_combat";
import { expeditionDraw, expeditionEnemies, expeditionCaptures, EXPEDITION_EXIT_COOLDOWN_MS, EXPEDITION_CRYSTAL_CAP, EXPEDITION_MANA_CAP, regenerateExpeditionMana, changeExpeditionMana, expeditionCaptureChance } from "./expeditions_rules";
import { expeditionBackgroundAt } from "./expeditions_backgrounds";
import { deterministicDraw } from "./solo_hunt_combat";
import { publicCombatStatus, publicIncomingDrains } from "./public_combat_status";

export class ExpeditionError extends Error { constructor(public status: number, message: string) { super(message); } }
const fail = (status: number, message: string): never => { throw new ExpeditionError(status, message); };
const canonical = (v: any): string => Array.isArray(v) ? `[${v.map(canonical).join(",")}]` : v && typeof v === "object" ? `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${canonical(v[k])}`).join(",")}}` : JSON.stringify(v) ?? "null";
const replayPrefix = "gz1:";
const readReplay = (value: string) => JSON.parse(value.startsWith(replayPrefix) ? gunzipSync(Buffer.from(value.slice(replayPrefix.length), "base64")).toString("utf8") : value);

/** Exact replays are retained for seven days after a run ends. Older actions and runs
 * are removed in small batches; references to removed runs fail closed. */
export const EXPEDITION_REPLAY_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
export const EXPEDITION_HEARTBEAT_INTERVAL_MS = 5000;
export const EXPEDITION_LEASE_EXPIRY_MS = 240000;
export const EXPEDITION_MAX_REVISION = 10000;
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

/** A domain-separated permutation of all expedition homunculi for each cycle. */
export function expeditionHomunculusAt(seed: Uint8Array, runId: string, index: number): string {
  if (!runId || !Number.isSafeInteger(index) || index < 0) throw new Error("INVALID_EXPEDITION_HOMUNCULUS_INDEX");
  const cycle = Math.floor(index / expeditionCaptures.length);
  const shuffle = (n: number) => {
    const bag = expeditionCaptures.map(h => h.id);
    for (let i = bag.length - 1; i > 0; i--) {
      const j = Math.floor(expeditionDraw(seed, JSON.stringify(["homunculus-bag", runId, n]), i) * (i + 1));
      [bag[i], bag[j]] = [bag[j], bag[i]];
    }
    return bag;
  };
  const bag = shuffle(cycle);
  if (cycle && bag[0] === shuffle(cycle - 1).at(-1)) [bag[0], bag[1]] = [bag[1], bag[0]];
  return bag[index % bag.length];
}

// Encounter depth is frozen at selection. Capturable enemies have higher generated
// budgets, so they reach each band modestly earlier, without stat-rounding jumps.
export function expeditionVictoryTier(depth: number, enemy: any, _setup: any): string {
  const capturable = enemy.capturable === true;
  if (depth >= (capturable ? 30 : 35)) return "exceptional";
  if (depth >= (capturable ? 12 : 15)) return "very_difficult";
  if (depth >= (capturable ? 4 : 5)) return "difficult";
  return "normal";
}
export function expeditionVictoryGrants(tier: string, roll: number): Record<string, number> {
  const amounts: Record<string, [number, number]> = {normal:[30,0], difficult:[45,1], very_difficult:[60,1], exceptional:[90,2]};
  if (!amounts[tier] || !(roll >= 0 && roll < 1)) throw new Error("INVALID_EXPEDITION_REWARD");
  const [essence, core] = amounts[tier];
  return {essence, ...(core ? {core} : {}), ...(roll < 0.08 ? {arcane_shard:1} : roll < 0.10 ? {time_crystal:1} : {})};
}

const publicEvent = (event: any) => {
  if (event?.kind === "inspiration_chosen" && event.actor === "npc") { const { spell_id, slot, ...visible } = event; return visible; }
  return event;
};
export function publicExpeditionCombat(combat: any) {
  const { spell_ids, original_spell_ids, cooldowns, inspiration_offers, temporary_spell_id, temporary_replaced_slot, ...npc } = combat.npc;
  return { player: { ...combat.player, ...publicCombatStatus(combat.player, combat.turn), pending_drain: publicIncomingDrains(combat, "player") }, npc: { ...npc, ...publicCombatStatus(npc, combat.turn), pending_drain: publicIncomingDrains(combat, "npc") }, floor: combat.floor, turn: combat.turn, terminal_result: combat.terminal_result, physical_anomaly: combat.physical_anomaly ?? null, strategic_delayed: combat.strategic_delayed ?? [], weapons: (combat.weapons ?? []).map((w: any) => ({id:w.id})), active_weapon_slot: combat.active_weapon_slot ?? 0, item_id: combat.item_id ?? null, item_effects: combat.item_effects ?? {} };
}
function publicSession(row: any, state: any) {
  return { run_id: row.run_id, status: row.status, revision: row.revision, phase: state.phase, depth: state.depth, loadout: JSON.parse(row.loadout_json), background_key: state.background, choices: state.phase === "EXPLORE" ? state.choices.map((e: any, choice: number) => ({ choice, id:e.entity_id, name:e.name, types:e.types, preview_texture:e.preview_texture, capturable:e.capturable })) : [], ...(state.combat && state.phase !== "REWARD" ? {combat_state:publicExpeditionCombat(state.combat), battle_log:state.log.map(publicEvent)} : {}), ...(state.phase === "REWARD" ? {reward_homunculus: (() => { const h = expeditionCaptures.find(h => h.id === state.selected?.homunculus_id); return h ? {id:h.id,name:h.name,type:h.type,preview_texture:h.preview_texture,combat_texture:h.combat_texture} : null; })(), capture_candidate: state.candidate ? { id:state.candidate.id, name:state.candidate.name, type:state.candidate.type, rarity:state.candidate.rarity, preview_texture:state.candidate.preview_texture } : null, capture_attempts:state.capture_attempts ?? 0, capture_attempts_remaining:state.capture_closed === true ? 0 : Math.max(0, 3-(state.capture_attempts ?? 0)), capture_closed:state.capture_closed === true, ...(state.victory_reward ? {victory_reward:state.victory_reward} : {})} : {}), ...(state.latest_reward ? {latest_reward:state.latest_reward} : {}), ...(state.phase === "ROUTE" ? { directions:["left","forward","right"], allowed_directions:(state.consecutive_right ?? 0) >= 3 ? ["left","forward"] : ["left","forward","right"], consecutive_right:state.consecutive_right ?? 0, last_direction:state.last_direction ?? null } : {}) };
}

export type ExpeditionQuestEvent = {kind:"victory";playerId:string;now:number;runId:string;depth:number;difficultyDepth:number;tier:string;enemyId:string} | {kind:"capture";playerId:string;now:number;runId:string;depth:number;homunculusId:string;success:true};
type Options = { db: Database; secret: string; catalogs: any; getPlayer: (playerId: string) => any; makeSetup: (playerId: string, snapshot: any, selection: any) => any; awardVictory: (playerId: string, loadoutJson: string, now: number) => void; grantVictoryLoot: (playerId: string, grants: Record<string, number>, rewardId: string, now: number) => Record<string, number>; spendManaEssence: (playerId: string, actionId: string, now: number) => void; captureHomunculus: (playerId: string, id: string, now: number) => { duplicate: boolean }; questProgress?: (event: ExpeditionQuestEvent) => void };
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
  const leaseHash = (lease: string) => createHmac("sha256", secret).update("expedition-lease:" + lease).digest("hex");
  const validLease = (row: any, lease: unknown, now: number) => typeof lease === "string" && /^[a-f0-9]{64}$/.test(lease) && row.lease_hash === leaseHash(lease) && Number.isSafeInteger(row.heartbeat_at) && now < row.heartbeat_at + EXPEDITION_LEASE_EXPIRY_MS;
  // Call only while holding the write transaction. A second closer cannot settle twice.
  const abandon = (row: any, now: number) => {
    const deadline = Number.isSafeInteger(row.heartbeat_at) ? row.heartbeat_at + EXPEDITION_LEASE_EXPIRY_MS : now;
    const closedAt = Math.min(now, deadline);
    if (db.query("UPDATE expedition_runs SET status='ABANDONED',revision=revision+1,snapshot_json=NULL,loadout_json=NULL,setup_json=NULL,state_json=NULL,lease_hash=NULL,updated_at=?,finished_at=? WHERE run_id=? AND status='ACTIVE'").run(now,closedAt,row.run_id).changes !== 1) return;
    const pool=balance(row.player_id,closedAt);
    if (pool.mana > 0) saveBalance(row.player_id,{...changeExpeditionMana(pool, -Math.min(1, pool.mana),closedAt),crystals:pool.crystals});
    db.query("INSERT INTO expedition_player_cooldowns(player_id,cooldown_until) VALUES(?,?) ON CONFLICT(player_id) DO UPDATE SET cooldown_until=excluded.cooldown_until").run(row.player_id,closedAt+EXPEDITION_EXIT_COOLDOWN_MS);
  };
  const purchaseWindow = (playerId: string, now: number) => {
    const row = db.query("SELECT COUNT(*) AS count, MIN(created_at) AS oldest FROM action_log WHERE player_id=? AND action_type='EXPEDITION_BUY_MANA' AND created_at>?").get(playerId,now-86400000) as any;
    return {remaining:Math.max(0,12-row.count), next:row.count >= 12 ? row.oldest + 86400000 : null};
  };
  const response = (playerId: string, now: number, row?: any, state?: any, events?: any[]) => { const pool=balance(playerId,now), purchases=purchaseWindow(playerId,now); return { ...spectatorNames(playerId), session: row && state ? publicSession(row, state) : null, mana:pool.mana, crystals:pool.crystals, mana_purchases_remaining:purchases.remaining, next_mana_purchase_at:purchases.next, next_regeneration_at:pool.regen_at || null, remaining_cooldown_ms:cooldown(playerId, now), server_time_unix_ms:now, ...(events ? {events:events.map(publicEvent)} : {}) }; };
  const makeNode = (state: any, setup: any, runId: string, seed: Uint8Array) => {
    const background = expeditionBackgroundAt(seed, runId, state.background_cursor++);
    const choices = [0,1].map(() => {
      const cursor = state.enemy_cursor++, id = expeditionEnemyAt(seed, runId, cursor);
      const key = `${runId}:node:${state.depth}:enemy:${cursor}`;
      const capturable = expeditionDraw(seed, JSON.stringify(["capturable", key]), 0) < 0.35;
      return buildExpeditionEnemy(seed, key, state.depth, capturable, setup, catalogs, id, expeditionHomunculusAt(seed, runId, cursor), state.npc_item_level ?? 0, state.difficulty_depth ?? state.depth);
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
  function state(playerId: string, lease?: string | null) {
    return db.transaction(() => { const now=Date.now(), row=db.query("SELECT * FROM expedition_runs WHERE player_id=? AND status='ACTIVE'").get(playerId) as any; if (row && !validLease(row,lease,now)) { abandon(row,now); return response(playerId,now); } return response(playerId,now,row,row ? JSON.parse(row.state_json) : null); }).immediate();
  }
  function heartbeat(playerId: string, lease: string | null, body: any) {
    if (!body || typeof body !== "object" || Array.isArray(body) || Object.keys(body).join(",") !== "run_id" || typeof body.run_id !== "string" || !body.run_id) fail(400,"Invalid expedition heartbeat.");
    const result = db.transaction(() => {
      const now=Date.now(), row=db.query("SELECT * FROM expedition_runs WHERE run_id=? AND player_id=?").get(body.run_id,playerId) as any;
      if (!row || row.status !== "ACTIVE") return false;
      if (!validLease(row,lease,now)) { abandon(row,now); return false; }
      db.query("UPDATE expedition_runs SET heartbeat_at=? WHERE run_id=? AND status='ACTIVE'").run(now,row.run_id);
      return {server_time_unix_ms:now, expires_at:now+EXPEDITION_LEASE_EXPIRY_MS};
    }).immediate();
    if (!result) fail(409,"Expedition lease expired or unavailable.");
    return result;
  }
  function expireLeases(now: number = Date.now()) {
    return db.transaction(() => {
      const rows = db.query("SELECT * FROM expedition_runs WHERE status='ACTIVE' AND (heartbeat_at IS NULL OR heartbeat_at<=?) ORDER BY heartbeat_at LIMIT 50").all(now-EXPEDITION_LEASE_EXPIRY_MS) as any[];
      for (const row of rows) abandon(row,now);
      return rows.length;
    }).immediate();
  }
  function action(playerId: string, action: string, body: any, lease?: string | null) {
    if (!["start","select","turn","inspiration","capture","skip","advance","exit","buy_mana"].includes(action)) fail(404,"Unknown expedition action.");
    validAction(action, body);
    const actionId=body.client_action_id.trim(), actionType=`EXPEDITION_${action.toUpperCase()}`, payload={...body}; delete payload.client_action_id;
    const outcome = db.transaction(() => {
      const now=Date.now();
      const live = action === "start" ? db.query("SELECT * FROM expedition_runs WHERE player_id=? AND status='ACTIVE'").get(playerId) as any : db.query("SELECT * FROM expedition_runs WHERE run_id=? AND player_id=?").get(body.run_id,playerId) as any;
      if (live?.status === "ACTIVE" && !validLease(live,lease,now)) { abandon(live,now); return {leaseRejected:true}; }
      const prior=db.query("SELECT action_type,payload_json,result_state_json FROM action_log WHERE player_id=? AND client_action_id=?").get(playerId,actionId) as any;
      if (prior) {
        if (prior.action_type!==actionType || canonical(JSON.parse(prior.payload_json))!==canonical(payload)) fail(409,"Action ID already used with different content.");
        if (!prior.result_state_json) fail(409,"Expedition action no longer available.");
        const replay=readReplay(prior.result_state_json);
        const replayRun=replay?.session?.run_id ?? body.run_id;
        const replayRow=replayRun ? db.query("SELECT status,lease_hash FROM expedition_runs WHERE run_id=? AND player_id=?").get(replayRun,playerId) as any : null;
        if (replayRow?.status !== "ACTIVE" && !(action === "exit" && replayRow?.status === "EXIT" && typeof lease === "string" && replayRow.lease_hash === leaseHash(lease))) fail(409,"Expedition action no longer available.");
        return action === "start" ? {...replay, lease} : replay;
      }
      if (live?.status === "ACTIVE" && live.revision >= EXPEDITION_MAX_REVISION && action !== "exit") { abandon(live,now); return {limitReached:true}; }
      let row: any, state: any, events: any[] = [];
      if (action === "start") {
        endSpectatingForStart(playerId);
        if (activePractice(db,playerId,now)) fail(409,"Practice is active.");
        if (cooldown(playerId, now)>0) fail(409,"Expedition exit cooldown active.");
        if (db.query("SELECT 1 FROM expedition_runs WHERE player_id=? AND status='ACTIVE'").get(playerId)) fail(409,"An active expedition already exists.");
        if (balance(playerId,now).mana < 1) fail(409,"Not enough expedition mana.");
        const player=options.getPlayer(playerId);
        const snapshot={state_revision:player.state_revision,item_progress:player.item_progress ?? {},homunculus_progress:player.homunculus_progress ?? {},spell_progress:player.spell_progress ?? {},research_flags:player.research_flags ?? {}};
        const selection={entity_id:body.entity_id,weapon_ids:body.weapon_ids,homunculus_id:body.homunculus_id,spell_ids:body.spell_ids,mode:body.mode};
        const setup=options.makeSetup(playerId,snapshot,selection);
        if (setup?.error) fail(400,"Invalid or unsupported expedition loadout.");
        const runId=crypto.randomUUID(), newLease=randomBytes(32).toString("hex"); state={phase:"EXPLORE",depth:1,difficulty_depth:1,enemy_cursor:0,background_cursor:0, npc_item_level: Math.max(0, ...selection.weapon_ids.filter((id: any) => !!id).map((id: string) => Math.min(10, Math.max(0, snapshot.item_progress?.[id]?.level ?? 0))))};
        makeNode(state,setup,runId,seedFor(runId));
        row={run_id:runId,player_id:playerId,status:"ACTIVE",revision:1,loadout_json:JSON.stringify(selection),newLease};
        db.query("INSERT INTO expedition_runs(run_id,player_id,status,revision,snapshot_json,loadout_json,setup_json,state_json,started_at,updated_at,lease_hash,heartbeat_at) VALUES(?,?,'ACTIVE',1,?,?,?,?,?,?,?,?)").run(runId,playerId,JSON.stringify(snapshot),row.loadout_json,JSON.stringify(setup),JSON.stringify(state),now,now,leaseHash(newLease),now);
      } else {
        row=db.query("SELECT * FROM expedition_runs WHERE run_id=? AND player_id=?").get(body.run_id,playerId) as any;
        if (!row) fail(404,"Expedition not found.");
        if (row.status!=="ACTIVE" || row.revision!==body.expected_revision) fail(409,"Expedition unavailable or stale.");
        state=JSON.parse(row.state_json); const seed=seedFor(row.run_id);
        if (action === "buy_mana") {
          const pool=balance(playerId,now);
          if (pool.mana > EXPEDITION_MANA_CAP - 1) fail(400,"Expedition mana is full.");
          if (purchaseWindow(playerId,now).remaining < 1) fail(400,"Expedition mana purchase limit reached.");
          options.spendManaEssence(playerId,actionId,now);
          saveBalance(playerId,{...changeExpeditionMana(pool,1,now),crystals:pool.crystals});
        } else if (action === "select") {
          if (balance(playerId,now).mana < 0.1) fail(400,"Not enough expedition mana.");
          if (state.phase!=="EXPLORE") fail(409,"Enemy selection unavailable.");
          let selected=state.choices[body.choice]; const setup=JSON.parse(row.setup_json);
          // Old active runs may have generated their choices before NPC items existed.
          if (!selected.item_id) {
            const frozen=JSON.parse(row.snapshot_json), loadout=JSON.parse(row.loadout_json);
            state.npc_item_level ??= Math.max(0, ...loadout.weapon_ids.filter((id: any) => !!id).map((id: string) => Math.min(10, Math.max(0, frozen.item_progress?.[id]?.level ?? 0))));
            const cursor=state.enemy_cursor - 2 + body.choice;
            const key=`${row.run_id}:node:${state.depth}:enemy:${cursor}`;
            selected=buildExpeditionEnemy(seed,key,state.depth,selected.capturable,setup,catalogs,selected.entity_id,selected.homunculus_id,state.npc_item_level,state.difficulty_depth ?? state.depth);
          }
          const tacticalTier=expeditionVictoryTier(state.difficulty_depth ?? state.depth,selected,setup);
          selected={...selected, tactical_tier:tacticalTier};
          const combat=createExpeditionCombatState(setup,selected,catalogs);
          if (combat.error) fail(409,"Expedition combat unavailable.");
          state.victory_tier=tacticalTier; state.victory_reward=null;
          state.phase="COMBAT"; state.combat=combat; state.selected=selected; state.choices=[]; state.log=[];
        } else if (action === "turn" || action === "inspiration") {
          if (state.phase!=="COMBAT") fail(409,"Expedition combat unavailable.");
          const draw=(turn: number, count: number) => deterministicDraw(seed,`${row.run_id}:${state.depth}`,turn,count);
          const result=action === "turn" ? resolveExpeditionTurn(state.combat,body.decision,draw) : resolveExpeditionInspiration(state.combat,body.decision,draw);
          if (result.error) fail(400,result.error);
          state.combat=result.next_state; events=result.events; state.log.push(...events);
          if (Bun.env.SPECTATOR_ENABLED === "1" && state.combat.terminal_result) {
            db.query("INSERT OR REPLACE INTO spectator_final_combats(mode,session_id,encounter,combat_json,created_at) VALUES ('expedition',?,?,?,?)").run(row.run_id,String(state.depth),JSON.stringify({combat:state.combat,log:state.log.slice(-512),log_base:Math.max(0,state.log.length-512),depth:state.depth,background:state.background,frozen_spells:JSON.parse(row.loadout_json)?.spell_ids}),now);
            db.query("DELETE FROM spectator_final_combats WHERE rowid IN (SELECT rowid FROM spectator_final_combats WHERE created_at<? ORDER BY created_at LIMIT 50)").run(now-86_400_000);
          }
          if (state.combat.terminal_result === "WIN") {
            const pool=balance(playerId,now);
            if (pool.mana < 0.1) fail(400,"Not enough expedition mana.");
            saveBalance(playerId,{...changeExpeditionMana(pool,-0.1,now),crystals:pool.crystals});
            state.phase="REWARD";
            state.candidate=state.selected.capturable ? expeditionCaptures.find(h => h.id === state.selected.homunculus_id) : null;
            state.capture_attempts=0; state.capture_closed=false;
            options.awardVictory(playerId,row.loadout_json,now);
            // Legacy active combats predate frozen tiers; use the original selected enemy and setup.
            const tier=state.victory_tier ?? expeditionVictoryTier(state.difficulty_depth ?? state.depth,state.selected,JSON.parse(row.setup_json));
            const rewardId=`${row.run_id}:${state.depth}:victory`;
            const roll=expeditionDraw(seed,JSON.stringify(["victory-loot",row.run_id,state.depth]),0);
            const grants=options.grantVictoryLoot(playerId,expeditionVictoryGrants(tier,roll),rewardId,now);
            state.victory_reward={reward_id:rewardId,tier,grants};
            options.questProgress?.({kind:"victory",playerId,now,runId:row.run_id,depth:state.depth,difficultyDepth:state.difficulty_depth ?? state.depth,tier,enemyId:state.selected.entity_id});
          } else if (state.combat.terminal_result === "LOSS") {
            const pool=balance(playerId,now); if (pool.mana > 0) saveBalance(playerId,{...changeExpeditionMana(pool, -Math.min(1, pool.mana),now),crystals:pool.crystals});
            state.phase="LOSS"; row.status="LOSS";
          }
        } else if (action === "capture") {
          const attempts=state.capture_attempts ?? 0;
          if (state.phase !== "REWARD" || !state.selected?.capturable || !state.candidate || state.capture_closed === true || !Number.isInteger(attempts) || attempts < 0 || attempts >= 3) fail(409,"Capture unavailable.");
          const candidate=expeditionCaptures.find(h => h.id === state.candidate.id);
          if (!candidate || candidate.id !== state.selected.homunculus_id || candidate.rarity !== state.candidate.rarity || candidate.preview_texture !== state.candidate.preview_texture) fail(409,"Invalid capture candidate.");
          const pool=balance(playerId,now);
          if (pool.crystals < 1) fail(409,"Not enough capture crystals.");
          const attempt=attempts+1;
          const success=expeditionDraw(seed,JSON.stringify(["capture",row.run_id,state.depth,candidate.id]),attempt-1) < expeditionCaptureChance(candidate.rarity);
          saveBalance(playerId,{...pool,crystals:pool.crystals-1});
          state.capture_attempts=attempt; state.capture_closed=success || attempt >= 3;
          const capture=success ? options.captureHomunculus(playerId,candidate.id,now) : null;
          if (success) options.questProgress?.({kind:"capture",playerId,now,runId:row.run_id,depth:state.depth,homunculusId:candidate.id,success:true});
          const event={reward_id:`${row.run_id}:${state.depth}:capture:${attempt}`,kind:success ? "capture_success" : "capture_failure",candidate_id:candidate.id,attempt,remaining_attempts:success ? 0 : 3-attempt,...(success ? {preview_texture:candidate.preview_texture,duplicate:capture!.duplicate,duplicate_xp:capture!.duplicate ? 20 : 0} : {})};
          state.latest_reward=event; events=[event];
        } else if (action === "skip") {
          if (state.phase!=="REWARD") fail(409,"Reward decision unavailable.");
          state.phase="ROUTE"; state.combat=null; state.log=[]; state.selected=null; state.candidate=null;
        } else if (action === "advance") {
          const difficultyDepth=(state.difficulty_depth ?? state.depth)+(body.direction === "left" ? 1 : body.direction === "forward" ? 2 : 0);
          if (state.phase!=="ROUTE" || !Number.isSafeInteger(state.depth+1) || !Number.isSafeInteger(difficultyDepth) || (body.direction === "right" && (state.consecutive_right ?? 0) >= 3)) fail(409,"Route unavailable.");
          const pool=balance(playerId,now);
          const granted=pool.crystals < EXPEDITION_CRYSTAL_CAP && expeditionDraw(seed,JSON.stringify(["crystal-drop",row.run_id,state.depth]),0) < 0.5;
          if (granted) saveBalance(playerId,{...pool,crystals:pool.crystals+1});
          const reward={reward_id:`${row.run_id}:${state.depth}:crystal`,kind:"crystal_drop",granted,amount:granted ? 1 : 0,...(granted ? {asset_key:"res://assets/entities/expeditions/capture.png"} : {})};
          state.latest_reward=reward; events=[reward];
          state.depth++; state.difficulty_depth=difficultyDepth; state.last_direction=body.direction; state.consecutive_right=body.direction === "right" ? (state.consecutive_right ?? 0) + 1 : 0;
          if (state.npc_item_level === undefined) { const frozen = JSON.parse(row.snapshot_json), loadout = JSON.parse(row.loadout_json); state.npc_item_level = Math.max(0, ...loadout.weapon_ids.filter((id: any) => !!id).map((id: string) => Math.min(10, Math.max(0, frozen.item_progress?.[id]?.level ?? 0)))); }
          makeNode(state,JSON.parse(row.setup_json),row.run_id,seed);
        } else {
          const pool=balance(playerId,now);
          if (pool.mana > 0) saveBalance(playerId,{...changeExpeditionMana(pool, -Math.min(1, pool.mana),now),crystals:pool.crystals});
          db.query("INSERT INTO expedition_player_cooldowns(player_id,cooldown_until) VALUES(?,?) ON CONFLICT(player_id) DO UPDATE SET cooldown_until=excluded.cooldown_until").run(playerId,now+EXPEDITION_EXIT_COOLDOWN_MS);
          row.status="EXIT";
        }
        const oldRevision=row.revision; row.revision++;
        const terminal=row.status!=="ACTIVE";
        const updated=db.query("UPDATE expedition_runs SET status=?,revision=?,snapshot_json=CASE WHEN ? THEN NULL ELSE snapshot_json END,loadout_json=CASE WHEN ? THEN NULL ELSE loadout_json END,setup_json=CASE WHEN ? THEN NULL ELSE setup_json END,state_json=?,updated_at=?,finished_at=? WHERE run_id=? AND player_id=? AND status='ACTIVE' AND revision=?").run(row.status,row.revision,terminal?1:0,terminal?1:0,terminal?1:0,terminal?null:JSON.stringify(state),now,terminal?now:null,row.run_id,playerId,oldRevision);
        if (updated.changes!==1) fail(409,"Expedition changed.");
      }
      db.query("INSERT INTO action_log(player_id,client_action_id,action_type,payload_json,result_state_json,created_at,expedition_run_id) VALUES(?,?,?,?,NULL,?,?)").run(playerId,actionId,actionType,JSON.stringify(payload),now,row.run_id);
      const result=response(playerId,now,row.status === "EXIT" ? null : row,row.status === "EXIT" ? null : state,events);
      db.query("UPDATE action_log SET result_state_json=? WHERE player_id=? AND client_action_id=?").run(JSON.stringify(result),playerId,actionId);
      return action === "start" ? {...result,lease:row.newLease} : result;
    }).immediate();
    if ((outcome as any).leaseRejected) fail(409,"Expedition lease expired or unavailable.");
    if ((outcome as any).limitReached) fail(409,"Expedition action limit reached.");
    return outcome;
  }
  return {state,action,heartbeat,expireLeases};
}
