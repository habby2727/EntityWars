import { expect, test } from "bun:test";
import { buildTrustedCombatSetup, deterministicDraw } from "../solo_hunt_combat";
import { homunculusCatalog } from "../homunculus_catalog";
import { buildExpeditionEnemy, createExpeditionCombatState, resolveExpeditionTurn, resolveExpeditionInspiration, expeditionItemEffects } from "../expeditions_combat";
import { createExpeditionService, expeditionVictoryTier } from "../expeditions_service";
import { Database } from "bun:sqlite";
import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createHmac } from "node:crypto";
import { expeditionSpellSupported, chooseDungeonNpcSpell } from "../dungeon_combat";
import { expeditionEnemies, expeditionCaptures, expeditionDualTypeMultiplier } from "../expeditions_rules";
import entities from "../../../data/entities.json";
import items from "../../../data/items.json";
import spells from "../../../data/spells.json";
import types from "../../../data/types.json";
import bosses from "../../../data/static/solo_bosses.json";
import mutations from "../../../data/static/mutations.json";
import balance from "../../../data/static/balance.json";

const catalogs = { entities: entities.entities, items: items.items, spells: spells.spells, types, bosses: bosses.bosses, mutations: mutations.mutations, balance: balance.balance, homunculi: homunculusCatalog().all };
const seed = new Uint8Array(32).fill(37);
const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
const setup = buildTrustedCombatSetup({player_id:"p",state_revision:1,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{},homunculus_progress:{honin:{owned:true,level:0,xp:0}}}, {entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:"honin",spell_ids:ids,mode:"attack"}, catalogs, {independentLoadout:true});
const rng = (turn: number, draw: number) => deterministicDraw(seed, "battle", turn, draw);

test("updated entity base statistics", () => {
  expect(entities.entities.find(e => e.id === "mercury_01")?.base_stats).toEqual({hp:91,power:23,guard:10,tempo:18});
  expect(entities.entities.find(e => e.id === "sodium_01")?.base_stats).toEqual({hp:122,power:16,guard:16,tempo:10});
});

test("routes preserve floor identity and persist independent difficulty, including legacy runs", () => {
  const db = new Database(":memory:");
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(migrations, file), "utf8"));
  const options = {db, secret:"route-test", catalogs, getPlayer:()=>({}), makeSetup:()=>setup, awardVictory:()=>{}, captureHomunculus:()=>({duplicate:false}), grantVictoryLoot:()=>({})};
  let service = createExpeditionService(options);
  const started = service.action("route-player", "start", {entity_id:"sulfur_01", weapon_ids:[null,null], homunculus_id:"honin", spell_ids:ids, mode:"attack", client_action_id:"start"}) as any;
  const run = started.session.run_id, lease = started.lease;
  const read = () => JSON.parse((db.query("SELECT state_json FROM expedition_runs WHERE run_id=?").get(run) as any).state_json);
  const initial = read(); expect([initial.depth, initial.difficulty_depth]).toEqual([1, 1]);
  const route = {...initial, phase:"ROUTE", depth:10, difficulty_depth:4};
  let revision = 1;
  for (const [direction, difficulty] of [["right",4],["left",5],["forward",6]] as const) {
    db.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(route),run);
    const body = {run_id:run,expected_revision:revision,client_action_id:`advance-${direction}`,direction};
    const advanced = service.action("route-player","advance",body,lease) as any;
    const state = read();
    expect([state.depth,state.difficulty_depth,advanced.session.depth]).toEqual([11,difficulty,11]);
    expect(service.action("route-player","advance",body,lease)).toEqual(advanced);
    expect(read()).toEqual(state);
    service = createExpeditionService(options);
    expect(service.state("route-player",lease).session).toEqual(advanced.session);
    for (let i=0; i<2; i++) {
      const choice=state.choices[i], cursor=state.enemy_cursor-2+i;
      const expected=buildExpeditionEnemy(new Uint8Array(createHmac("sha256","route-test").update("expedition:"+run).digest()),`${run}:node:11:enemy:${cursor}`,11,choice.capturable,setup,catalogs,choice.entity_id,choice.homunculus_id,state.npc_item_level,difficulty);
      expect(choice).toEqual(expected);
    }
    revision++;
  }
  const legacy = {...route}; delete (legacy as any).difficulty_depth;
  db.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(legacy),run);
  const advanced = service.action("route-player","advance",{run_id:run,expected_revision:revision,client_action_id:"legacy",direction:"right"},lease) as any;
  expect([read().depth,read().difficulty_depth]).toEqual([11,10]);
  const selected = service.action("route-player","select",{run_id:run,expected_revision:advanced.session.revision,client_action_id:"select",choice:0},lease) as any;
  const frozen=read(); expect(frozen.victory_tier).toBe(expeditionVictoryTier(10,frozen.selected,setup));
  expect(selected.session.depth).toBe(11);
  expect(frozen.selected.tactical_tier).toBe(frozen.victory_tier);
  expect(frozen.combat.tactical_tier).toBe(frozen.victory_tier);
  // Three rights survive service reconstruction; a fourth cannot mutate the run.
  let currentRevision=selected.session.revision;
  for (let i=0;i<3;i++) {
    const persisted=read(); persisted.phase="ROUTE"; persisted.combat=null; persisted.consecutive_right=i;
    db.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(persisted),run);
    const body={run_id:run,expected_revision:currentRevision,client_action_id:`right-${i}`,direction:"right"};
    const result=service.action("route-player","advance",body,lease) as any;
    expect(service.action("route-player","advance",body,lease)).toEqual(result);
    expect(read().consecutive_right).toBe(i+1); currentRevision=result.session.revision;
  }
  const persisted=read(); persisted.phase="ROUTE";
  db.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(persisted),run);
  service=createExpeditionService(options);
  expect(service.state("route-player",lease).session).toMatchObject({directions:["left","forward","right"],allowed_directions:["left","forward"],consecutive_right:3});
  const before=read();
  expect(()=>service.action("route-player","advance",{run_id:run,expected_revision:currentRevision,client_action_id:"fourth",direction:"right"},lease)).toThrow();
  expect(read()).toEqual(before);
  service.action("route-player","advance",{run_id:run,expected_revision:currentRevision,client_action_id:"reset",direction:"left"},lease);
  expect(read().consecutive_right).toBe(0);
  db.close();
});

