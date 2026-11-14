import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn, deterministicDraw, resolveInspirationDecision, restoreInspiration, bossStrikeMultiplier, selectBossIntent } from "../solo_hunt_combat";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", name), "utf8"));
const catalogs = { entities: read("entities.json").entities, items: read("items.json").items, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} };
const selection = { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
const rng = (_turn: number, draw: number) => draw % 2 === 0 ? 0 : 0.99;

test("independent hunt selection validates unlocks without changing PvP equipment", () => {
  const ids = ["steady_script", ...selection.spell_ids.slice(1)];
  const progress = { learned_by_entity: { sulfur_01: ["steady_script"] }, equipped_by_mode: { attack: { sulfur_01: [...selection.spell_ids] } } };
  const trusted = { ...snapshot, spell_progress: progress };
  const chosen = { ...selection, weapon_ids: ["bismuth_talisman", "wind_amulet"], spell_ids: ids };
  const before = structuredClone(trusted);
  expect(buildTrustedCombatSetup(trusted, chosen, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup(trusted, chosen, catalogs, { independentLoadout: true }).error).toBeUndefined();
  expect(trusted).toEqual(before);
  expect(buildTrustedCombatSetup({ ...trusted, spell_progress: {} }, chosen, catalogs, { independentLoadout: true })).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup(trusted, { ...chosen, spell_ids: ["steady_script", "steady_script", ...ids.slice(2)] }, catalogs, { independentLoadout: true })).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup(trusted, { ...chosen, atk: 999 }, catalogs, { independentLoadout: true })).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("tier HP progression, strike thresholds and boss catalog validation", () => {
  expect(catalogs.bosses.map((boss: any) => boss.hp_mult)).toEqual([1, 1.22, 1.525, 1.83, 2.2692]);
  expect(catalogs.bosses.map((boss: any) => boss.attack_mult)).toEqual([1, 1.15, 1.35, 1.55, 1.8]);
  expect([71, 70, 41, 40, 16, 15, 0].map(hp => bossStrikeMultiplier(hp, 100))).toEqual([1, 1.2, 1.2, 1.4, 1.4, 1.6, 1.6]);
  expect(() => bossStrikeMultiplier(101, 100)).toThrow();
  const malformed = structuredClone(catalogs);
  malformed.bosses[0].shield_reduction = 1.1;
  expect(buildTrustedCombatSetup(snapshot, selection, malformed)).toEqual({ error: "UNTRUSTED_SETUP" });
  malformed.bosses[0] = { ...catalogs.bosses[0], signature_pool: ["not_a_spell"] };
  expect(buildTrustedCombatSetup(snapshot, selection, malformed)).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("all five tiers initialize with scaled stats and eligible tiers summon", () => {
  for (const boss of catalogs.bosses) {
    const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: boss.id }, selection, catalogs);
    expect(setup.error).toBeUndefined();
    let state = createCombatState(setup);
    expect([state.boss_tier, state.boss.hp, state.boss.atk]).toEqual([boss.tier, Math.round(112 * boss.hp_mult), Math.round(16 * boss.attack_mult)]);
    for (let turn = 1; turn <= 2; turn++) {
      const before = structuredClone(state);
      const decision = { turn, spell_id: "cinder_fist", target: "boss" };
      const result = resolveCombatTurn(state, decision, () => 0.99);
      expect(result.error).toBeUndefined();
      expect(resolveCombatTurn(state, decision, () => 0.99)).toEqual(result);
      expect(state).toEqual(before);
      state = result.next_state;
    }
    if (boss.tier !== "common") {
      expect(state.boss_intent).toBe("Summon");
      const result = resolveCombatTurn(state, { turn: 3, spell_id: "cinder_fist", target: "boss" }, () => 0.99);
      expect(result.next_state.minions.length).toBe(boss.minions);
      expect(result.events.some((e: any) => e.kind === "minion_attack")).toBe(false);
    }
  }
});

test("signature selection uses deterministic injected server draws and official catalogs", () => {
  for (const boss of catalogs.bosses) {
    const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: boss.id }, selection, catalogs);
    const first = createCombatState(setup, () => 0);
    const second = createCombatState(setup, () => 0.99);
    expect(first.selected_signature).toBe(boss.signature_pool[0]);
    expect(second.selected_signature).toBe(boss.signature_pool[1]);
    expect([first.boss_signature.id, first.rng_counter]).toEqual([first.selected_signature, 1]);
    expect(createCombatState(setup, () => 0.99)).toEqual(second);
    expect(() => createCombatState(setup, () => 1)).toThrow("Invalid RNG draw");
  }
});

