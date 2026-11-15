import { createHmac } from "node:crypto";

export function globalBossRoll(secret: string, zone: string, rotationKey: number): Buffer {
	return createHmac("sha256", secret).update(`global-boss:${zone}:${rotationKey}`).digest();
}

export function globalBossTier(roll: number, weights: Record<string, number>): string {
	let cumulative = 0;
	for (const tier of ["mythic", "rare", "epic", "legendary"]) {
		cumulative += weights[tier];
		if (roll < cumulative) return tier;
	}
	return "legendary";
}