test("enemy growth uses difficulty without changing floor or deterministic choices", () => {
  const enemy = (depth:number,difficulty:number) => buildExpeditionEnemy(seed,"growth",depth,false,setup,catalogs,undefined,undefined,0,difficulty);
  const first=enemy(11,1), stronger=enemy(11,31), oldCall=buildExpeditionEnemy(seed,"growth",11,false,setup,catalogs);
  expect(oldCall).toEqual(enemy(11,11));
  expect(first.floor).toBe(11); expect(stronger.floor).toBe(11);
  expect([first.entity_id,first.homunculus_id,first.spell_ids,first.item_id]).toEqual([stronger.entity_id,stronger.homunculus_id,stronger.spell_ids,stronger.item_id]);
  expect(stronger.hp).toBeGreaterThan(first.hp); expect(stronger.attack).toBeGreaterThan(first.attack); expect(stronger.defense).toBeGreaterThan(first.defense); expect(stronger.homunculus_level).toBeGreaterThan(first.homunculus_level);
});
test("difficulty adds two defense per step, capped at 26", () => {
  for (const capturable of [false, true]) for (const difficulty of [1,2,3,9,13,14,15,20,100]) {
    const enemy = buildExpeditionEnemy(seed,"defense-bonus",11,capturable,setup,catalogs,undefined,undefined,0,difficulty);
    const baseGuard = setup.entity.base_stats.guard + (setup.bonuses?.def ?? 0);
    const growth = 1 + Math.min(0.55, Math.log2(difficulty) * 0.035);
    const oldDefense = Math.max(1, Math.round(baseGuard * 0.82 * (capturable ? 1.12 : 1) * growth));
    expect(enemy.defense).toBe(oldDefense + Math.min(26, 2 * (difficulty - 1)));
    const state = createExpeditionCombatState(setup,enemy,catalogs);
    const hom = expeditionCaptures.find(h => h.id === enemy.homunculus_id)!;
    expect(state.npc.def).toBe(enemy.defense + (hom.buff_def ?? 0) + Math.floor(enemy.homunculus_level / 3));
  }
});