test("summoned minions protect their boss, have independent HP and attack on later exchanges", () => {
  const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_rare" }, selection, catalogs);
  let state = createCombatState(setup);
  for (let turn = 1; turn <= 3; turn++) state = resolveCombatTurn(state, { turn, spell_id: "cinder_fist", target: "boss" }, () => 0.99).next_state;
  expect(state.minions.map((m: any) => [m.id, m.hp, m.atk])).toEqual([["minion_0", 22, 4], ["minion_1", 22, 4]]);
  const before = structuredClone(state);
  let draws = 0;
  expect(resolveCombatTurn(state, { turn: 4, spell_id: "cinder_fist", target: "boss" }, () => { draws++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(draws).toBe(0);
  expect(state).toEqual(before);
  const decision = { turn: 4, spell_id: "cinder_fist", target: "minion_0" };
  const result = resolveCombatTurn(state, decision, () => 0);
  expect(result.error).toBeUndefined();
  expect(result.next_state.boss.hp).toBe(state.boss.hp);
  expect(result.next_state.minions[0].hp).toBeLessThan(22);
  expect(result.next_state.minions[1].hp).toBe(22);
  expect(result.events.filter((e: any) => e.kind === "minion_attack").length).toBe(result.next_state.minions.filter((m: any) => m.hp > 0).length);
  expect(resolveCombatTurn(state, decision, () => 0)).toEqual(result);
  state.minions[0].hp = 1;
  const killed = resolveCombatTurn(state, decision, () => 0);
  expect(killed.next_state.minions[0].hp).toBe(0);
  expect(killed.events.some((e: any) => e.kind === "minion_defeated" && e.actor === "minion_0")).toBe(true);
  expect(killed.events.some((e: any) => e.kind === "boss_exposed")).toBe(false);
  expect(killed.next_state.minions[1].hp).toBe(22);
  let staleDraws = 0;
  expect(resolveCombatTurn(killed.next_state, { ...decision, turn: 5 }, () => { staleDraws++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(staleDraws).toBe(0);
});

test("summon before player initiative protects boss without redirecting the chosen attack", () => {
  const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_mythic" }, selection, catalogs);
  const state = createCombatState(setup);
  state.boss_actions_taken = 2;
  state.boss_intent = "Summon";
  state.boss.status.tempo_bonus = 1;
  const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
  expect(result.next_state.boss.hp).toBe(state.boss.hp);
  expect(result.next_state.minions[0].hp).toBe(result.next_state.minions[0].max_hp);
  expect(result.events.some((e: any) => e.kind === "minion_attack")).toBe(false);
});

test("minion stun and poison expire independently without affecting the other minion", () => {
  const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_rare" }, selection, catalogs);
  let state = createCombatState(setup);
  for (let turn = 1; turn <= 3; turn++) state = resolveCombatTurn(state, { turn, spell_id: "cinder_fist", target: "boss" }, () => 0.99).next_state;
  state.minions[0].status = { stun: 1, poison: 2 };
  const result = resolveCombatTurn(state, { turn: 4, spell_id: "cinder_fist", target: "minion_1" }, () => 0.99);
  expect(result.next_state.minions[0].hp).toBe(20);
  expect(result.next_state.minions[0].status.stun).toBe(0);
  expect(result.events.filter((e: any) => e.kind === "status_consumed" && e.target === "minion_0" && e.status === "stun")).toHaveLength(1);
  expect(result.next_state.minions[0].status.poison).toBe(1);
  expect(result.events.some((e: any) => e.kind === "status_tick" && e.target === "minion_0" && e.damage === 2 && e.hp === 20 && e.remaining === 1)).toBe(true);
  expect(result.events.find((e: any) => e.kind === "status_snapshot" && e.target === "minion_0").status).toEqual({ stun: 0, poison: 1 });
  expect(result.next_state.minions[1].hp).toBe(22);
  expect(result.events.filter((e: any) => e.kind === "minion_attack").map((e: any) => e.actor)).toEqual(["minion_1"]);
});

test("poison ticks once for each living fighter even while boss is protected", () => {
  const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_rare" }, selection, catalogs);
  let state = createCombatState(setup);
  for (let turn = 1; turn <= 3; turn++) state = resolveCombatTurn(state, { turn, spell_id: "cinder_fist", target: "boss" }, () => 0.99).next_state;
  state.boss.status.poison = 1;
  state.player.status.poison = 1;
  state.minions[0].status.poison = 1;
  state.minions[1].status.poison = 1;
  state.minions[0].hp = 1;
  state.boss.hp = 1;
  state.boss.status.stun = 1;
  state.minions[0].status.stun = 1;
  state.minions[1].status.stun = 1;
  const original = structuredClone(state);
  const decision = { turn: 4, spell_id: "cinder_fist", target: "minion_1" };
  const result = resolveCombatTurn(state, decision, () => 0.99);
  const ticks = result.events.filter((e: any) => e.kind === "status_tick");
  expect(ticks.map((e: any) => e.target)).toEqual(["player", "boss", "minion_0", "minion_1"]);
  expect(ticks.map((e: any) => e.damage)).toEqual([2, 1, 1, 2]);
  expect(ticks.every((e: any) => e.remaining === 0)).toBe(true);
  expect(result.terminal_result).toBeNull();
  expect(result.next_state.minions[1].hp).toBeGreaterThan(0);
  expect(result.events.some((e: any) => e.kind === "minion_defeated" && e.actor === "minion_0")).toBe(true);
  expect(result.events.some((e: any) => e.kind === "status_snapshot" && e.target === "boss" && e.status.poison === 0)).toBe(true);
  expect(state).toEqual(original);
  expect(resolveCombatTurn(state, decision, () => 0.99)).toEqual(result);
  const unprotected = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  unprotected.boss.status = { stun: 1, poison: 1 };
  const before = structuredClone(unprotected);
  delete before.boss.status.poison;
  let ticksDraws = 0, baselineDraws = 0;
  const poisonResult = resolveCombatTurn(unprotected, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => { ticksDraws++; return 0.99; });
  resolveCombatTurn(before, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => { baselineDraws++; return 0.99; });
  expect(poisonResult.events.filter((e: any) => e.kind === "status_tick" && e.target === "boss")).toMatchObject([{ damage: 2, remaining: 0 }]);
  expect(ticksDraws).toBe(baselineDraws);
});

test("reflection poison transitions reflect changes and ignored effects", () => {
  const make = () => {
    const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
    state.boss.status = { stun: 1, reflect_pct: 0.2, poison_on_reflect: 2 };
    return state;
  };
  const decision = { turn: 1, spell_id: "cinder_fist", target: "boss" };
  const state = make();
  const hit = resolveCombatTurn(state, decision, () => 0.5);
  expect(hit.events.filter((e: any) => e.kind === "status_applied" && e.source === "poison_on_reflect")).toMatchObject([{ target: "player", previous: 0, value: 2 }]);
  expect(hit.events.filter((e: any) => e.kind === "status_consumed" && e.status === "poison_on_reflect")).toMatchObject([{ target: "boss", previous: 2, value: 0, ignored: false }]);
  expect(resolveCombatTurn(state, decision, () => 0.5)).toEqual(hit);
  const ignored = make(); ignored.item_effects.ignore_reflect_chance = 1;
  const skipped = resolveCombatTurn(ignored, decision, () => 0.5);
  expect(skipped.events.some((e: any) => e.kind === "status_applied" && e.source === "poison_on_reflect")).toBe(false);
  expect(skipped.events.find((e: any) => e.status === "poison_on_reflect" && e.kind === "status_consumed").ignored).toBe(true);
  const stronger = make(); stronger.player.status.poison = 3;
  expect(resolveCombatTurn(stronger, decision, () => 0.5).events.some((e: any) => e.kind === "status_applied" && e.source === "poison_on_reflect")).toBe(false);
  const unarmed = make(); delete unarmed.boss.status.reflect_pct;
  const noReflection = resolveCombatTurn(unarmed, decision, () => 0.5);
  expect(noReflection.next_state.boss.status.poison_on_reflect).toBe(2);
  expect(noReflection.events.some((e: any) => e.kind === "status_consumed" && e.status === "poison_on_reflect")).toBe(false);
});

test("deterministic complete encounters terminate for every tier", () => {
  for (const boss of catalogs.bosses) {
    const simulate = () => {
      const random = (turn: number, draw: number) => deterministicDraw(new Uint8Array(32).fill(7), boss.id, turn, draw);
      let state = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_id: boss.id }, selection, catalogs), random);
      const actions: string[] = [];
      for (let i = 0; i < 100 && !state.terminal_result; i++) {
        if (state.player.inspiration_pending) {
          const declined = resolveInspirationDecision(state, { kind: "decline" }, random);
          expect(declined.error).toBeUndefined();
          state = declined.next_state;
          continue;
        }
        const target = state.minions.find((m: any) => m.hp > 0)?.id ?? "boss";
        const result = resolveCombatTurn(state, { turn: state.turn + 1, spell_id: "cinder_fist", target }, random);
        expect(result.error).toBeUndefined();
        actions.push(...result.events.map((e: any) => e.kind));
        state = result.next_state;
      }
      expect(["WIN", "LOSS"]).toContain(state.terminal_result);
      return { turn: state.turn, result: state.terminal_result, actions };
    };
    expect(simulate()).toEqual(simulate());
  }
});

test("seeded combat matrix across tiers and equipment", () => {
  const summary: Record<string, any[]> = {};
  for (const boss of catalogs.bosses) {
    summary[boss.tier] = [];
    for (const weaponIds of [[null, null], ["bismuth_talisman", "wind_amulet"]]) for (const seed of [7, 17, 29]) {
      const run = () => {
        const random = (turn: number, draw: number) => deterministicDraw(new Uint8Array(32).fill(seed), boss.id, turn, draw);
        const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: boss.id }, { ...selection, weapon_ids: weaponIds }, catalogs);
        expect(setup.error).toBeUndefined();
        let state = createCombatState(setup, random);
        const counts: Record<string, number> = {};
        let prevented = 0, healing = 0;
        for (let i = 0; i < 100 && !state.terminal_result; i++) {
          if (state.player.inspiration_pending) {
            const decision = resolveInspirationDecision(state, { kind: "decline" }, random);
            expect(decision.error).toBeUndefined();
            state = decision.next_state;
            continue;
          }
          const target = state.minions.find((m: any) => m.hp > 0)?.id ?? "boss";
          const result = resolveCombatTurn(state, { turn: state.turn + 1, spell_id: "cinder_fist", target }, random);
          expect(result.error).toBeUndefined();
          for (const event of result.events) {
            const key = event.kind === "boss_action" ? `action_${event.action}` : event.kind;
            counts[key] = (counts[key] ?? 0) + 1;
            if (event.kind === "boss_shield") { prevented += event.prevented; healing += event.heal; }
          }
          state = result.next_state;
          expect(state.boss.hp).toBeLessThanOrEqual(state.boss.max_hp);
          expect(new Set(state.boss_shield_phases).size).toBe(state.boss_shield_phases.length);
          expect(counts.boss_summon ?? 0).toBeLessThanOrEqual(1);
        }
        expect(["WIN", "LOSS"]).toContain(state.terminal_result);
        return { seed, weapon: weaponIds[0], turns: state.turn, result: state.terminal_result, counts, prevented, healing };
      };
      const result = run();
      expect(run()).toEqual(result);
      summary[boss.tier].push(result);
    }
  }
  console.log("Solo hunt seeded matrix:", JSON.stringify(summary));
});

test("progressed server-owned build can finish seeded hunts", () => {
  const progress = { item_progress: { bismuth_talisman: { level: 10, specialization: "aggressive", traits: [{ id: "power_flat", points: 4 }, { id: "true_on_hit", points: 4 }, { id: "dot_true", points: 2 }] } }, homunculus_progress: { cinder: { level: 10, mutation_id: "vitality" } } };
  const results: Record<string, string[]> = {};
  for (const boss of catalogs.bosses) {
    results[boss.tier] = [];
    for (const seed of [7, 17, 29]) {
      const random = (turn: number, draw: number) => deterministicDraw(new Uint8Array(32).fill(seed), boss.id, turn, draw);
      const setup = buildTrustedCombatSetup({ ...snapshot, ...progress, boss_id: boss.id }, { ...selection, weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder" }, catalogs);
      expect(setup.error).toBeUndefined();
      let state = createCombatState(setup, random);
      for (let i = 0; i < 100 && !state.terminal_result; i++) {
        if (state.player.inspiration_pending) { state = resolveInspirationDecision(state, { kind: "decline" }, random).next_state; continue; }
        const target = state.minions.find((m: any) => m.hp > 0)?.id ?? "boss";
        const spell_id = state.cooldowns.brimstone_crash > 0 ? "cinder_fist" : "brimstone_crash";
        const decision: any = { turn: state.turn + 1, spell_id, target };
        if (state.hom_energy >= 3) decision.hom_action = "attack";
        const result = resolveCombatTurn(state, decision, random);
        expect(result.error).toBeUndefined();
        state = result.next_state;
      }
      expect(["WIN", "LOSS"]).toContain(state.terminal_result);
      results[boss.tier].push(`${state.terminal_result}@${state.turn}`);
    }
    expect(results[boss.tier].some(outcome => outcome.startsWith("WIN@"))).toBe(true);
  }
  console.log("Progressed build outcomes:", JSON.stringify(results));
});

test("tactical intent respects Fury, summoning, shield, cooldown and weak player", () => {
  const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_mythic" }, selection, catalogs));
  state.boss_actions_taken = 2;
  expect(selectBossIntent(state, 0)).toBe("Summon");
  state.fury_pending = true;
  expect(selectBossIntent(state, 99)).toBe("Fury Strike");
  state.fury_pending = false;
  state.summoned = true;
  state.boss.hp = Math.floor(state.boss.max_hp * 0.4);
  expect(selectBossIntent(state, 20)).toBe("Shield");
  state.boss_shield_cooldown = 3;
  state.boss_cooldowns[state.selected_signature] = 1;
  state.player.hp = 1;
  expect(selectBossIntent(state, 0)).toBe("Strike");
});

test("boss signature uses its own element and protected bosses do not choose shield", () => {
  for (const draw of [0, 0.99]) {
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_mythic", boss_entity_id: "gold_01" }, selection, catalogs), () => draw);
    expect(state.boss.type).not.toBe(state.boss_signature.type);
    state.player.status.stun = 1;
    state.boss_intent = "Special";
    const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
    expect(result.error).toBeUndefined();
    const relation = catalogs.types.effectiveness[state.boss_signature.type][state.player.type];
    const mult = relation > 1 ? 1.12 : relation < 1 ? 0.92 : 1;
    const expected = Math.max(1, Math.round((state.boss.atk - Math.trunc(state.player.def * 0.5)) * mult * state.boss_signature.power_mult));
    expect(result.events.find((e: any) => e.actor === "boss" && e.kind === "damage").damage).toBe(expected);
  }
  const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_mythic" }, selection, catalogs));
  state.summoned = true;
  state.boss.hp = 30;
  state.minions = [{ id: "minion_0", hp: 10 }];
  expect(selectBossIntent(state, 30)).not.toBe("Shield");
});

test("tactical intent values a useful signature debuff and avoids repeating it", () => {
  const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_epic" }, selection, catalogs), () => 0.99);
  state.boss_actions_taken = 2;
  state.summoned = true;
  expect(state.selected_signature).toBe("brimstone_crash");
  expect(selectBossIntent(state, 0)).toBe("Special");
  state.player.status.atk_down = 0.12;
  expect(selectBossIntent(state, 0)).toBe("Strike");
});

test("special events report only applied effects and misses do not apply debuffs", () => {
  const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_epic" }, selection, catalogs);
  const state = createCombatState(setup, () => 0.99);
  state.boss_intent = "Special";
  state.player.status.stun = 1;
  const decision = { turn: 1, spell_id: "cinder_fist", target: "boss" };
  const landed = resolveCombatTurn(state, decision, () => 0);
  const event = landed.events.find((e: any) => e.kind === "boss_special_cast");
  expect(event.spell_id).toBe("brimstone_crash");
  expect(event.applied_effects).toEqual([{ kind: "atk_down", target: "player", value: 0.12 }]);
  expect(landed.next_state.player.status.atk_down).toBe(0.12);
  const missed = resolveCombatTurn(state, decision, () => 0.99);
  expect(missed.events.find((e: any) => e.kind === "boss_special_cast").applied_effects).toEqual([]);
  expect(missed.next_state.player.status.atk_down).toBeUndefined();
});

test("Common signature resolves once, preserves replay and does not loop", () => {
  let state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs), () => 0);
  for (let turn = 1; turn <= 2; turn++) {
    state = resolveCombatTurn(state, { turn, spell_id: "cinder_fist", target: "boss" }, () => 0.99).next_state;
  }
  expect(state.boss_intent).toBe("Special");
  const before = structuredClone(state);
  const decision = { turn: 3, spell_id: "cinder_fist", target: "boss" };
  const result = resolveCombatTurn(state, decision, () => 0);
  expect(result.error).toBeUndefined();
  expect(result.events.some((event: any) => event.kind === "boss_special_cast" && event.spell_id === "cinder_fist" && event.landed)).toBe(true);
  expect(result.next_state.player.hp).toBeLessThan(state.player.hp);
  expect(result.next_state.boss_intent).toBe("Strike");
  expect(state).toEqual(before);
  expect(resolveCombatTurn(state, decision, () => 0)).toEqual(result);
});

test("a stunned boss retains its committed Special without spending its cooldown", () => {
  const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs), () => 0);
  state.boss_intent = "Special";
  state.boss.status.stun = 1;
  const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0.99);
  expect(result.error).toBeUndefined();
  expect(result.next_state.boss_intent).toBe("Special");
  expect(result.next_state.boss_cooldowns.cinder_fist ?? 0).toBe(0);
  expect(result.events.some((event: any) => event.kind === "boss_special_cast")).toBe(false);
});

