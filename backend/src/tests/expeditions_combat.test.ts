import { expect, test } from "bun:test";
import { buildTrustedCombatSetup, deterministicDraw } from "../solo_hunt_combat";
import { homunculusCatalog } from "../homunculus_catalog";
import { buildExpeditionEnemy, createExpeditionCombatState, resolveExpeditionTurn, resolveExpeditionInspiration } from "../expeditions_combat";
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