test("difficulty adds five HP per step, capped at forty", () => {
  for (const capturable of [false, true]) for (const difficulty of [1, 2, 3, 8, 9, 10, 100]) {
    const enemy = buildExpeditionEnemy(seed,"hp-bonus",11,capturable,setup,catalogs,undefined,undefined,0,difficulty);
    const baseHp = setup.entity.base_stats.hp + (setup.bonuses?.hp ?? 0);
    const growth = 1 + Math.min(0.55, Math.log2(difficulty) * 0.035);
    const previousHp = Math.max(1, Math.round(baseHp * (capturable ? 0.85 : 0.75) * growth));
    expect(enemy.hp - previousHp).toBe(Math.min(40, (difficulty - 1) * 5));
    const state = createExpeditionCombatState(setup,enemy,catalogs);
    expect(state.error).toBeUndefined();
    expect(state.npc.hp).toBe(state.npc.max_hp);
    expect(state.npc.hp).toBe(enemy.hp + (expeditionCaptures.find(h => h.id === enemy.homunculus_id)?.buff_hp ?? 0) + enemy.homunculus_level);
  }
});
const build = (key: string, depth = 1, capture = false) => buildExpeditionEnemy(seed, key, depth, capture, setup, catalogs);
const simulate = (state: any, random = rng) => {
  const events: any[] = [];
  for (let i = 0; i < 200 && !state.terminal_result; i++) {
    if (state.player.inspiration_pending) {
      const r = resolveExpeditionInspiration(state, {kind:"choose",spell_id:state.player.inspiration_offers[0]}, random);
      expect(r.error).toBeUndefined(); state = r.next_state; events.push(...r.events);
    }
    const options = state.player.spell_ids.map((id: string) => state.spells.find((s: any) => s.id === id)).filter((s: any) => !(state.player.cooldowns[s.id] > 0));
    const attack = options.filter((s: any) => s.category === "attack").sort((a: any, b: any) => b.power_mult*b.accuracy-a.power_mult*a.accuracy)[0] ?? options[0];
    const result = resolveExpeditionTurn(state, {turn:state.turn+1,spell_id:attack.id,...(state.player.hom_energy >= 3 ? {hom_action:"attack"} : {})}, random);
    expect(result.error).toBeUndefined(); events.push(...result.events); state = result.next_state;
  }
  expect(["WIN", "LOSS"]).toContain(state.terminal_result);
  expect(events.some(e => e.kind === "hom_sacrifice")).toBe(false);
  return {state, events};
};

test("NPC homunculus holds charge, spends tactically, and uses its passive", () => {
  const enemy = build("npc-charge"); enemy.homunculus_id = "solcarp";
  const base = createExpeditionCombatState(setup,enemy,catalogs);
  base.npc.hp=base.npc.max_hp=1000; base.player.hp=base.player.max_hp=1000;
  base.player.tempo=1000; base.npc.hom_energy=2;
  const first=resolveExpeditionTurn(base,{turn:1,spell_id:"cinder_fist"},()=>0.1);
  expect(first.error).toBeUndefined();
  expect(first.next_state.npc.hom_energy).toBe(3);
  expect(first.events.some((e:any)=>e.actor==="npc" && e.kind==="hom_attack")).toBe(false);
  expect(first.events.some((e:any)=>e.actor==="npc" && e.kind==="hom_passive" && e.passive_id==="solcarp")).toBe(true);
  expect(first.next_state.npc.expedition_passive.modifiers).toHaveLength(0);
  const charged=structuredClone(base); charged.npc.hom_energy=5;
  const six=resolveExpeditionTurn(charged,{turn:1,spell_id:"cinder_fist"},()=>0.1);
  expect(six.events.some((e:any)=>e.actor==="npc" && e.kind==="hom_attack")).toBe(true);
  expect(six.next_state.npc.hom_energy).toBe(0);
  const urgent=structuredClone(base); urgent.npc.hom_energy=2; urgent.npc.hp=1; urgent.npc.max_hp=1000; urgent.npc.tempo=1001;
  const early=resolveExpeditionTurn(urgent,{turn:1,spell_id:"cinder_fist"},()=>0.1);
  expect(early.events.some((e:any)=>e.actor==="npc" && e.kind==="hom_attack")).toBe(true);
  expect(early.events.some((e:any)=>String(e.kind).includes("sacrifice"))).toBe(false);
});

test("each expedition species initializes its own NPC passive and HUD identity", () => {
  for (const hom of expeditionCaptures) {
    const enemy=build(`species-${hom.id}`,10); enemy.homunculus_id=hom.id;
    const state=createExpeditionCombatState(setup,enemy,catalogs);
    expect(state.error).toBeUndefined();
    expect(state.npc).toMatchObject({hom_id:hom.id,hom_type:hom.type,hom_texture:hom.combat_texture,hom_energy:0,expedition_passive:{id:hom.id,level:enemy.homunculus_level}});
  }
  const forged=build("invalid-hom"); forged.homunculus_id="cinder";
  expect(createExpeditionCombatState(setup,forged,catalogs).error).toBe("UNTRUSTED_SETUP");
});