test("Common boss shield protects a full subsequent exchange and then cools down", () => {
  const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  state.boss.hp -= 1;
  state.boss_intent = "Shield";
  const first = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
  expect(first.error).toBeUndefined();
  expect(first.next_state.boss_shield_turns).toBe(1);
  expect(first.events.some((e: any) => e.kind === "boss_shield_activated")).toBe(true);
  const second = resolveCombatTurn(first.next_state, { turn: 2, spell_id: "cinder_fist", target: "boss" }, () => 0);
  const shield = second.events.find((e: any) => e.kind === "boss_shield");
  expect(shield.prevented).toBeGreaterThan(0);
  expect(shield.heal).toBe(0);
  expect(second.next_state.boss_shield_turns).toBe(0);
  expect(second.next_state.boss_shield_cooldown).toBe(3);
  expect(second.events.some((e: any) => e.kind === "boss_shield_expired" && e.cooldown === 3)).toBe(true);
});

test("Epic shield heals prevented damage after the hit without exceeding maximum HP", () => {
  const setup = buildTrustedCombatSetup({ ...snapshot, boss_id: "hunt_epic" }, selection, catalogs);
  const state = createCombatState(setup);
  state.boss.hp--;
  state.boss_shield_turns = 2;
  const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
  expect(result.error).toBeUndefined();
  const shield = result.events.find((e: any) => e.kind === "boss_shield");
  const hit = result.events.find((e: any) => e.actor === "player" && e.kind === "damage");
  expect(shield.prevented).toBeGreaterThan(0);
  expect(shield.heal).toBe(Math.floor(shield.prevented * 0.2));
  expect(result.next_state.boss.hp).toBe(state.boss.hp - hit.damage + shield.heal);
  expect(result.next_state.boss.hp).toBeLessThanOrEqual(state.boss.max_hp);
  expect(result.next_state.boss_shield_turns).toBe(1);
});

test("boss commits a shield after a damaging exchange and does not choose it twice in the same phase", () => {
  const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  state.boss.hp = 49;
  state.power_turn_used = true;
  const decision = { turn: 1, spell_id: "cinder_fist", target: "boss" };
  const first = resolveCombatTurn(state, decision, () => 0.99);
  expect(first.next_state.boss_intent).toBe("Shield");
  expect(first.events.some((e: any) => e.kind === "boss_intent" && e.intent === "Shield")).toBe(true);
  expect(resolveCombatTurn(state, decision, () => 0.99)).toEqual(first);
  const second = resolveCombatTurn(first.next_state, { ...decision, turn: 2 }, () => 0.99);
  expect(second.events.some((e: any) => e.kind === "boss_shield_activated")).toBe(true);
  expect(second.next_state.boss_shield_phases).toEqual(["low"]);
  expect(second.next_state.boss_intent).not.toBe("Shield");
});

