import { createHmac } from "node:crypto";

// B4.2B must persist server-validated entity, two weapon IDs, homunculus,
// four equipped/learned spell IDs, progression revision and boss snapshot.
// The B4.1 UNVERIFIED local seal is never a TrustedCombatSetup.
export type TrustedCombatSetup = {
  selection_authority: "SERVER_VALIDATED";
  player_id: string;
  progression_revision: number;
  entity_id: string;
  weapon_ids: [string, string | null];
  homunculus_id: string;
  spell_ids: [string, string, string, string];
  boss_id: string;
};

export const PARITY_GAPS = [
  "Authoritative selection persistence, catalog validation and progression-derived fighter stats",
  "All spell effects, accuracy, type modifiers, cooldowns and status timing",
  "Weapon passives, forge progression, homunculus mutations and sacrifice",
  "Boss intent, minions, shields, initiative, power turn, fury and terminal outcomes",
  "Atomic persistence, turn sequencing, private seed storage and server-only settlement",
] as const;

export type CombatError = { error: "UNTRUSTED_SETUP" | "UNSUPPORTED_MECHANIC" | "INVALID_DECISION" };

// Stateless draws: the caller stores the private seed and committed draw counter.
export function deterministicDraw(secret: Uint8Array, sessionId: string, turn: number, draw: number): number {
  if (secret.length < 32 || !sessionId || !Number.isSafeInteger(turn) || turn < 0 || !Number.isSafeInteger(draw) || draw < 0) throw new Error("Invalid server RNG input");
  const message = JSON.stringify(["solo-hunt-v1", sessionId, turn, draw]);
  return createHmac("sha256", secret).update(message).digest().readUInt32BE(0) / 0x100000000;
}

export function createCombatState(setup: unknown): CombatError {
  if (!setup || typeof setup !== "object" || Array.isArray(setup)) return { error: "UNTRUSTED_SETUP" };
  const s = setup as Partial<TrustedCombatSetup>;
  const id = (value: unknown) => typeof value === "string" && /^[a-z0-9_]{1,64}$/.test(value);
  if (s.selection_authority !== "SERVER_VALIDATED" || typeof s.player_id !== "string" || s.player_id.length < 1 || s.player_id.length > 128 || !Number.isSafeInteger(s.progression_revision) || s.progression_revision! < 0 || !id(s.entity_id) || !id(s.homunculus_id) || !id(s.boss_id) || !Array.isArray(s.weapon_ids) || s.weapon_ids.length !== 2 || !id(s.weapon_ids[0]) || (s.weapon_ids[1] !== null && (!id(s.weapon_ids[1]) || s.weapon_ids[0] === s.weapon_ids[1])) || !Array.isArray(s.spell_ids) || s.spell_ids.length !== 4 || !s.spell_ids.every(id) || new Set(s.spell_ids).size !== 4) return { error: "UNTRUSTED_SETUP" };
  // A marker alone cannot prove catalog ownership or selection provenance.
  return { error: "UNSUPPORTED_MECHANIC" };
}

export function resolveCombatTurn(_state: unknown, _decision: unknown): CombatError {
  // No authoritative state can exist until the parity gaps above are closed.
  return { error: "UNSUPPORTED_MECHANIC" };
}
