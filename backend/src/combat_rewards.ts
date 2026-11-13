import { Database } from "bun:sqlite";
import { randomInt } from "node:crypto";

export type VerifiedStatus = "VERIFIED_WIN" | "VERIFIED_LOSS" | "INVALID";
export type CombatReward = { resource_id: "arcane_shard" | "time_crystal"; amount: 1 | 3 } | null;

function validReward(value: any): value is Exclude<CombatReward, null> {
	return value && typeof value === "object" && !Array.isArray(value) && ((value.resource_id === "arcane_shard" && value.amount === 1) || (value.resource_id === "time_crystal" && (value.amount === 1 || value.amount === 3)));
}

export class CombatRewardError extends Error {
	constructor(public status: number, message: string) { super(message); }
}

// Only server-side verification code may call this module to record results.
export function evaluateCombatReward(result: { status: VerifiedStatus }, balance: Record<string, unknown>): CombatReward {
	if (result.status !== "VERIFIED_WIN") return null;
	const table = balance.combat_rewards;
	if (!Array.isArray(table) || table.some(entry => !validReward(entry) || typeof entry.weight !== "number" || !Number.isFinite(entry.weight) || entry.weight < 0 || entry.weight > 1) || table.reduce((sum, entry) => sum + entry.weight, 0) > 1) throw new Error("Invalid combat reward probabilities");
	const roll = randomInt(1_000_000) / 1_000_000;
	let threshold = 0;
	for (const entry of table) {
		threshold += entry.weight;
		if (roll < threshold) return { resource_id: entry.resource_id, amount: entry.amount };
	}
	return null;
}

export function recordVerifiedCombatResult(db: Database, result: { match_id: string; player_id: string; status: VerifiedStatus }, balance: Record<string, unknown>): string {
	return db.transaction(() => {
		if (typeof result.match_id !== "string" || !result.match_id.trim() || result.match_id.length > 128 || typeof result.player_id !== "string" || !result.player_id.trim() || result.player_id.length > 256 || !["VERIFIED_WIN", "VERIFIED_LOSS", "INVALID"].includes(result.status)) throw new Error("Invalid trusted combat result");
		const existing = db.query("SELECT player_id, status FROM combat_reward_receipts WHERE match_id = ?").get(result.match_id) as { player_id: string; status: string } | null;
		if (existing) {
			if (existing.player_id !== result.player_id || existing.status !== result.status) throw new CombatRewardError(409, "Combat match result conflicts with existing receipt.");
			return result.match_id;
		}
		const now = Date.now();
		const reward = evaluateCombatReward(result, balance);
		db.query("INSERT INTO combat_reward_receipts (match_id, player_id, status, reward_json, verified_at, claimed_at, created_at) VALUES (?, ?, ?, ?, ?, NULL, ?)")
			.run(result.match_id, result.player_id, result.status, JSON.stringify(reward), now, now);
		return result.match_id;
	}).immediate();
}

export function claimVerifiedCombatReward<T>(db: Database, matchId: string, playerId: string, apply: (reward: CombatReward, duplicate: boolean) => T): { reward: CombatReward; duplicate: boolean; state: T } {
	return db.transaction(() => {
		const row = db.query("SELECT player_id, status, reward_json, claimed_at FROM combat_reward_receipts WHERE match_id = ?").get(matchId) as { player_id: string; status: string; reward_json: string; claimed_at: number | null } | null;
		if (!row || row.player_id !== playerId || row.status !== "VERIFIED_WIN") throw new CombatRewardError(404, "Verified combat reward not found.");
		let reward: unknown;
		try { reward = JSON.parse(row.reward_json); } catch { throw new CombatRewardError(500, "Invalid stored combat reward."); }
		if (reward !== null && (!validReward(reward) || Object.keys(reward).length !== 2)) throw new CombatRewardError(500, "Invalid stored combat reward.");
		const duplicate = row.claimed_at !== null;
		const state = apply(reward as CombatReward, duplicate);
		if (!duplicate) db.prepare("UPDATE combat_reward_receipts SET claimed_at = ? WHERE match_id = ? AND claimed_at IS NULL").run(Date.now(), matchId);
		return { reward: reward as CombatReward, duplicate, state };
	}).immediate();
}
