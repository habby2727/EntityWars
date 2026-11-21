import { expect, test } from "bun:test";
import catalog from "../../../data/static/expedition_homunculi.json";
import originals from "../../../data/homunculi.json";
import { evaluateExpeditionPassive as evaluate, validatePassiveCatalog, type PassiveContext, type PassiveEvent } from "../expedition_passives";
const base = (): PassiveContext => ({exchange: 3, fighter: {hp: 40, max_hp: 100, shielded: true, consecutive_spell_hits: 2, attacks_made: 0}, target: {debuffed: true}, type_relation: "advantage", poison_damage: 5, applied_markers: []});
const ids = catalog.homunculi.map(e => e.id);
const eventOf = (id: string) => catalog.homunculi.find(e => e.id === id)!.passive.event as PassiveEvent;
const forId = (id: string): PassiveContext => { const ctx = base(); if (id === "honin") ctx.type_relation = "disadvantage"; return ctx; };
test("all fourteen identities activate, scale, cap, replay and cannot stack", () => {
  expect(validatePassiveCatalog(catalog).size).toBe(14); expect(new Set(ids).size).toBe(14); expect(originals.homunculi.some(e => ids.includes(e.id))).toBe(false);
  for (const id of ids) {
    const context = forId(id), event = eventOf(id), results = [0,3,6,10].map(level => evaluate(id, level, context, event)!);
    expect(results.every(Boolean)).toBe(true);
    for (let level = 0; level <= 10; level++) expect(evaluate(id, level, context, event)).not.toBeNull();
    expect(evaluate(id, 10, context, "weapon_switched" === event ? "dodge" : "weapon_switched")).toBeNull();
    for (let i = 0; i < results[0].effects.length; i++) {
      const values = results.map(r => r.effects[i].amount), kind = results[0].effects[i].kind;
      expect(values[0]).toBeGreaterThan(0); expect(values).toEqual([...values].sort((a,b) => a-b)); expect(values[3]).toBeGreaterThan(values[0]);
      expect(values[3]).toBeLessThanOrEqual(({power_flat:3, guard_flat:3, tempo_flat:2, accuracy_pct:.05, evasion_pct:.05, poison:2, heal:3})[kind]);
    }
    expect(evaluate(id, 10, context, event)).toEqual(evaluate(id, 10, structuredClone(context), event));
    expect(evaluate(id, 10, {...context, applied_markers:[results[0].marker]}, event)).toBeNull(); expect(results[0].stacking).toBe("replace");
  }
});
test("conditions and healing boundaries reject counterexamples", () => {
  const cases: [string, (c: PassiveContext) => void][] = [["astralotl", c => c.type_relation = "neutral"], ["cedix", c => c.fighter.hp = 50], ["honin", c => c.type_relation = "neutral"], ["luny", c => c.fighter.consecutive_spell_hits = 1], ["mantillo", c => c.target.debuffed = false], ["ninux", c => c.fighter.shielded = false], ["solcarp", c => c.fighter.attacks_made = 1], ["venam", c => c.poison_damage = 0], ["voltibis", c => c.exchange = 4]];
  for (const [id, alter] of cases) { const context = forId(id); alter(context); expect(evaluate(id, 10, context, eventOf(id))).toBeNull(); }
  const heal = base(); heal.fighter.hp = 99; heal.poison_damage = 10; expect(evaluate("venam", 10, heal, "opponent_poison_damage")!.effects[0].amount).toBe(1);
  heal.fighter.hp = 80; heal.poison_damage = 2; expect(evaluate("venam", 10, heal, "opponent_poison_damage")!.effects[0].amount).toBe(2);
  heal.fighter.hp = 100; expect(evaluate("venam", 10, heal, "opponent_poison_damage")).toBeNull(); heal.fighter.hp = 0; expect(evaluate("venam", 10, heal, "opponent_poison_damage")).toBeNull();
});
test("invalid inputs, duplicate IDs and unsupported effects fail closed", () => {
  const c = base();
  for (const level of [-1,11,NaN,Infinity,2.5]) expect(() => evaluate("astralotl", level, c, "before_attack")).toThrow();
  expect(() => evaluate("__proto__", 0, c, "before_attack")).toThrow(); expect(() => evaluate("astralotl", 0, {...c, fighter:{...c.fighter,hp:Infinity}}, "before_attack")).toThrow();
  expect(() => evaluate("astralotl", 0, {...c, exchange:0}, "before_attack")).toThrow(); expect(() => evaluate("astralotl", 0, c, "bogus" as PassiveEvent)).toThrow();
  const dup = structuredClone(catalog); dup.homunculi[1].id = dup.homunculi[0].id; expect(() => validatePassiveCatalog(dup)).toThrow();
  const invalid = structuredClone(catalog); invalid.homunculi[0].passive.effects[0].values[3] = 4; expect(() => validatePassiveCatalog(invalid)).toThrow();
  const wrong = structuredClone(catalog); wrong.homunculi[0].passive.effects[0].kind = "guard_flat"; expect(() => validatePassiveCatalog(wrong)).toThrow();
  const unknown = structuredClone(catalog); unknown.homunculi[0].passive.effects[0].kind = "new_status"; expect(() => validatePassiveCatalog(unknown)).toThrow();
});


test("expedition IDs remain rejected by existing trusted combat catalogs", async () => {
  const { readFileSync } = await import("node:fs");
  const { resolve } = await import("node:path");
  const { buildTrustedCombatSetup } = await import("../solo_hunt_combat");
  const { createPvpCombatState } = await import("../pvp/combat");
  const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", name), "utf8"));
  const catalogs = {entities:read("entities.json").entities, items:read("items.json").items, homunculi:read("homunculi.json").homunculi, spells:read("spells.json").spells, bosses:read("static/solo_bosses.json").bosses, mutations:read("static/mutations.json").mutations, balance:read("static/balance.json").balance, types:read("types.json")};
  const spells = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const hunt = {player_id:"a", state_revision:1, boss_id:"hunt_common", boss_entity_id:"sodium_01", spell_progress:{}};
  const selection = {entity_id:"sulfur_01", weapon_ids:[null,null], spell_ids:spells, mode:"attack"};
  const other = {player_id:"b", entity_id:"sulfur_01", weapon_ids:[null,null], homunculus_id:null, spell_ids:spells};
  for (const id of ids) {
    expect(buildTrustedCombatSetup(hunt, {...selection, homunculus_id:id}, catalogs, {independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"});
    expect(createPvpCombatState({...other, player_id:"a", homunculus_id:id}, other, catalogs)).toEqual({error:"UNTRUSTED_SETUP"});
  }
});