test("NPC damage passive applies poison and its next-exchange guard expires", () => {
  const enemy=build("npc-passive"); enemy.homunculus_id="crishvin";
  const state=createExpeditionCombatState(setup,enemy,catalogs);
  state.player.hp=state.player.max_hp=1000; state.npc.hp=state.npc.max_hp=1000;
  state.player.tempo=1000;
  const first=resolveExpeditionTurn(state,{turn:1,spell_id:"cinder_fist"},()=>0.1);
  expect(first.events.some((e:any)=>e.kind==="hom_passive" && e.actor==="npc" && e.trigger==="damage_received")).toBe(true);
  expect(first.events.some((e:any)=>e.kind==="status_applied" && e.actor==="npc" && e.target==="player" && e.status==="poison")).toBe(true);
  expect(first.next_state.npc.expedition_passive.modifiers.some((m:any)=>m.kind==="guard_flat" && m.exchange===2)).toBe(true);
  const next=first.next_state; next.player.inspiration_pending=false;
  // Prevent another activation so the assertion observes expiry of the original modifier.
  next.player.atk=0;
  const second=resolveExpeditionTurn(next,{turn:2,spell_id:"ash_temper"},()=>0.1);
  expect(second.error).toBeUndefined();
  expect(second.next_state.npc.expedition_passive.modifiers.some((m:any)=>m.exchange===2)).toBe(false);
});

test("all expedition enemies produce reproducible legal real combat builds", () => {
  expect(setup.error).toBeUndefined();
  const seen = new Set<string>(), hybrids = new Set<string>(); let hybridCombo = false;
  for (let i=0; i<300 && seen.size<21; i++) {
    const enemy=build(`encounter-${i}`, 15, true); seen.add(enemy.entity_id);
    expect(enemy).toEqual(build(`encounter-${i}`, 15, true));
    expect(expeditionCaptures.some(h => h.id === enemy.homunculus_id)).toBe(true); expect(new Set(enemy.spell_ids).size).toBe(4);
    const chosen = enemy.spell_ids.map((id:string)=>catalogs.spells.find(s=>s.id===id));
    for (const spell of chosen) { expect(expeditionSpellSupported(spell, enemy.types)).toBe(true); if(spell.type === "hybrid") hybrids.add(enemy.entity_id); }
    const has = (s: any, k: string) => s.effects.some((e: any) => e.kind === k);
    if (chosen.some(s => s.type === "hybrid" && has(s, "hybrid_mark")) && chosen.some(s => has(s, "bonus_if_marked"))) hybridCombo = true;
    expect(chosen.some(s=>s.category==="attack" && s.cooldown_turns===0)).toBe(true);
    expect(createExpeditionCombatState(setup, enemy, catalogs).error).toBeUndefined();
  }
  expect(seen.size).toBe(expeditionEnemies.length); expect(hybrids.size).toBeGreaterThan(0); expect(hybridCombo).toBe(true);
});

test("normal and capturable encounters resolve actual turns to terminal states", () => {
  const normal=build("normal"), tough=build("tough",8,true), sameNormal=build("tough",8,false);
  expect(tough.hp).toBeGreaterThan(sameNormal.hp); expect(tough.attack).toBeGreaterThanOrEqual(sameNormal.attack);
  for(const enemy of [normal,tough]) {
    const state=createExpeditionCombatState(setup,enemy,catalogs);
    expect(state.error).toBeUndefined(); expect(state.npc.hom_id).toBe(enemy.homunculus_id); expect(state.npc.hom_energy).toBe(0);
    const outcomes = Array.from({length: 8}, (_, i) => simulate(state, (turn, draw) => deterministicDraw(seed, `battle-${i}`, turn, draw)));
    expect(outcomes.every(result => result.events.some(e=>e.kind==="damage"))).toBe(true);
    const stronger=structuredClone(state); stronger.player.hp=stronger.player.max_hp=500; stronger.player.atk=100;
    expect(simulate(stronger).state.terminal_result).toBe("WIN");
  }
  const injured = createExpeditionCombatState(setup, tough, catalogs); injured.player.hp = 1;
  expect(simulate(injured).state.terminal_result).toBe("LOSS");
});