test("Common power opportunity and Fury survive invalid decisions and stun", () => {
  let state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  state.boss.hp = 55;
  state.boss_shield_phases = ["low"];
  for (let turn = 1; turn <= 4; turn++) {
    const result = resolveCombatTurn(state, { turn, spell_id: "cinder_fist", target: "boss" }, () => 0.99);
    expect(result.error).toBeUndefined();
    state = result.next_state;
    expect(state.power_turn_active).toBe(turn === 4);
  }
  expect(state.power_turn_eligible).toBe(4);
  const before = structuredClone(state);
  let invalidDraws = 0;
  expect(resolveCombatTurn(state, { turn: 5, spell_id: "unknown", target: "boss" }, () => { invalidDraws++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(invalidDraws).toBe(0);
  expect(state).toEqual(before);
  const decision = { turn: 5, spell_id: "cinder_fist", target: "boss" };
  const baseline = structuredClone(state); baseline.power_turn_active = false;
  const ordinary = resolveCombatTurn(baseline, decision, () => 0.2);
  const powered = resolveCombatTurn(state, decision, () => 0.2);
  const normalDamage = ordinary.events.find((event: any) => event.actor === "player" && event.kind === "damage").damage;
  const boostedDamage = powered.events.find((event: any) => event.actor === "player" && event.kind === "damage").damage;
  expect(boostedDamage).toBe(normalDamage * 2);
  expect(powered.next_state.fury_pending).toBe(true);
  expect(powered.next_state.boss_intent).toBe("Fury Strike");
  expect(resolveCombatTurn(state, decision, () => 0.2)).toEqual(powered);
  const stunned = powered.next_state; stunned.boss.status.stun = 1;
  const delayedResult = resolveCombatTurn(stunned, { turn: 6, spell_id: "cinder_fist", target: "boss" }, () => 0.99);
  expect(delayedResult.events.some((event: any) => event.kind === "fury_delayed" && event.multiplier === 2)).toBe(true);
  expect(delayedResult.events.some((event: any) => event.kind === "boss_action")).toBe(false);
  const delayed = delayedResult.next_state;
  expect(delayed.fury_pending).toBe(true);
  const fired = resolveCombatTurn(delayed, { turn: 7, spell_id: "cinder_fist", target: "boss" }, () => 0.99);
  expect(fired.events.find((event: any) => event.kind === "fury_strike_resolved")).toMatchObject({ multiplier: 2, landed: false });
  expect(fired.next_state.fury_pending).toBe(false);
  expect(fired.next_state.power_turn_used).toBe(true);
});

test("validated setup and deterministic direct exchange", () => {
  const setup = buildTrustedCombatSetup(snapshot, selection, catalogs);
  expect(setup.error).toBeUndefined();
  const state = createCombatState(setup);
  expect([state.player.hp, state.player.atk, state.player.def]).toEqual([104, 21, 11]);
  expect([state.boss.hp, state.boss.atk, state.boss.def]).toEqual([112, 16, 16]);
  const before = structuredClone(state);
  const decision = { turn: 1, spell_id: "cinder_fist", target: "boss" };
  const result = resolveCombatTurn(state, decision, rng);
  expect(result.error).toBeUndefined();
  expect([result.next_state.player.hp, result.next_state.boss.hp]).toEqual([93, 101]);
  expect(result.next_state.turn).toBe(1);
  expect(resolveCombatTurn(state, decision, rng)).toEqual(result);
  const missed = resolveCombatTurn(state, decision, () => 0.99);
  expect([missed.next_state.player.hp, missed.next_state.boss.hp, missed.next_state.rng_counter]).toEqual([104, 112, 2]);
  expect(resolveCombatTurn({ ...state, terminal_result: "WIN" }, decision, rng)).toEqual({ error: "INVALID_DECISION" });
  expect(state).toEqual(before);
  expect(resolveCombatTurn(state, { ...decision, hp: 999 }, rng)).toEqual({ error: "INVALID_DECISION" });
  const proc = resolveCombatTurn(state, decision, () => 0);
  expect(proc.next_state.boss.status.atk_down ?? 0).toBe(0);
  expect(proc.events.some((e: any) => e.kind === "elemental_proc" && e.type === "sulfur")).toBe(true);
  const support = resolveCombatTurn(state, { ...decision, spell_id: "ash_temper" }, rng);
  expect(support.next_state.player.status.atk_boost).toBe(0.2);
  expect(support.next_state.cooldowns.ash_temper).toBe(2);
  const rush = resolveCombatTurn(state, { ...decision, spell_id: "furnace_rush" }, rng);
  expect(rush.next_state.player.hp).toBeLessThan(104);
  expect(rush.next_state.cooldowns.furnace_rush).toBe(2);
  expect(rush.next_state.player.status.vuln_pct ?? 0).toBe(0);
  const crash = resolveCombatTurn(state, { ...decision, spell_id: "brimstone_crash" }, rng);
  expect(crash.next_state.boss.status.atk_down ?? 0).toBe(0);
  expect(crash.next_state.player.hp).toBeGreaterThan(93);
  expect(resolveCombatTurn(support.next_state, { turn: 2, spell_id: "ash_temper", target: "boss" }, rng)).toEqual({ error: "INVALID_DECISION" });
});

test("trust, spell and deterministic RNG boundaries", () => {
  expect(createCombatState({ selection_authority: "SERVER_VALIDATED" })).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup(snapshot, { ...selection, state_revision: 50 }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup(snapshot, { ...selection, spell_ids: ["steady_script", ...selection.spell_ids.slice(1)] }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  const mismatched = { ...selection, spell_ids: ["null_lattice", ...selection.spell_ids.slice(1)] };
  const progress = { learned_by_entity: { sulfur_01: ["null_lattice"] }, equipped_by_mode: { attack: { sulfur_01: mismatched.spell_ids } } };
  expect(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, mismatched, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  const equipped = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  expect(resolveCombatTurn(equipped, { turn: 1, spell_id: "steady_script", target: "boss" }, rng)).toEqual({ error: "INVALID_DECISION" });
  const secret = new Uint8Array(32).fill(42);
  expect(deterministicDraw(secret, "session", 1, 0)).toBe(deterministicDraw(secret, "session", 1, 0));
});

test("six elemental procs resolve and update combat state", () => {
  for (const type of ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"]) {
    const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
    state.player.type = type;
    state.spells.find((s: any) => s.id === "cinder_fist").type = type;
    state.boss.type = "unknown";
    state.player.hp = 90;
    const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
    expect(result.events.some((e: any) => e.kind === "elemental_proc" && e.type === type)).toBe(true);
    if (type === "mercury") expect(result.next_state.player.hp).toBe(90);
    if (type === "aether") expect(result.next_state.boss.status.vuln_pct).toBe(0.12);
    if (type === "vitriol") expect(result.next_state.boss.status.poison).toBe(1);
    if (type === "gold") expect(result.next_state.player.hp).toBeGreaterThan(79);
    if (type === "sodium") expect(result.next_state.player.hp).toBeGreaterThan(79);
    if (type === "sulfur") expect(result.next_state.player.hp).toBeGreaterThan(79);
  }
  const capped = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  capped.player.type = "gold";
  capped.spells.find((s: any) => s.id === "cinder_fist").type = "gold";
  capped.player.hp = 103;
  capped.boss.status.stun = 1;
  const result = resolveCombatTurn(capped, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
  expect(result.next_state.player.hp).toBe(104);
});

test("validated Mercury and Sodium defensive spells", () => {
  const fixture = (type: string, spells: string[]) => createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: type + "_01", spell_ids: spells }, catalogs));
  const mercury = () => fixture("mercury", ["silver_needle", "false_signal", "liquid_decoy", "mercury_snare"]);
  const sodium = () => fixture("sodium", ["crystal_ram", "salt_barrier", "brine_mend", "bastion_return"]);
  const hit = (_turn: number, draw: number) => [0, 0, 0.99][draw % 3];
  const cast = (state: any, spell_id: string, random = hit) => resolveCombatTurn(state, { turn: 1, spell_id, target: "boss" }, random);
  const decoy = cast(mercury(), "liquid_decoy");
  expect(decoy.next_state.player.hp).toBe(86);
  expect(decoy.next_state.player.status.shield_pct ?? 0).toBe(0);
  const stronger = mercury(); stronger.player.status.shield_pct = 0.3;
  expect(cast(stronger, "liquid_decoy").next_state.player.hp).toBe(88);
  const barrier = cast(sodium(), "salt_barrier");
  expect(barrier.next_state.player.hp).toBe(106);
  const barrierProc = cast(sodium(), "salt_barrier", () => 0);
  expect(barrierProc.next_state.player.hp).toBe(106);
  expect(barrierProc.next_state.boss.status.shield_pct).toBe(0.12);
  const injured = sodium(); injured.player.hp = 50;
  const healed = cast(injured, "brine_mend");
  expect(healed.next_state.player.hp).toBe(53);
  const full = sodium(); full.boss.status.stun = 1;
  expect(cast(full, "brine_mend").next_state.player.hp).toBe(112);
  const reflected = cast(sodium(), "bastion_return");
  expect(reflected.events.find((e: any) => e.kind === "reflect").damage).toBe(1);
  expect(reflected.next_state.boss.hp).toBe(111);
  expect(reflected.next_state.player.status.reflect_pct ?? 0).toBe(0);
  const snare = cast(mercury(), "mercury_snare", () => 0);
  expect(snare.next_state.boss.status.hom_stun).toBe(1);
  const miss = cast(mercury(), "mercury_snare", () => 0.99);
  expect(miss.next_state.boss.hp).toBe(112);
  expect(miss.next_state.cooldowns.mercury_snare).toBe(3);
  expect(cast(sodium(), "bastion_return")).toEqual(reflected);
  for (const [state, id] of [[mercury(), "silver_needle"], [mercury(), "false_signal"], [sodium(), "crystal_ram"]] as const) {
    expect(cast(state, id, () => 0).next_state.boss.hp).toBeLessThan(112);
  }
});

test("native Aether and Vitriol spells, delayed neutralization and poison", () => {
  const aether = ["rift_touch", "null_stitch", "veil_rupture", "paradox_fold"];
  const vitriol = ["etching_fang", "caustic_mark", "bitter_haze", "rot_harvest"];
  const fixture = (type: string, spells: string[], bossId: string) => createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: bossId }, { ...selection, entity_id: type + "_01", spell_ids: spells }, catalogs));
  const draws = (_turn: number, counter: number) => counter % 2 === 0 ? 0 : 0.99;
  for (const [type, spells, bossId] of [["aether", aether, "sulfur_01"], ["vitriol", vitriol, "sodium_01"]] as const) {
    for (const spell_id of spells) {
      const state = fixture(type, spells, bossId); state.boss.status.stun = 1;
      const before = structuredClone(state);
      const decision = { turn: 1, spell_id, target: "boss" };
      const result = resolveCombatTurn(state, decision, draws);
      expect(result.error).toBeUndefined();
      expect(result.next_state.cooldowns[spell_id]).toBe(state.spells.find((s: any) => s.id === spell_id).cooldown_turns);
      expect(resolveCombatTurn(state, decision, draws)).toEqual(result);
      expect(state).toEqual(before);
    }
  }
  const base = fixture("aether", aether, "sulfur_01"); base.boss.status.stun = 1;
  expect(resolveCombatTurn(base, { turn: 1, spell_id: "rift_touch", target: "boss" }, draws).next_state.boss.hp).toBe(88);
  const fold = resolveCombatTurn(base, { turn: 1, spell_id: "paradox_fold", target: "boss" }, draws).next_state;
  expect(fold.player.spell_neutralize_pending).toBe(0.5);
  expect(fold.player.spell_neutralize_active).toBe(0);
  fold.boss.status.stun = 1;
  const follow = resolveCombatTurn(fold, { turn: 2, spell_id: "rift_touch", target: "boss" }, () => 0.1).next_state;
  expect(follow.boss.hp).toBe(89);
  expect([follow.player.spell_neutralize_pending, follow.player.spell_neutralize_active]).toEqual([0, 0]);
  const plain = fixture("vitriol", vitriol, "sodium_01"); plain.boss.status.stun = 1;
  const poisoned = structuredClone(plain); poisoned.boss.status.poison = 2;
  const action = { turn: 1, spell_id: "rot_harvest", target: "boss" };
  expect(resolveCombatTurn(plain, action, draws).next_state.boss.hp).toBe(98);
  const harvest = resolveCombatTurn(poisoned, action, draws).next_state;
  expect([harvest.boss.hp, harvest.boss.status.poison]).toEqual([91, 1]);
  const marked = resolveCombatTurn(plain, { turn: 1, spell_id: "caustic_mark", target: "boss" }, draws).next_state;
  expect(marked.boss.status.poison).toBe(1);
});

test("reflection uses calculated damage even when the target has little HP", () => {
  const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  state.player.hp = 1;
  state.player.status.reflect_pct = 0.5;
  const result = resolveCombatTurn(state, { turn: 1, spell_id: "ash_temper", target: "boss" }, () => 0.1);
  expect([result.next_state.player.hp, result.next_state.boss.hp]).toEqual([0, 106]);
  expect(result.events.find((event: any) => event.kind === "reflect").damage).toBe(6);
});

test("Gold spells and received-hit tracking across exchanges", () => {
  const spells = ["aurum_edge", "gilded_reprisal", "debt_seal", "tribunal_strike"];
  const fixture = () => createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: "gold_01", spell_ids: spells }, catalogs));
  const action = (turn: number, spell_id: string) => ({ turn, spell_id, target: "boss" });
  const state = fixture();
  expect([state.player.hp, state.player.atk, state.player.def]).toEqual([104, 18, 14]);
  for (const spell of spells) {
    const result = resolveCombatTurn(fixture(), action(1, spell), rng);
    expect(result.error).toBeUndefined();
    expect(result.next_state.cooldowns[spell]).toBe(state.spells.find((s: any) => s.id === spell).cooldown_turns);
  }
  const normal = resolveCombatTurn(fixture(), action(1, "tribunal_strike"), rng);
  expect(normal.next_state.boss.hp).toBe(99);
  const first = resolveCombatTurn(fixture(), action(1, "aurum_edge"), rng).next_state;
  expect(first.player.spell_hit_this_exchange).toBe(true);
  const boosted = resolveCombatTurn(first, action(2, "tribunal_strike"), rng);
  expect(boosted.events.find((e: any) => e.actor === "player" && e.kind === "damage").damage).toBe(16);
  expect(boosted).toEqual(resolveCombatTurn(first, action(2, "tribunal_strike"), rng));
  const outgoing = fixture(); outgoing.boss.status.stun = 1;
  const onlyHit = resolveCombatTurn(outgoing, action(1, "aurum_edge"), rng).next_state;
  expect(onlyHit.player.spell_hit_this_exchange).toBe(false);
  expect(resolveCombatTurn(onlyHit, action(2, "tribunal_strike"), rng).events[0].damage).toBe(13);
  const missed = resolveCombatTurn(fixture(), action(1, "aurum_edge"), () => 0.99).next_state;
  expect(missed.player.spell_hit_this_exchange).toBe(false);
  const blocked = fixture(); blocked.player.status.shield_pct = 1;
  expect(resolveCombatTurn(blocked, action(1, "aurum_edge"), rng).next_state.player.spell_hit_this_exchange).toBe(false);
  const reflection = fixture(); reflection.boss.status.reflect_pct = 0.5; reflection.boss.status.stun = 1;
  expect(resolveCombatTurn(reflection, action(1, "aurum_edge"), rng).next_state.player.spell_hit_this_exchange).toBe(true);
  const poison = fixture(); poison.player.status.poison = 1; poison.boss.status.stun = 1;
  const poisoned = resolveCombatTurn(poison, action(1, "aurum_edge"), rng).next_state;
  expect(poisoned.player.hp).toBe(102);
  expect(poisoned.player.spell_hit_this_exchange).toBe(true);
  const healing = fixture(); healing.player.hp = 103; healing.boss.status.stun = 1;
  expect(resolveCombatTurn(healing, action(1, "aurum_edge"), () => 0).next_state.player.hp).toBe(104);
});

test("researchable catalog spells resolve or fail closed", () => {
  const unsupported = new Set<string>();
  const counts = { universal: 0, hybrid: 0 };
  for (const spell of catalogs.spells.filter((s: any) => ["universal", "hybrid"].includes(s.type))) {
    const entity = catalogs.entities.find((e: any) => spell.eligible_types.includes(e.type));
    const defaults = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id).slice(0, 4);
    const equipped = [spell.id, ...defaults.slice(1)];
    const progress = { learned_by_entity: { [entity.id]: [spell.id] }, equipped_by_mode: { attack: { [entity.id]: equipped } } };
    const setup = buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: entity.id, spell_ids: equipped }, catalogs);
    const state = createCombatState(setup);
    state.boss.status.stun = 1;
    const decision = { turn: 1, spell_id: spell.id, target: "boss" };
    const before = structuredClone(state);
    const result = resolveCombatTurn(state, decision, rng);
    if (spell.effects.some((effect: any) => unsupported.has(effect.kind))) expect(result).toEqual({ error: "UNSUPPORTED_MECHANIC" });
    else { expect(result.error).toBeUndefined(); counts[spell.type as "universal" | "hybrid"]++; }
    expect(state).toEqual(before);
  }
  console.log("Researchable spells supported:", JSON.stringify(counts));
  expect(counts).toEqual({ universal: 10, hybrid: 30 });
});

test("universal is neutral and hybrid uses both catalog types", () => {
  const setupFor = (id: string) => {
    const ids = [id, "null_stitch", "veil_rupture", "paradox_fold"];
    const progress = { learned_by_entity: { aether_01: [id] }, equipped_by_mode: { attack: { aether_01: ids } } };
    return createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: "sulfur_01", spell_progress: progress }, { ...selection, entity_id: "aether_01", spell_ids: ids }, catalogs));
  };
  const neutral = setupFor("steady_script"); neutral.boss.status.stun = 1;
  expect(resolveCombatTurn(neutral, { turn: 1, spell_id: "steady_script", target: "boss" }, rng).next_state.boss.hp).toBe(92);
  const hybrid = setupFor("void_etching"); hybrid.boss.status.stun = 1;
  expect(resolveCombatTurn(hybrid, { turn: 1, spell_id: "void_etching", target: "boss" }, rng).next_state.boss.hp).toBe(91);
});

test("catalog sweep includes all 64 equipped spells", () => {
  let passed = 0;
  for (const spell of catalogs.spells) {
    const entity = catalogs.entities.find((e: any) => spell.type === e.type || spell.eligible_types?.includes(e.type));
    const defaults = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
    const equipped = [spell.id, ...defaults.filter((id: string) => id !== spell.id).slice(0, 3)];
    const progress = { learned_by_entity: { [entity.id]: [spell.id] }, equipped_by_mode: { attack: { [entity.id]: equipped } } };
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: entity.id, spell_ids: equipped }, catalogs));
    state.boss.status.stun = 1;
    const result = resolveCombatTurn(state, { turn: 1, spell_id: spell.id, target: "boss" }, rng);
    expect(result.error).toBeUndefined();
    expect(result.next_state.turn).toBe(1);
    passed++;
  }
  expect(passed).toBe(64);
});

