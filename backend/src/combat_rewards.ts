import { Database } from "bun:sqlite";
import { randomInt, randomUUID } from "node:crypto";

export type VerifiedStatus = "VERIFIED_WIN" | "VERIFIED_LOSS" | "INVALID";
export type CombatReward = { resource_id: "arcane_shard" | "time_crystal" | "primordial_sigil"; amount: 1 } | null;
const rewardIds = ["arcane_shard", "time_crystal", "primordial_sigil"] as const;

export class CombatRewardError extends Error {
	constructor(public status: number, message: string) { super(message); }
}

// Only server-side verification code may call this module to record results.
export function evaluateCombatReward(result: { status: VerifiedStatus }, balance: Record<string, unknown>): CombatReward {
	if (result.status !== "VERIFIED_WIN") return null;
	const table = balance.combat_rewards;
	if (!table || typeof table !== "object") throw new Error("Combat reward table missing");
	const probabilities = rewardIds.map(id => Number((table as Record<string, unknown>)[id]));
	if (probabilities.some(p => !Number.isFinite(p) || p < 0 || p > 1) || probabilities.reduce((a, b) => a + b, 0) > 1) throw new Error("Invalid combat reward probabilities");
	const roll = randomInt(1_000_000) / 1_000_000;
	let threshold = 0;
	for (let i = 0; i < rewardIds.length; i++) {
		threshold += probabilities[i];
		if (roll < threshold) return { resource_id: rewardIds[i], amount: 1 };
	}
	return null;
}

export function recordVerifiedCombatResult(db: Database, result: { player_id: string; status: VerifiedStatus }, balance: Record<string, unknown>): string {
	if (!result.player_id || !["VERIFIED_WIN", "VERIFIED_LOSS", "INVALID"].includes(result.status)) throw new Error("Invalid trusted combat result");
	const matchId = randomUUID();
	const now = Date.now();
	const reward = evaluateCombatReward(result, balance);
	db.prepare("INSERT INTO combat_reward_receipts (match_id, player_id, status, reward_json, verified_at, claimed_at, created_at) VALUES (?, ?, ?, ?, ?, NULL, ?)")
		.run(matchId, result.player_id, result.status, JSON.stringify(reward), now, now);
	return matchId;
}

export function claimVerifiedCombatReward<T>(db: Database, matchId: string, playerId: string, apply: (reward: CombatReward, duplicate: boolean) => T): { reward: CombatReward; duplicate: boolean; state: T } {
	return db.transaction(() => {
		const row = db.query("SELECT player_id, status, reward_json, claimed_at FROM combat_reward_receipts WHERE match_id = ?").get(matchId) as { player_id: string; status: string; reward_json: string; claimed_at: number | null } | null;
		if (!row || row.player_id !== playerId || row.status !== "VERIFIED_WIN") throw new CombatRewardError(404, "Verified combat reward not found.");
		let reward: unknown;
		try { reward = JSON.parse(row.reward_json); } catch { throw new CombatRewardError(500, "Invalid stored combat reward."); }
		if (reward !== null && (typeof reward !== "object" || Array.isArray(reward) || !rewardIds.includes((reward as any).resource_id) || (reward as any).amount !== 1 || Object.keys(reward).length !== 2)) throw new CombatRewardError(500, "Invalid stored combat reward.");
		const duplicate = row.claimed_at !== null;
		const state = apply(reward as CombatReward, duplicate);
		if (!duplicate) db.prepare("UPDATE combat_reward_receipts SET claimed_at = ? WHERE match_id = ? AND claimed_at IS NULL").run(Date.now(), matchId);
		return { reward: reward as CombatReward, duplicate, state };
	}).immediate();
}