test("charged homunculus and entity attack together, or hold its charge", () => {
  const state = createExpeditionCombatState(setup,build("hom-choice"),catalogs);
  state.player.hp = state.player.max_hp = 5000;
  state.npc.hp = state.npc.max_hp = 5000;
  state.player.tempo = 1000;
  state.player.hom_energy = 3;
  state.npc.item_effects.evasion_pct = 0;
  const cast = (hom_action: string) => resolveExpeditionTurn(structuredClone(state),{turn:1,spell_id:"cinder_fist",hom_action},()=>0.1);
  const attack = cast("attack");
  expect(attack.error).toBeUndefined();
  expect(attack.events.some((e:any)=>e.kind === "spell" && e.actor === "player" && e.spell_id === "cinder_fist")).toBe(true);
  expect(attack.events.some((e:any)=>e.kind === "damage" && e.actor === "player" && e.amount > 0)).toBe(true);
  expect(attack.events.some((e:any)=>e.kind === "hom_attack" && e.actor === "player" && e.amount > 0)).toBe(true);
  expect(attack.next_state.player.hom_energy).toBe(0);
  const hold = cast("hold");
  expect(hold.error).toBeUndefined();
  expect(hold.events.some((e:any)=>e.kind === "damage" && e.actor === "player" && e.amount > 0)).toBe(true);
  expect(hold.events.some((e:any)=>e.kind === "hom_attack" && e.actor === "player")).toBe(false);
  expect(hold.next_state.player.hom_energy).toBeGreaterThanOrEqual(3);
  state.player.hom_energy = 6;
  expect(cast("hold").next_state.player.hom_energy).toBe(6);
  expect(cast("attack").events.some((e:any)=>e.kind === "hom_attack" && e.actor === "player")).toBe(true);
});

test("dual type defense affects real damage, neutralization and homunculus attacks", () => {
  const byTypes = (wanted: string[]) => {
    for (let i=0;i<300;i++) { const e=build(`dual-${i}`); if (JSON.stringify(e.types)===JSON.stringify(wanted)) return e; }
    throw new Error("missing fixture");
  };
  const a=byTypes(["aether","vitriol"]), b=byTypes(["aether","sulfur"]);
  const stateA=createExpeditionCombatState(setup,a,catalogs), stateB=createExpeditionCombatState(setup,b,catalogs);
  for(const s of [stateA,stateB]) { s.player.atk=80; s.npc.def=10; s.npc.hp=s.npc.max_hp=500; s.player.hom_energy=3; s.player.tempo=100; }
  const turn=(s:any)=>resolveExpeditionTurn(s,{turn:1,spell_id:"cinder_fist",hom_action:"attack"},()=>0.1);
  const ra=turn(stateA), rb=turn(stateB);
  expect(ra.events.find((e:any)=>e.kind==="damage"&&e.actor==="player").amount).toBeGreaterThan(rb.events.find((e:any)=>e.kind==="damage"&&e.actor==="player").amount);
  expect(expeditionDualTypeMultiplier("sulfur",a.types)).toBeGreaterThan(expeditionDualTypeMultiplier("sulfur",b.types));
  expect(ra.events.some((e:any)=>e.kind==="hom_attack"&&e.actor==="player")).toBe(true);
  const neutral=structuredClone(stateB); neutral.player.spell_neutralize_pending=1;
  expect(turn(neutral).events.find((e:any)=>e.kind==="damage"&&e.actor==="player").amount).toBeGreaterThan(rb.events.find((e:any)=>e.kind==="damage"&&e.actor==="player").amount);
});

test("hybrid damage against two types uses both components and neutralization", () => {
  const state = createExpeditionCombatState(setup, build("hybrid-dual"), catalogs);
  state.player.atk = 100; state.player.tempo = 100; state.npc.def = 0; state.npc.hp = state.npc.max_hp = 1000;
  state.npc.expedition_types = ["gold", "sulfur"];
  state.hom_advantage = 0; state.hom_synergy.type_neutralize = 0;
  const spell = state.spells.find((s: any) => s.id === "cinder_fist");
  Object.assign(spell, {type:"hybrid",primary_type:"sulfur",secondary_type:"mercury",power_mult:1,accuracy:1,effects:[]});
  const run = (s: any) => resolveExpeditionTurn(s,{turn:1,spell_id:spell.id},()=>0.5).events.find((e: any) => e.kind === "damage" && e.actor === "player").amount;
  const weak = structuredClone(state); weak.spells.find((s: any) => s.id === spell.id).secondary_type = "aether";
  const mult = (secondary: string) => expeditionDualTypeMultiplier("sulfur", state.npc.expedition_types) ** 0.65 * expeditionDualTypeMultiplier(secondary, state.npc.expedition_types) ** 0.35;
  expect(mult("mercury")).toBeGreaterThan(mult("aether"));
  expect(run(state)).toBe(Math.round(100 * mult("mercury"))); expect(run(weak)).toBe(Math.round(100 * mult("aether")));
  const neutral = structuredClone(state); neutral.player.spell_neutralize_pending = 1;
  expect(run(neutral)).toBe(100);
});