test("precision, shields, leech and initiative have observable effects", () => {
  const fixture = (id: string, entity = "sulfur_01") => {
    const ids = [id, ...catalogs.spells.filter((s: any) => s.type === catalogs.entities.find((e: any) => e.id === entity).type).map((s: any) => s.id).filter((x: string) => x !== id).slice(0, 3)];
    const progress = { learned_by_entity: { [entity]: [id] }, equipped_by_mode: { attack: { [entity]: ids } } };
    return createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: entity, spell_ids: ids }, catalogs));
  };
  const cast = (state: any, spell_id: string, random = rng) => resolveCombatTurn(state, { turn: state.turn + 1, spell_id, target: "boss" }, random);
  const pierce = fixture("needle_etch"); pierce.boss.status.shield_pct = 0.5; pierce.boss.status.stun = 1;
  expect(cast(pierce, "needle_etch").next_state.boss.hp).toBe(104);
  const dispel = fixture("quicksilver_solvent", "mercury_01"); dispel.boss.status.shield_pct = 0.5; dispel.boss.status.stun = 1;
  expect(cast(dispel, "quicksilver_solvent").next_state.boss.hp).toBe(106);
  const leech = fixture("echo_siphon"); leech.player.hp = 80; leech.boss.status.stun = 1;
  expect(cast(leech, "echo_siphon").next_state.player.hp).toBe(81);
  const overkill = fixture("echo_siphon"); overkill.player.hp = 80; overkill.boss.hp = 1; overkill.boss.max_hp = 2;
  expect(cast(overkill, "echo_siphon").next_state.player.hp).toBe(80);
  const focus = fixture("quiet_focus"); focus.boss.status.stun = 1;
  const focused = cast(focus, "quiet_focus").next_state;
  expect(focused.player.status.focus_next).toBe(0.12);
  focused.boss.status.stun = 1;
  const focusMiss = cast(focused, "furnace_rush", () => 0.99);
  expect(focusMiss.next_state.player.status.focus_next).toBeUndefined();
  const focusEvent = focusMiss.events.findIndex((e: any) => e.kind === "status_consumed" && e.status === "focus_next" && e.target === "player");
  const missEvent = focusMiss.events.findIndex((e: any) => e.kind === "miss" && e.actor === "player");
  expect(focusEvent).toBeGreaterThanOrEqual(0);
  expect(missEvent).toBeGreaterThan(focusEvent);
  const misalign = fixture("quiet_focus"); misalign.boss.status.stun = 1; misalign.player.status.misalign_next = 0.1;
  const misalignHit = cast(misalign, "cinder_fist", () => 0);
  const consumedMisalign = misalignHit.events.findIndex((e: any) => e.kind === "status_consumed" && e.status === "misalign_next");
  const hitAfter = misalignHit.events.findIndex((e: any) => e.kind === "damage" && e.actor === "player");
  expect(consumedMisalign).toBeGreaterThanOrEqual(0);
  expect(hitAfter).toBeGreaterThan(consumedMisalign);
  const crooked = fixture("crooked_rune"); crooked.boss.status.stun = 1;
  expect(cast(crooked, "crooked_rune").next_state.boss.status.misalign_next).toBe(0.1);
  const misaligned = cast(fixture("crooked_rune"), "crooked_rune", (_turn, draw) => [0, 0.99, 0.84][draw % 3]);
  expect(misaligned.events.some((e: any) => e.actor === "boss" && e.kind === "damage")).toBe(true);
  expect(misaligned.next_state.boss.status.misalign_next).toBe(0.1);
  const tempo = fixture("second_measure"); tempo.boss.status.stun = 1;
  expect(cast(tempo, "second_measure").next_state.player.status.tempo_bonus).toBe(2);
  const recoil = fixture("last_axiom"); recoil.player.hp = 2; recoil.boss.status.stun = 1;
  expect(cast(recoil, "last_axiom").terminal_result).toBe("LOSS");
  const second = fixture("fluid_anchor", "mercury_01"); second.player.status.tempo_bonus = -2;
  const result = cast(second, "fluid_anchor");
  expect(result.events.find((e: any) => ["boss_action", "damage", "miss"].includes(e.kind)).actor).toBe("boss");
  expect(result.next_state.player.status.shield_pct).toBe(0.18);
  const first = fixture("fluid_anchor", "mercury_01"); first.boss.status.stun = 1;
  expect(cast(first, "fluid_anchor").next_state.player.status.shield_pct).toBe(0.08);
  const killed = fixture("fluid_anchor", "mercury_01"); killed.player.status.tempo_bonus = -2; killed.player.hp = 1;
  expect(cast(killed, "fluid_anchor").events.some((e: any) => e.actor === "player" && e.kind !== "status_consumed")).toBe(false);
  const toxic = fixture("toxic_mirror", "mercury_01");
  const reflected = cast(toxic, "toxic_mirror", rng);
  expect(reflected.events.some((e: any) => e.kind === "reflect")).toBe(true);
  expect(reflected.events.some((e: any) => e.kind === "status_applied" && e.status === "poison_on_reflect" && e.target === "player" && e.value === 1)).toBe(true);
  expect(reflected.next_state.boss.status.poison).toBe(0);
  expect(reflected.next_state.player.status.poison_on_reflect).toBeUndefined();
  const miss = fixture("toxic_mirror", "mercury_01"); miss.boss.status.stun = 1;
  const saved = cast(miss, "toxic_mirror", rng).next_state;
  expect(saved.player.status.poison_on_reflect).toBe(1);
  expect(saved.boss.status.poison ?? 0).toBe(0);
});

test("server Bismuth and Cinder progression applies without trusting client stats", () => {
  const selected = { ...selection, weapon_ids: ["bismuth_talisman", null], homunculus_id: "cinder" };
  const progress = { ...snapshot, item_progress: { bismuth_talisman: { level: 5 } }, homunculus_progress: { cinder: { level: 5 } } };
  const state = createCombatState(buildTrustedCombatSetup(progress, selected, catalogs));
  expect([state.player.hp, state.player.atk, state.player.def]).toEqual([109, 33, 13]);
  const base = createCombatState(buildTrustedCombatSetup(snapshot, selected, catalogs));
  expect([base.player.hp, base.player.atk, base.player.def]).toEqual([104, 27, 12]);
  state.boss.status.stun = 1;
  const before = structuredClone(state);
  const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "hold" }, rng);
  expect(result.error).toBeUndefined();
  expect(result.events.find((e: any) => e.kind === "true_damage").damage).toBe(1);
  expect(result.next_state.hom_energy).toBe(1);
  const ready = structuredClone(state); ready.hom_energy = 3;
  const hom = resolveCombatTurn(ready, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng);
  expect(hom.events.find((e: any) => e.kind === "hom_damage").damage).toBe(13);
  expect(hom.next_state.hom_energy).toBe(1);
  const stunned = structuredClone(ready); stunned.player.status.hom_stun = 1;
  const nullified = resolveCombatTurn(stunned, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng);
  expect(nullified.events.some((e: any) => e.kind === "hom_damage")).toBe(false);
  expect([nullified.next_state.player.status.hom_stun, nullified.next_state.hom_energy]).toEqual([0, 1]);
  ready.hom_energy = 6;
  expect(resolveCombatTurn(ready, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng).events.find((e: any) => e.kind === "hom_damage").damage).toBe(20);
  ready.hom_energy = 3; ready.player.hp = 50;
  const sacrificed = resolveCombatTurn(ready, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "sacrifice" }, rng).next_state;
  expect([sacrificed.player.hp, sacrificed.player.max_hp, sacrificed.player.atk, sacrificed.player.def, sacrificed.hom_spent]).toEqual([80, 104, 27, 12, true]);
  expect(state).toEqual(before);
  expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng)).toEqual({ error: "INVALID_DECISION" });
  let draws = 0;
  expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, () => { draws++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(draws).toBe(0);
  expect(buildTrustedCombatSetup(progress, { ...selected, weapon_ids: ["bismuth_talisman", "bismuth_talisman"] }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup({ ...progress, item_progress: { bismuth_talisman: { level: 5, specialization: "aggressive" } } }, selected, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("catalog homunculi and validated flat Forge traits use server progression", () => {
  const selected = { ...selection, weapon_ids: ["bismuth_talisman", null], homunculus_id: "cinder" };
  const progress = { ...snapshot, item_progress: { bismuth_talisman: { level: 5, specialization: "aggressive", traits: [{ id: "power_flat", points: 2 }, { id: "true_on_hit", points: 1 }, { id: "dot_true", points: 0 }] } }, homunculus_progress: { cinder: { level: 5, mutation_id: "vitality" } } };
  const enhanced = createCombatState(buildTrustedCombatSetup(progress, selected, catalogs));
  expect([enhanced.player.hp, enhanced.player.atk, enhanced.item_effects.true_on_hit]).toEqual([114, 35, 2]);
  enhanced.boss.status.stun = 1;
  expect(resolveCombatTurn(enhanced, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBe(86);
  const supported = structuredClone(progress); supported.item_progress.bismuth_talisman.specialization = "technical";
  supported.item_progress.bismuth_talisman.traits = [{ id: "guard_flat", points: 2 }, { id: "power_flat", points: 1 }, { id: "tempo_flat", points: 0 }];
  expect(buildTrustedCombatSetup(supported, selected, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  const vitality = { ...snapshot, homunculus_progress: { cinder: { level: 5, mutation_id: "vitality" } } };
  const state = createCombatState(buildTrustedCombatSetup(vitality, selected, catalogs));
  expect([state.player.hp, state.player.atk]).toEqual([114, 28]);
  const sodium = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, homunculus_id: "sodium" }, catalogs));
  expect(sodium.hom_id).toBe("sodium");
  sodium.boss.status.stun = 1;
  expect(resolveCombatTurn(sodium, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "hold" }, rng).next_state.hom_energy).toBe(1);
  const silphide = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, homunculus_id: "silphide" }, catalogs));
  silphide.boss.status.tempo_bonus = 1;
  expect(resolveCombatTurn(silphide, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).events.find((e: any) => ["boss_action", "damage", "miss"].includes(e.kind)).actor).toBe("player");
  const catalyst = { ...snapshot, homunculus_progress: { cinder: { level: 5, mutation_id: "catalyst" } } };
  expect(createCombatState(buildTrustedCombatSetup(catalyst, selected, catalogs)).player.atk).toBe(29);
  expect(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { cinder: { level: 99 } } }, selected, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("all 48 catalog entity and homunculus combinations resolve", () => {
  let count = 0;
  for (const entity of catalogs.entities) for (const hom of catalogs.homunculi) {
    const spells = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
    const state = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: entity.id, spell_ids: spells, homunculus_id: hom.id }, catalogs));
    expect(state.hom_id).toBe(hom.id);
    state.boss.status.stun = 1;
    const result = resolveCombatTurn(state, { turn: 1, spell_id: spells[0], target: "boss", hom_action: "hold" }, rng);
    expect(result.error).toBeUndefined();
    expect(result.next_state.hom_energy).toBe(1);
    count++;
  }
  expect(count).toBe(48);
});

