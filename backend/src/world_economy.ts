export function worldDropAmount(min: number, max: number, roll: number): number {
	return Math.min(max, min + Math.floor((max - min + 1) * roll));
}

export function incrementalBossTokens(previous: number, current: number, divisor: number): number {
	return Math.floor(current / divisor) - Math.floor(previous / divisor);
}