test("Inspiration resolves and tactical AI uses available second-type spells", () => {
  let state=createExpeditionCombatState(setup,build("inspiration",5,true),catalogs);
  state.player.inspiration=3; state.npc.inspiration=3; state.npc.hp=state.npc.max_hp=500; state.player.hp=state.player.max_hp=500;
  const first=resolveExpeditionTurn(state,{turn:1,spell_id:"cinder_fist"},rng); expect(first.error).toBeUndefined(); state=first.next_state;
  expect(state.player.inspiration_pending).toBe(true);
  expect(state.npc.inspiration_used).toBe(true);
  expect(state.npc.spell_ids.some((id: string) => state.spells.some((s: any) => s.id === id && s.category === "attack" && s.cooldown_turns === 0))).toBe(true);
  const inspiration=resolveExpeditionInspiration(state,{kind:"choose",spell_id:state.player.inspiration_offers[0]},rng);
  expect(inspiration.error).toBeUndefined(); expect(inspiration.next_state.turn).toBe(1);
  expect(simulate(inspiration.next_state).state.terminal_result).toBeTruthy();
  const moves=catalogs.spells.filter(s=>["rift_touch","silver_needle","veil_rupture","false_signal"].includes(s.id));
  const choice=chooseDungeonNpcSpell(8,moves.map(s=>s.id),moves,{rift_touch:1,veil_rupture:1,false_signal:1},{type:"aether",expedition_types:["aether","mercury"],hp:100,max_hp:100,atk:20,status:{}},{type:"gold",hp:100,max_hp:100,def:5,status:{}},0.5,{types,personality:"AGGRESSIVE"});
  expect(choice).toBe("silver_needle");
});


test("catalog items have trusted, exact level effects and encounter budgets include flats once", () => {
  for (const item of items.items) for (const level of [0, 1, 5, 10]) {
    const actual = expeditionItemEffects(item, level);
    for (const [key, values] of Object.entries(item.effects) as [string, number[]][]) {
      const expected = level === 0 && values.length === 10 && Object.hasOwn(item.base_effects ?? {}, key) ? (item.base_effects as any)[key] : values[Math.min(Math.max(0, level - 1), values.length - 1)];
      expect(actual[key]).toBe(expected);
    }
  }
  expect(() => expeditionItemEffects({...items.items[0],effects:{power_flat:[NaN]}}, 1)).toThrow();
  for (const level of [0,1,5,10]) {
    const encounter=buildExpeditionEnemy(seed,"level-"+level,1,false,setup,catalogs,undefined,undefined,level);
    expect(encounter.item_level).toBe(level);
    expect(createExpeditionCombatState(setup,encounter,catalogs).npc.weapons).toEqual([{id:encounter.item_id,level}]);
  }
  const enemy = buildExpeditionEnemy(seed,"item-level",1,false,setup,catalogs,undefined,undefined,10);
  expect(enemy.item_level).toBe(10);
  const state = createExpeditionCombatState(setup,enemy,catalogs);
  expect(state.npc.weapons).toEqual([{id:enemy.item_id,level:10}]);
  const hom = expeditionCaptures.find(h => h.id === enemy.homunculus_id)! as any;
  expect(state.npc.atk).toBe(enemy.attack + (hom.buff_atk ?? 0) + Math.floor(enemy.homunculus_level / 5));
  expect(state.npc.def).toBe(enemy.defense + (hom.buff_def ?? 0) + Math.floor(enemy.homunculus_level / 3));
  expect(createExpeditionCombatState(setup,{...enemy,item_effects:{power_flat:999}},catalogs).error).toBe("UNTRUSTED_SETUP");
  const budgetAttack=enemy.attack, budgetGuard=enemy.defense;
  for (const item of items.items) {
    const fx=expeditionItemEffects(item,10), power=Math.trunc(fx.power_flat ?? 0), guard=Math.trunc(fx.guard_flat ?? 0);
    const candidate={...enemy,item_id:item.id,item_level:10,item_effects:fx,item_power_allocated:power,item_guard_allocated:guard,attack:budgetAttack,defense:budgetGuard};
    const equipped=createExpeditionCombatState(setup,candidate,catalogs);
    expect(equipped.error).toBeUndefined();
    expect(equipped.npc.weapons).toEqual([{id:item.id,level:10}]);
    expect(equipped.npc.atk).toBe(state.npc.atk);
    expect(equipped.npc.def).toBe(state.npc.def);
  }
});