test("homunculus levels and mutations are server-derived", () => {
  for (const hom of catalogs.homunculi) for (const level of [0, 5, 10]) for (const mutation_id of ["catalyst", "vitality", "resonance"]) {
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { [hom.id]: { level, mutation_id } } }, { ...selection, homunculus_id: hom.id }, catalogs));
    expect(state.player.max_hp).toBe(104 + hom.buff_hp + level + (mutation_id === "vitality" ? 5 : 0));
    expect(state.hom_advantage).toBeCloseTo(Math.min(0.5, (hom.per_type.sulfur.type_adv_bonus ?? 0) + (mutation_id === "resonance" ? 0.03 : 0)));
    state.boss.status.stun = 1;
    expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).error).toBeUndefined();
  }
  expect(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { cinder: { mutation_id: "forged" } } }, { ...selection, homunculus_id: "cinder" }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("synergy damage, neutralization, corrosion and incoming reduction", () => {
  const fixture = (entity_id: string, homunculus_id: string, boss_entity_id: string, mutation_id?: string) => {
    const entity = catalogs.entities.find((e: any) => e.id === entity_id);
    const spell_ids = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
    const homunculus_progress = mutation_id ? { [homunculus_id]: { mutation_id } } : {};
    return createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id, homunculus_progress }, { ...selection, entity_id, spell_ids, homunculus_id }, catalogs));
  };
  const drakon = fixture("sulfur_01", "drakon", "vitriol_01", "resonance");
  drakon.boss.status.stun = 1;
  const d = resolveCombatTurn(drakon, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng);
  expect(d.events.find((e: any) => e.kind === "damage").damage).toBe(19);
  expect(drakon.hom_advantage).toBeCloseTo(0.08);
  const unfavorable = fixture("sulfur_01", "drakon", "sodium_01", "resonance"); unfavorable.boss.status.stun = 1;
  const withoutBonus = structuredClone(unfavorable); withoutBonus.hom_advantage = 0;
  expect(resolveCombatTurn(unfavorable, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBe(resolveCombatTurn(withoutBonus, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp);
  const universalIds = ["steady_script", "furnace_rush", "ash_temper", "brimstone_crash"];
  const spell_progress = { learned_by_entity: { sulfur_01: ["steady_script"] }, equipped_by_mode: { attack: { sulfur_01: universalIds } } };
  const universal = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: "vitriol_01", spell_progress, homunculus_progress: { drakon: { mutation_id: "resonance" } } }, { ...selection, spell_ids: universalIds, homunculus_id: "drakon" }, catalogs));
  universal.boss.status.stun = 1;
  expect(resolveCombatTurn(universal, { turn: 1, spell_id: "steady_script", target: "boss" }, rng).events.find((e: any) => e.kind === "damage").damage).toBe(14);
  const hybridIds = ["golden_crucible", "furnace_rush", "ash_temper", "brimstone_crash"];
  const hybridProgress = { learned_by_entity: { sulfur_01: ["golden_crucible"] }, equipped_by_mode: { attack: { sulfur_01: hybridIds } } };
  const hybrid = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: "aether_01", spell_progress: hybridProgress, homunculus_progress: { drakon: { mutation_id: "resonance" } } }, { ...selection, spell_ids: hybridIds, homunculus_id: "drakon" }, catalogs));
  hybrid.boss.status.stun = 1;
  expect(resolveCombatTurn(hybrid, { turn: 1, spell_id: "golden_crucible", target: "boss" }, rng).events.find((e: any) => e.kind === "damage").damage).toBe(20);
  const mothy = fixture("sulfur_01", "mothy", "sodium_01"); mothy.player.spell_neutralize_pending = 0.5; mothy.boss.status.stun = 1;
  const m = resolveCombatTurn(mothy, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng);
  expect(m.events.find((e: any) => e.kind === "damage").damage).toBe(14);
  const pyritc = fixture("vitriol_01", "pyritc", "sodium_01"); pyritc.boss.status.stun = 1;
  const p = resolveCombatTurn(pyritc, { turn: 1, spell_id: "etching_fang", target: "boss" }, rng);
  expect(p.events.find((e: any) => e.kind === "hom_corrosion")).toMatchObject({ target: "boss", damage: 3, actual_damage: 3, hp: p.next_state.boss.hp });
  const partial = structuredClone(pyritc); partial.boss.hp = p.events.find((e: any) => e.kind === "damage" && e.actor === "player").actual_damage + 2;
  expect(resolveCombatTurn(partial, { turn: 1, spell_id: "etching_fang", target: "boss" }, rng).events.find((e: any) => e.kind === "hom_corrosion")).toMatchObject({ target: "boss", damage: 3, actual_damage: 2, hp: 0 });
  const lethal = structuredClone(pyritc); lethal.boss.hp = 1;
  expect(resolveCombatTurn(lethal, { turn: 1, spell_id: "etching_fang", target: "boss" }, rng).events.find((e: any) => e.kind === "hom_corrosion")).toMatchObject({ target: "boss", damage: 3, actual_damage: 0, hp: 0 });
  const guarded = structuredClone(pyritc);
  guarded.minions = [{ id: "minion_0", hp: 2, max_hp: 20, atk: 1, def: 0, type: "", status: {} }, { id: "minion_1", hp: 20, max_hp: 20, atk: 1, def: 0, type: "", status: { stun: 1 } }];
  guarded.summoned = true;
  const minionHit = resolveCombatTurn(guarded, { turn: 1, spell_id: "etching_fang", target: "minion_0" }, rng);
  expect(minionHit.events.find((e: any) => e.kind === "hom_corrosion")).toMatchObject({ target: "minion_0", damage: 3, actual_damage: 0, hp: 0 });
  expect(minionHit.next_state.minions[1].hp).toBe(20);
  expect(resolveCombatTurn(pyritc, { turn: 1, spell_id: "etching_fang", target: "boss" }, () => 0.99).events.some((e: any) => e.kind === "hom_corrosion")).toBe(false);
  const silk = fixture("sodium_01", "silphide", "sodium_01");
  const reduced = resolveCombatTurn(silk, { turn: 1, spell_id: "salt_barrier", target: "boss" }, (_t, i) => [0, 0, 0.99][i % 3]);
  expect(reduced.next_state.player.hp).toBe(107);
});

test("Nighty scaling and Chimera reflection are removed safely on sacrifice", () => {
  const weapons = ["bismuth_talisman", "wind_amulet"];
  const item_progress = { bismuth_talisman: { level: 5, fusion: { donor_id: "wind_amulet" } }, wind_amulet: { level: 3 } };
  const night = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress }, { ...selection, weapon_ids: weapons, homunculus_id: "nighty" }, catalogs));
  expect(night.item_effects.power_flat).toBeCloseTo(6.3);
  expect(night.item_effects.evasion_pct).toBeCloseTo(0.021);
  night.hom_energy = 3; night.boss.status.stun = 1;
  const sacrificed = resolveCombatTurn(night, { turn: 1, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect(sacrificed.item_effects.tempo_flat).toBe(4);
  expect(sacrificed.hom_spent).toBe(true);
  sacrificed.boss.status.stun = 1;
  const back = resolveCombatTurn(sacrificed, { turn: 2, switch_slot: 1 }, rng).next_state;
  expect(back.item_effects.power_flat).toBe(6);
  expect(back.item_effects.evasion_pct).toBe(0.02);
  const chimera = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["mirror_sigel", "bismuth_talisman"], homunculus_id: "chimera" }, catalogs));
  chimera.hom_energy = 3; chimera.boss.status.stun = 1;
  const active = resolveCombatTurn(chimera, { turn: 1, spell_id: "ash_temper", target: "boss" }, rng).next_state;
  expect(active.player.status.reflect_pct).toBe(0.02);
  active.boss.status.stun = 1;
  const removed = resolveCombatTurn(active, { turn: 2, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect(removed.player.status.reflect_pct ?? 0).toBe(0);
  const ids = ["reverse_quill", "furnace_rush", "ash_temper", "brimstone_crash"];
  const spell_progress = { learned_by_entity: { sulfur_01: ["reverse_quill"] }, equipped_by_mode: { attack: { sulfur_01: ids } } };
  const combined = createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress }, { ...selection, spell_ids: ids, weapon_ids: ["mirror_sigel", "bismuth_talisman"], homunculus_id: "chimera" }, catalogs));
  combined.hom_energy = 3; combined.boss.status.stun = 1;
  const defended = resolveCombatTurn(combined, { turn: 1, spell_id: "reverse_quill", target: "boss" }, rng).next_state;
  expect(defended.player.status.reflect_pct).toBe(0.13);
  defended.boss.status.stun = 1;
  const preserved = resolveCombatTurn(defended, { turn: 2, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect(preserved.player.status.reflect_pct).toBe(0.13);
});

test("all eight catalog weapons resolve at Forge levels 0, 5 and 10", () => {
  for (const item of catalogs.items) for (const level of [0, 5, 10]) {
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [item.id]: { level } } }, { ...selection, weapon_ids: [item.id, null] }, catalogs));
    expect(state.item_id).toBe(item.id);
    for (const [key, values] of Object.entries(item.effects) as [string, number[]][]) {
      const expected = level === 0 && values.length === 10 && key in (item.base_effects ?? {}) ? item.base_effects[key] : values[Math.min(values.length - 1, Math.max(0, level - 1))];
      expect(state.item_effects[key]).toBe(expected);
    }
    state.boss.status.stun = 1;
    expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBeLessThan(112);
  }
});

test("Forge paths and all donor imprints derive from official balance", () => {
  for (const path of ["aggressive", "defensive", "technical"]) {
    const pool = catalogs.balance.forge_trait_pool[path];
    const traits = Object.keys(pool).slice(0, 3).map((id, i) => ({ id, points: i === 0 ? 2 : 0 }));
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { bismuth_talisman: { level: 5, specialization: path, traits } } }, { ...selection, weapon_ids: ["bismuth_talisman", null] }, catalogs));
    const base = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { bismuth_talisman: { level: 5 } } }, { ...selection, weapon_ids: ["bismuth_talisman", null] }, catalogs));
    expect(state.item_effects[traits[0].id]).toBe((base.item_effects[traits[0].id] ?? 0) + pool[traits[0].id] * 2);
    state.boss.status.stun = 1;
    expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBeLessThan(112);
  }
  for (const donor of catalogs.items) {
    const target = donor.id === "bismuth_talisman" ? "wind_amulet" : "bismuth_talisman";
    const base = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [target]: { level: 3 } } }, { ...selection, weapon_ids: [target, null] }, catalogs));
    const fused = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [target]: { level: 3, fusion: { donor_id: donor.id } }, [donor.id]: { level: 3 } } }, { ...selection, weapon_ids: [target, null] }, catalogs));
    const [key, amount] = Object.entries(catalogs.balance.forge_fusion_imprints[donor.id])[0] as [string, number];
    expect(fused.item_effects[key]).toBeCloseTo((base.item_effects[key] ?? 0) + amount);
  }
});

