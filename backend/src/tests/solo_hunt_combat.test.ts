import { expect, test } from "bun:test";
import { createCombatState, deterministicDraw, PARITY_GAPS, resolveCombatTurn } from "../solo_hunt_combat";

test("incomplete snapshots and fabricated selections cannot create verified combat", () => {
  expect(createCombatState({ item_progress: {}, loadout_verification: "UNVERIFIED" })).toEqual({ error: "UNTRUSTED_SETUP" });
  const setup = { selection_authority: "SERVER_VALIDATED", player_id: "player", progression_revision: 0, entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], boss_id: "hunt_common" };
  expect(createCombatState(setup)).toEqual({ error: "UNSUPPORTED_MECHANIC" });
  expect(createCombatState({ ...setup, spell_ids: ["cinder_fist", "cinder_fist", "ash_temper", "brimstone_crash"] })).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(PARITY_GAPS.length).toBeGreaterThan(0);
});

test("unsupported turns cannot mutate state or consume random draws", () => {
  const state = { turn: 1, hp: 100, cooldowns: { spell: 2 } };
  const before = structuredClone(state);
  expect(resolveCombatTurn(state, { turn: 1, action: "spell" })).toEqual({ error: "UNSUPPORTED_MECHANIC" });
  expect(state).toEqual(before);
  const secret = new Uint8Array(32).fill(42);
  const draw = deterministicDraw(secret, "session", 1, 0);
  expect(draw).toBe(deterministicDraw(secret, "session", 1, 0));
  expect(draw).not.toBe(deterministicDraw(secret, "session", 1, 1));
  expect(() => deterministicDraw(new Uint8Array(4), "session", 1, 0)).toThrow();
});