test("tactical equipment is deterministic and responds to opposing loadout", () => {
  const defensive = {...setup, weapons:[{id:"mirror_sigel",effects:{reflect_pct:0.8,ward_pct:0.3,guard_flat:9}},{id:null,effects:{}}], spells:setup.spells.map((spell:any)=>({...spell,effects:[...spell.effects,{kind:"reflect",value:0.8,target:"self"}]}))};
  const fast = {...setup, entity:{...setup.entity,base_stats:{...setup.entity.base_stats,tempo:100}}, weapons:[{id:"wind_amulet",effects:{tempo_flat:8,evasion_pct:0.08}},{id:null,effects:{}}]};
  const seen = new Set<string>(), profiles: string[][] = [];
  for (const profile of [setup, defensive, fast]) {
    const picks: string[] = [];
    for (let i=0;i<80;i++) {
      const key=`profile-${i}`, enemy=buildExpeditionEnemy(seed,key,2,false,profile,catalogs,undefined,undefined,5);
      expect(buildExpeditionEnemy(seed,key,2,false,profile,catalogs,undefined,undefined,5).item_id).toBe(enemy.item_id);
      expect(items.items.some(item=>item.id===enemy.item_id)).toBe(true);
      picks.push(enemy.item_id); seen.add(enemy.item_id);
    }
    profiles.push(picks);
  }
  expect(seen.size).toBeGreaterThan(4);
  expect(profiles[0].filter((v,i)=>v!==profiles[1][i]).length).toBeGreaterThan(20);
  expect(profiles[0].filter((v,i)=>v!==profiles[2][i]).length).toBeGreaterThan(20);
});

test("NPC equipment triggers offense, defense, evasion, tempo and reflection without borrowing the player weapon", () => {
  const base = createExpeditionCombatState(setup,build("item-effects"),catalogs);
  const fight = (npcEffects:any, playerEffects:any = {}, configure:(state:any)=>void = ()=>{}) => {
    const state=structuredClone(base);
    state.player.hp=state.player.max_hp=5000; state.npc.hp=state.npc.max_hp=5000;
    state.player.tempo=100; state.npc.tempo=10;
    state.player.expedition_passive=null; state.npc.expedition_passive=null;
    state.npc.item_id="vitriol_vial"; state.npc.item_effects=npcEffects;
    state.item_effects=playerEffects;
    state.npc.spell_ids=["cinder_fist","furnace_rush","ash_temper","brimstone_crash"];
    state.npc.cooldowns={furnace_rush:9,ash_temper:9,brimstone_crash:9};
    configure(state);
    return resolveExpeditionTurn(state,{turn:state.turn+1,spell_id:"cinder_fist"},()=>0.01);
  };
  const offense=fight({true_on_hit:3,dot_true:2,vuln_on_hit:0.2});
  expect(offense.events.some((e:any)=>e.actor==="npc" && e.kind==="true_on_hit" && e.amount===3)).toBe(true);
  expect(offense.events.some((e:any)=>e.actor==="npc" && e.kind==="dot_true" && e.amount===2)).toBe(true);
  expect(offense.events.some((e:any)=>e.actor==="npc" && e.status==="vuln" && e.source==="weapon")).toBe(true);
  expect(offense.events.some((e:any)=>e.actor==="player" && ["true_on_hit","dot_true"].includes(e.kind))).toBe(false);
  const evaded=fight({evasion_pct:1});
  expect(evaded.events.some((e:any)=>e.kind==="evade" && e.actor==="npc")).toBe(true);
  const defensive=fight({ward_pct:0.1,reflect_pct:0.2});
  expect(defensive.next_state.npc.status.shield).toBe(0.1);
  expect(defensive.next_state.npc.status.reflect).toBe(0.2);
  const second=defensive.next_state; second.player.cooldowns={}; second.npc.cooldowns={};
  const used=resolveExpeditionTurn(second,{turn:2,spell_id:"cinder_fist"},()=>0.01);
  expect(used.events.some((e:any)=>e.kind==="reflect" && e.actor==="npc")).toBe(true);
  expect(used.next_state.npc.status.shield ?? 0).toBe(0);
  expect(used.next_state.npc.status.reflect ?? 0).toBe(0);
  const ignore=fight({ignore_reflect_chance:1},{},s=>{s.player.status.reflect=0.5});
  expect(ignore.events.some((e:any)=>e.kind==="reflect" && e.actor==="player" && e.ignored)).toBe(true);
  const tempo=fight({tempo_flat:200});
  expect(tempo.events.find((e:any)=>e.kind==="spell").actor).toBe("npc");
  const winner=fight({tempo_on_win:4},{},s=>{s.npc.hp=5000; s.player.hp=4900;});
  expect(winner.next_state.npc.status.tempo_bonus).toBe(4);
  const normalGuard=fight({}, {}, s=>{s.npc.def=5;});
  const higherGuard=fight({}, {}, s=>{s.npc.def=15;});
  expect(higherGuard.events.find((e:any)=>e.kind==="damage" && e.actor==="player").amount).toBeLessThan(normalGuard.events.find((e:any)=>e.kind==="damage" && e.actor==="player").amount);
  const mismatch=(s:any)=>{s.player.type="aether"; s.npc.type="sulfur"; s.npc.expedition_types=["sulfur","mercury"];};
  const weak=fight({}, {}, mismatch), reduced=fight({disadvantage_reduction:0.15}, {}, mismatch);
  expect(reduced.events.find((e:any)=>e.kind==="damage" && e.actor==="npc").amount).toBeGreaterThan(weak.events.find((e:any)=>e.kind==="damage" && e.actor==="npc").amount);
  const hom=structuredClone(base);
  hom.player.hp=hom.player.max_hp=5000; hom.npc.hp=hom.npc.max_hp=5000;
  hom.player.tempo=100; hom.player.hom_energy=3; hom.npc.item_effects={evasion_pct:1};
  hom.player.expedition_passive=null; hom.npc.expedition_passive=null;
  const homEvade=resolveExpeditionTurn(hom,{turn:1,spell_id:"cinder_fist",hom_action:"attack"},()=>0.01);
  expect(homEvade.events.filter((e:any)=>e.kind==="evade" && e.actor==="npc").length).toBe(2);
});