test("weapon evasion, ward, corrosion and reflection prevention activate", () => {
  const fixture = (id: string, level = 0) => createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [id]: { level } } }, { ...selection, weapon_ids: [id, null] }, catalogs));
  const action = (spell_id: string) => ({ turn: 1, spell_id, target: "boss" });
  const dodge = resolveCombatTurn(fixture("wind_amulet"), action("ash_temper"), () => 0);
  expect(dodge.next_state.player.hp).toBe(104);
  expect(dodge.events.some((event: any) => event.kind === "evade")).toBe(true);
  const ward = fixture("saltstone_charm"); ward.boss.status.stun = 1;
  expect(resolveCombatTurn(ward, action("ash_temper"), rng).next_state.player.status.shield_pct).toBe(0.12);
  const mirror = fixture("mirror_sigel", 5); mirror.boss.status.stun = 1;
  const guarded = resolveCombatTurn(mirror, action("ash_temper"), rng).next_state;
  expect([guarded.player.status.shield_pct, guarded.player.status.reflect_pct]).toEqual([0.08, 0.07]);
  const returned = resolveCombatTurn(guarded, { turn: 2, spell_id: "cinder_fist", target: "boss" }, rng);
  expect(returned.events.find((event: any) => event.kind === "reflect").damage).toBe(1);
  expect(returned.next_state.player.status.reflect_pct).toBeUndefined();
  const corrosion = fixture("vitriol_vial", 5); corrosion.boss.status.stun = 1;
  const corroded = resolveCombatTurn(corrosion, action("cinder_fist"), rng);
  expect(corroded.events.find((event: any) => event.kind === "corrosion").damage).toBe(3);
  expect(corroded.next_state.boss.status.vuln_pct).toBe(0.1);
  const protectedPlayer = fixture("aether_knot", 10); protectedPlayer.boss.status.reflect_pct = 1; protectedPlayer.boss.status.stun = 1;
  const ignored = resolveCombatTurn(protectedPlayer, action("cinder_fist"), () => 0);
  expect(ignored.next_state.player.hp).toBe(104);
  const suffered = resolveCombatTurn(protectedPlayer, action("cinder_fist"), (_turn, draw) => [0, 0.99, 0.99][draw % 3]);
  expect(suffered.next_state.player.hp).toBeLessThan(104);
});

test("both slots validate and each weapon switches into real combat at every Forge level", () => {
  for (const item of catalogs.items) for (const level of [0, 5, 10]) {
    const other = item.id === "bismuth_talisman" ? "wind_amulet" : "bismuth_talisman";
    for (const ids of [[item.id, other], [other, item.id]]) {
      const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [item.id]: { level } } }, { ...selection, weapon_ids: ids }, catalogs));
      expect(state.weapons[ids.indexOf(item.id)].id).toBe(item.id);
      for (const [key, values] of Object.entries(item.effects) as [string, number[]][]) {
        const expected = level === 0 && values.length === 10 && key in (item.base_effects ?? {}) ? item.base_effects[key] : values[Math.min(values.length - 1, Math.max(0, level - 1))];
        expect(state.weapons[ids.indexOf(item.id)].effects[key]).toBe(expected);
      }
      state.boss.status.stun = 1;
      const destination = ids.indexOf(item.id) + 1;
      const initial = destination === 1 ? 2 : 1;
      if (destination === 1) {
        const swapped = resolveCombatTurn(state, { turn: 1, switch_slot: initial }, rng);
        expect(swapped.next_state.active_weapon_slot).toBe(2);
        swapped.next_state.boss.status.stun = 1;
        const returned = resolveCombatTurn(swapped.next_state, { turn: 2, switch_slot: destination }, rng);
        expect(returned.next_state.item_id).toBe(item.id);
      } else {
        const switched = resolveCombatTurn(state, { turn: 1, switch_slot: destination }, rng);
        expect(switched.next_state.item_id).toBe(item.id);
      }
    }
    const onlySecond = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [item.id]: { level } } }, { ...selection, weapon_ids: [null, item.id] }, catalogs));
    expect([onlySecond.active_weapon_slot, onlySecond.item_id]).toEqual([2, item.id]);
  }
});

test("switch consumes action, preserves independent defenses and recalculates stats", () => {
  const state = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["bismuth_talisman", "mirror_sigel"] }, catalogs));
  expect([state.player.hp, state.player.atk, state.player.def, state.active_weapon_slot]).toEqual([104, 22, 12, 1]);
  state.cooldowns.ash_temper = 2;
  state.boss.status.stun = 1;
  const switched = resolveCombatTurn(state, { turn: 1, switch_slot: 2 }, rng);
  expect([switched.next_state.player.hp, switched.next_state.player.atk, switched.next_state.player.def, switched.next_state.active_weapon_slot, switched.next_state.cooldowns.ash_temper]).toEqual([104, 21, 12, 2, 1]);
  expect(switched.events.some((event: any) => event.kind === "switch")).toBe(true);
  expect(switched.next_state.player.status.shield_pct).toBe(0.08);
  const next = switched.next_state;
  next.other_defenses.shield_pct = 0.05;
  next.other_defenses.reflect_pct = 0.01;
  next.player.status.poison = 1;
  next.boss.status.stun = 1;
  const back = resolveCombatTurn(next, { turn: 2, switch_slot: 1 }, rng);
  expect([back.next_state.player.atk, back.next_state.player.def, back.next_state.player.status.shield_pct, back.next_state.player.status.reflect_pct]).toEqual([22, 12, 0.05, 0.01]);
  expect(back.next_state.player.hp).toBe(102);
  expect(resolveCombatTurn(next, { turn: 2, switch_slot: 1 }, rng)).toEqual(back);
  let draws = 0;
  expect(resolveCombatTurn(state, { turn: 1, switch_slot: 2, spell_id: "cinder_fist" }, () => { draws++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(draws).toBe(0);
  expect(resolveCombatTurn(state, { turn: 1, switch_slot: 1 }, rng)).toEqual({ error: "INVALID_DECISION" });
  expect(resolveCombatTurn(state, { turn: 1, switch_slot: 3 }, rng)).toEqual({ error: "INVALID_DECISION" });
  const stunned = structuredClone(state); stunned.player.status.stun = 1;
  expect(resolveCombatTurn(stunned, { turn: 1, switch_slot: 2 }, rng).next_state.active_weapon_slot).toBe(1);
  const defeated = structuredClone(state); defeated.player.hp = 1; defeated.boss.status.stun = 0; defeated.boss.status.tempo_bonus = 100;
  const killed = resolveCombatTurn(defeated, { turn: 1, switch_slot: 2 }, () => 0);
  expect([killed.terminal_result, killed.next_state.active_weapon_slot]).toEqual(["LOSS", 1]);
  const activeBoss = structuredClone(state); activeBoss.boss.status.stun = 0;
  const bossTurn = resolveCombatTurn(activeBoss, { turn: 1, switch_slot: 2 }, rng);
  expect(bossTurn.events.some((event: any) => event.actor === "player" && event.kind === "damage")).toBe(false);
  expect(bossTurn.events.some((event: any) => event.actor === "boss" && event.kind === "damage")).toBe(true);
  const sodium = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: "sodium_01", spell_ids: ["crystal_ram", "salt_barrier", "brine_mend", "bastion_return"], weapon_ids: ["mirror_sigel", "bismuth_talisman"] }, catalogs));
  sodium.boss.status.stun = 1;
  const protectedState = resolveCombatTurn(sodium, { turn: 1, spell_id: "salt_barrier", target: "boss" }, rng).next_state;
  expect([protectedState.player.status.shield_pct, protectedState.weapon_defenses.shield_pct, protectedState.other_defenses.shield_pct]).toEqual([0.24, 0.08, 0.24]);
  protectedState.boss.status.stun = 1;
  const preserved = resolveCombatTurn(protectedState, { turn: 2, switch_slot: 2 }, rng).next_state;
  expect(preserved.player.status.shield_pct).toBe(0.24);
  const withoutTempo = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["bismuth_talisman", "wind_amulet"] }, catalogs));
  const withTempo = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["wind_amulet", "bismuth_talisman"] }, catalogs));
  withoutTempo.boss.status.tempo_bonus = 1; withTempo.boss.status.tempo_bonus = 1;
  expect(resolveCombatTurn(withoutTempo, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).events.find((e: any) => ["boss_action", "damage", "miss"].includes(e.kind)).actor).toBe("boss");
  expect(resolveCombatTurn(withTempo, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).events.find((e: any) => ["boss_action", "damage", "miss"].includes(e.kind)).actor).toBe("player");
});

test("each slot retains its own Forge traits and fusion through switching", () => {
  const item_progress = {
    bismuth_talisman: { level: 5, specialization: "aggressive", traits: [{ id: "power_flat", points: 2 }, { id: "true_on_hit", points: 1 }, { id: "dot_true", points: 0 }], fusion: { donor_id: "wind_amulet" } },
    wind_amulet: { level: 5, specialization: "defensive", traits: [{ id: "guard_flat", points: 2 }, { id: "ward_pct", points: 1 }, { id: "reflect_pct", points: 0 }], fusion: { donor_id: "mirror_sigel" } },
    mirror_sigel: { level: 3 },
  };
  const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress }, { ...selection, weapon_ids: ["bismuth_talisman", "wind_amulet"] }, catalogs));
  expect([state.player.atk, state.item_effects.true_on_hit, state.item_effects.evasion_pct]).toEqual([29, 2, 0.02]);
  expect(state.item_effects.ward_pct).toBeUndefined();
  state.boss.status.stun = 1;
  const switched = resolveCombatTurn(state, { turn: 1, switch_slot: 2 }, rng).next_state;
  expect([switched.player.atk, switched.player.def, switched.item_effects.ward_pct, switched.item_effects.reflect_pct]).toEqual([22, 13, 0.02, 0.02]);
  expect(switched.item_effects.true_on_hit).toBeUndefined();
  expect(switched.player.status.shield_pct).toBe(0.02);
});

test("switch and sacrifice preserve recalculated stats on subsequent switches", () => {
  const selected = { ...selection, weapon_ids: ["bismuth_talisman", "mirror_sigel"], homunculus_id: "cinder" };
  const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { cinder: { level: 5 } } }, selected, catalogs));
  state.hom_energy = 3; state.player.hp = 50; state.boss.status.stun = 1;
  const switched = resolveCombatTurn(state, { turn: 1, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect([switched.player.hp, switched.player.max_hp, switched.player.atk, switched.player.def, switched.hom_spent]).toEqual([80, 104, 21, 12, true]);
  switched.boss.status.stun = 1;
  const back = resolveCombatTurn(switched, { turn: 2, switch_slot: 1 }, rng).next_state;
  expect([back.player.hp, back.player.atk, back.player.def, back.hom_spent]).toEqual([80, 22, 12, true]);
});

