import { expect, test } from "bun:test";
import manifest from "../../../data/static/expedition_homunculi.json";
import { newExpeditionPassiveState, beginPassiveExchange, triggerExpeditionPassive, finishPassiveAttack, finishPassiveExchange, passiveModifiers, recordPassiveSpellHit, clearExpeditionPassive } from "../expedition_passive_state";
import type { PassiveContext, PassiveEvent } from "../expedition_passives";

const context = (id: string): Omit<PassiveContext, "exchange" | "applied_markers"> => ({fighter: {hp:40,max_hp:100,shielded:true,consecutive_spell_hits:0,attacks_made:0}, target:{debuffed:true}, type_relation:id === "honin" ? "disadvantage" : "advantage", poison_damage:5});
const ready = (id: string, level: number) => { let state = newExpeditionPassiveState(id, level); for (let turn=1;turn<=3;turn++) state=beginPassiveExchange(state,turn); if (id === "luny") {state=recordPassiveSpellHit(state,true);state=recordPassiveSpellHit(state,true);} return state; };

test("all fourteen proposals are replayable, level-scaled, and once per exchange", () => {
 for (const hom of manifest.homunculi) for (const level of [0,3,6,10]) {
  const state=ready(hom.id,level), input=context(hom.id), event=hom.passive.event as PassiveEvent;
  const a=triggerExpeditionPassive(state,event,input), b=triggerExpeditionPassive(structuredClone(state),event,input);
  expect(a).toEqual(b); expect(a.activated).toBe(true); expect(triggerExpeditionPassive(a.state,event,input).activated).toBe(false);
  expect(state.markers).toEqual([]); expect(a.state.markers).toHaveLength(1);
  expect(triggerExpeditionPassive(state,event === "dodge" ? "weapon_switched" : "dodge",input).activated).toBe(false);
 }
});

test("attack, exchange and next exchange modifiers expire at their own boundaries", () => {
 let state=ready("luny",10); state=triggerExpeditionPassive(state,"before_attack",context("luny")).state;
 expect(passiveModifiers(state)).toEqual({power_flat:3,tempo_flat:2});
 state=finishPassiveAttack(state); expect(passiveModifiers(state)).toEqual({tempo_flat:2});
 state=finishPassiveExchange(state); expect(passiveModifiers(state)).toEqual({});
 state=ready("hyrox",10); state=triggerExpeditionPassive(state,"dodge",context("hyrox")).state;
 expect(passiveModifiers(state)).toEqual({}); state=finishPassiveExchange(state); state=beginPassiveExchange(state,4);
 expect(passiveModifiers(state)).toEqual({evasion_pct:0.05,tempo_flat:2});
 state=finishPassiveExchange(state); state=beginPassiveExchange(state,5); expect(passiveModifiers(state)).toEqual({});
});

test("counterconditions, counters, instant bounds and reset", () => {
 let state=ready("luny",3); state=recordPassiveSpellHit(state,false); expect(triggerExpeditionPassive(state,"before_attack",context("luny")).activated).toBe(false);
 state=ready("solcarp",0); state=finishPassiveAttack(state); expect(triggerExpeditionPassive(state,"before_attack",context("solcarp")).activated).toBe(false);
 state=ready("venam",10); const c=context("venam"); c.fighter.hp=99; c.poison_damage=2;
 expect(triggerExpeditionPassive(state,"opponent_poison_damage",c).instant).toEqual([{kind:"heal",target:"self",amount:1}]);
 c.poison_damage=0; expect(triggerExpeditionPassive(state,"opponent_poison_damage",c).activated).toBe(false);
 state=ready("crishvin",10); expect(triggerExpeditionPassive(state,"damage_received",context("crishvin")).instant).toEqual([{kind:"poison",target:"target",amount:2}]);
 state=clearExpeditionPassive(state); expect(state.exchange).toBe(0); expect(state.modifiers).toEqual([]); expect(state.attacks_made).toBe(0);
 expect(()=>beginPassiveExchange(state,2)).toThrow(); expect(()=>newExpeditionPassiveState("invalid",0)).toThrow();
});