test("real encounters progress through victory tiers for both capture variants", () => {
  const depths = [1,5,10,15,25,35,50];
  const tiers = ["normal","difficult","difficult","very_difficult","very_difficult","exceptional","exceptional"];
  for (const capture of [false,true]) for (const [i,depth] of depths.entries()) {
    const enemy=build(`tier-${depth}-${capture}`,depth,capture);
    const state=createExpeditionCombatState(setup,enemy,catalogs);
    expect(state.error).toBeUndefined();
    expect(enemy.capturable).toBe(capture);
    const turn=resolveExpeditionTurn(state,{turn:1,spell_id:"cinder_fist"},rng);
    expect(turn.error).toBeUndefined();
    expect(turn.next_state.turn).toBe(1);
    expect(["WIN", "LOSS"]).toContain(simulate(state).state.terminal_result);
    expect(expeditionVictoryTier(depth,enemy,setup)).toBe(tiers[i]);
  }
  for (const [depth, normal, capture] of [[4,"normal","difficult"],[12,"difficult","very_difficult"],[30,"very_difficult","exceptional"]] as const) {
    expect(expeditionVictoryTier(depth,build(`normal-${depth}`,depth,false),setup)).toBe(normal);
    expect(expeditionVictoryTier(depth,build(`capture-${depth}`,depth,true),setup)).toBe(capture);
  }
});


test("frozen tactical tiers make seeded choices from the same legal loadout", () => {
  const moves=[
    {id:"weak",type:"sulfur",category:"attack",power_mult:0.3,accuracy:1,cooldown_turns:0,effects:[]},
    {id:"lethal",type:"sulfur",category:"attack",power_mult:1,accuracy:1,cooldown_turns:0,effects:[]},
    {id:"heal",type:"sulfur",category:"support",power_mult:0,accuracy:1,cooldown_turns:1,effects:[{kind:"heal",target:"self",value:30}]},
    {id:"clean",type:"sulfur",category:"support",power_mult:0,accuracy:1,cooldown_turns:1,effects:[{kind:"cleanse_one",target:"self",value:1}]},
  ];
  const npc={type:"sulfur",expedition_types:["sulfur","gold"],hp:30,max_hp:100,atk:30,status:{poison:2}};
  const target={type:"gold",hp:10,max_hp:100,def:0,status:{}};
  const choose=(floor:number,tactical_tier:string, opponent=target)=>chooseDungeonNpcSpell(floor,moves.map(s=>s.id),moves,{},npc,opponent,0,{tactical_tier,types});
  expect(choose(1,"normal")).toBe("weak");
  expect(choose(5,"difficult")).toBe("lethal");
  expect(choose(8,"very_difficult",{...target,hp:100})).toBe("clean");
  expect(choose(8,"very_difficult",{...target,hp:100})).toBe(choose(8,"very_difficult",{...target,hp:100}));
});