test("marks are owned, expire on actions and are consumed on hybrid hit", () => {
  const ids = ["paradox_edict", "gilded_exception", "rift_touch", "paradox_fold"];
  const progress = { learned_by_entity: { aether_01: ids.slice(0, 2) }, equipped_by_mode: { attack: { aether_01: ids } } };
  const make = () => createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: "aether_01", spell_ids: ids }, catalogs));
  const state = make(); state.boss.status.stun = 1;
  const markedResult = resolveCombatTurn(state, { turn: 1, spell_id: "paradox_edict", target: "boss" }, rng);
  expect(markedResult.events.some((e: any) => e.kind === "status_applied" && e.status === "hybrid_mark" && e.target === "boss" && e.value.remaining === 2)).toBe(true);
  const marked = markedResult.next_state;
  expect(marked.boss.status.hybrid_mark).toEqual({ owner: "player", remaining: 2 });
  marked.boss.status.stun = 1;
  const consumedResult = resolveCombatTurn(marked, { turn: 2, spell_id: "gilded_exception", target: "boss" }, rng);
  expect(consumedResult.events.some((e: any) => e.kind === "status_consumed" && e.status === "hybrid_mark" && e.target === "boss")).toBe(true);
  const consumed = consumedResult.next_state;
  expect(consumed.boss.status.hybrid_mark).toBeUndefined();
  const foreign = make(); foreign.boss.status.stun = 1; foreign.boss.status.hybrid_mark = { owner: "enemy", remaining: 2 };
  const other = resolveCombatTurn(foreign, { turn: 1, spell_id: "gilded_exception", target: "boss" }, rng).next_state;
  expect(other.boss.status.hybrid_mark).toEqual({ owner: "enemy", remaining: 2 });
  const expiring = make(); expiring.boss.status.stun = 1; expiring.boss.status.hybrid_mark = { owner: "player", remaining: 1 };
  const expired = resolveCombatTurn(expiring, { turn: 1, spell_id: "rift_touch", target: "boss" }, rng).next_state;
  expect(expired.boss.status.hybrid_mark).toBeUndefined();
});

test("inspiration status triggers, three offers and temporary spell lifecycle", () => {
  const build = (spellId: string) => {
    const spell = catalogs.spells.find((s: any) => s.id === spellId);
    const entity = catalogs.entities.find((e: any) => e.type === spell.type || spell.eligible_types?.includes(e.type));
    const defaults = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
    const ids = [spell.id, ...defaults.filter((id: string) => id !== spell.id).slice(0, 3)];
    const progress = { learned_by_entity: { [entity.id]: [spell.id] }, equipped_by_mode: { attack: { [entity.id]: ids } } };
    return createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: entity.id, spell_ids: ids }, catalogs));
  };
  for (const id of ["brimstone_crash", "veil_rupture", "caustic_mark", "mercury_snare", "crooked_rune", "salt_circuit", "paradox_edict"]) {
    const state = build(id); state.boss.status.stun = 1;
    const result = resolveCombatTurn(state, { turn: 1, spell_id: id, target: "boss" }, rng);
    expect(result.next_state.player.inspiration).toBe(1);
  }
  const equal = build("caustic_mark"); equal.boss.status.stun = 1; equal.boss.status.poison = 2;
  expect(resolveCombatTurn(equal, { turn: 1, spell_id: "caustic_mark", target: "boss" }, rng).next_state.player.inspiration).toBe(0);
  const self = build("furnace_rush"); self.boss.status.stun = 1;
  expect(resolveCombatTurn(self, { turn: 1, spell_id: "furnace_rush", target: "boss" }, rng).next_state.player.inspiration).toBe(0);
  const miss = build("brimstone_crash"); miss.boss.status.stun = 1;
  expect(resolveCombatTurn(miss, { turn: 1, spell_id: "brimstone_crash", target: "boss" }, () => 0.99).next_state.player.inspiration).toBe(0);
  let accumulated = build("brimstone_crash"); accumulated.boss.hp = 10000; accumulated.boss.max_hp = 10000;
  for (const [index, id] of ["brimstone_crash", "cinder_fist", "cinder_fist", "brimstone_crash", "cinder_fist", "cinder_fist", "brimstone_crash"].entries()) {
    const result = resolveCombatTurn(accumulated, { turn: index + 1, spell_id: id, target: "boss" }, rng);
    expect(result.error).toBeUndefined();
    accumulated = result.next_state;
    if ([0, 3, 6].includes(index)) expect(accumulated.player.inspiration).toBe([0, 3, 6].indexOf(index) + 1);
  }
  expect(accumulated.player.inspiration_pending).toBe(true);
  const state = build("brimstone_crash"); state.player.inspiration = 2; state.boss.status.stun = 1;
  const before = structuredClone(state);
  const turn = { turn: 1, spell_id: "brimstone_crash", target: "boss" };
  const offered = resolveCombatTurn(state, turn, rng).next_state;
  expect(state).toEqual(before);
  expect(offered.player.inspiration).toBe(3);
  expect(offered.rng_counter).toBe(5);
  expect(new Set(offered.inspiration_offers).size).toBe(3);
  for (const id of offered.inspiration_offers) {
    const s = offered.inspiration_catalog.find((entry: any) => entry.id === id);
    expect(s.type === "sulfur" || (s.type === "hybrid" && s.primary_type === "sulfur")).toBe(true);
    expect(offered.spell_ids.includes(id)).toBe(false);
    const candidate = resolveInspirationDecision(offered, { kind: "choose", spell_id: id }, () => 0).next_state;
    candidate.boss.status.stun = 1;
    expect(resolveCombatTurn(candidate, { turn: 2, spell_id: id, target: "boss" }, rng).error).toBeUndefined();
  }
  expect(resolveCombatTurn(offered, { turn: 2, spell_id: offered.spell_ids[0], target: "boss" }, rng)).toEqual({ error: "INVALID_DECISION" });
  let attempts = 0;
  expect(resolveInspirationDecision(offered, { kind: "choose", spell_id: "forged" }, () => { attempts++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(attempts).toBe(0);
  const chosen = resolveInspirationDecision(offered, { kind: "choose", spell_id: offered.inspiration_offers[0] }, () => 0.3).next_state;
  expect(resolveInspirationDecision(offered, { kind: "choose", spell_id: offered.inspiration_offers[0] }, () => 0.3).next_state).toEqual(chosen);
  expect([chosen.turn, chosen.temporary_replaced_slot, chosen.player.inspiration_used_this_battle]).toEqual([1, 1, true]);
  expect(chosen.rng_counter).toBe(6);
  expect(chosen.spell_ids[1]).toBe(chosen.temporary_spell_id);
  chosen.boss.status.stun = 1;
  const cast = resolveCombatTurn(chosen, { turn: 2, spell_id: chosen.temporary_spell_id, target: "boss" }, rng);
  expect(cast.error).toBeUndefined();
  expect(cast.next_state.boss.hp).toBeLessThan(chosen.boss.hp);
  expect(cast.next_state.player.inspiration).toBe(3);
  expect(resolveInspirationDecision(chosen, { kind: "decline" }, rng)).toEqual({ error: "INVALID_DECISION" });
  const withCooldown = structuredClone(chosen); withCooldown.cooldowns[chosen.temporary_spell_id] = 2; withCooldown.cooldowns.ash_temper = 1;
  const restored = restoreInspiration(withCooldown);
  expect(restored.spell_ids).toEqual(state.spell_ids);
  expect(restored.temporary_spell_id).toBeNull();
  expect(restored.cooldowns[chosen.temporary_spell_id]).toBeUndefined();
  expect(restored.cooldowns.ash_temper).toBe(1);
  const winning = structuredClone(chosen); winning.boss.hp = 1; winning.boss.max_hp = 2;
  const win = resolveCombatTurn(winning, { turn: 2, spell_id: winning.temporary_spell_id, target: "boss" }, () => 0.1);
  expect(win.terminal_result).toBe("WIN");
  expect(win.next_state.spell_ids).toEqual(state.spell_ids);
  expect(win.next_state.temporary_spell_id).toBeNull();
  const losing = structuredClone(chosen); losing.player.hp = 1; losing.boss.status.tempo_bonus = 100; losing.boss.status.stun = 0;
  const loss = resolveCombatTurn(losing, { turn: 2, spell_id: losing.temporary_spell_id, target: "boss" }, () => 0.1);
  expect(loss.terminal_result).toBe("LOSS");
  expect(loss.next_state.spell_ids).toEqual(state.spell_ids);
  const declined = resolveInspirationDecision(offered, { kind: "decline" }, rng).next_state;
  expect(declined.rng_counter).toBe(offered.rng_counter);
  expect(declined.spell_ids).toEqual(state.spell_ids);
  expect([declined.player.inspiration, declined.player.inspiration_used_this_battle]).toEqual([0, true]);
  expect(resolveCombatTurn(state, { ...turn, ultra: true }, rng)).toEqual({ error: "INVALID_DECISION" });
});

test("inspiration setup requires three distinct valid eligible candidates", () => {
  const defaults = catalogs.spells.filter((s: any) => s.type === "sulfur");
  const signature = catalogs.spells.find((s: any) => s.id === "silver_needle");
  const candidates = catalogs.spells.filter((s: any) => s.type === "hybrid" && s.primary_type === "sulfur" && s.eligible_types.includes("sulfur")).slice(0, 3);
  const minimal = { ...catalogs, spells: structuredClone([...defaults, signature, ...candidates]) };
  const original = structuredClone(minimal);
  const accepted = buildTrustedCombatSetup(snapshot, selection, minimal);
  expect(accepted.error).toBeUndefined();
  const state = createCombatState(accepted); state.player.inspiration = 2; state.boss.status.stun = 1;
  const offered = resolveCombatTurn(state, { turn: 1, spell_id: "brimstone_crash", target: "boss" }, rng).next_state;
  expect(new Set(offered.inspiration_offers)).toEqual(new Set(candidates.map((spell: any) => spell.id)));
  expect(minimal).toEqual(original);
  const noThird = { ...minimal, spells: [...defaults, signature, candidates[0], candidates[1], candidates[1]] };
  expect(buildTrustedCombatSetup(snapshot, selection, noThird)).toEqual({ error: "UNSUPPORTED_MECHANIC" });
  const ineligible = structuredClone(minimal); ineligible.spells[ineligible.spells.length - 1].eligible_types = ["gold"];
  expect(buildTrustedCombatSetup(snapshot, selection, ineligible)).toEqual({ error: "UNSUPPORTED_MECHANIC" });
  const invalid = structuredClone(minimal); invalid.spells[invalid.spells.length - 1].effects = [{ kind: "not_supported", value: 1, target: "enemy" }];
  expect(buildTrustedCombatSetup(snapshot, selection, invalid)).toEqual({ error: "UNSUPPORTED_MECHANIC" });
  const invalidNumber = structuredClone(minimal); invalidNumber.spells[invalidNumber.spells.length - 1].accuracy = 2;
  expect(buildTrustedCombatSetup(snapshot, selection, invalidNumber)).toEqual({ error: "UNSUPPORTED_MECHANIC" });
});
