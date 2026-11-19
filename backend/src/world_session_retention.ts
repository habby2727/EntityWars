const MAX_IDLE_MS = 180 * 24 * 60 * 60 * 1000;

export function pruneWorldSessions<T extends { started_at: number; last_farm_at: number; pending_loot: object }>(sessions: Record<string, T>, now: number): void {
	const ordered = Object.entries(sessions).sort(([a, x], [b, y]) =>
		Math.max(y.started_at, y.last_farm_at) - Math.max(x.started_at, x.last_farm_at) || (a < b ? -1 : a > b ? 1 : 0));
	for (const [id, session] of ordered.slice(20)) {
		if (now - Math.max(session.started_at, session.last_farm_at) > MAX_IDLE_MS && Object.keys(session.pending_loot).length === 0) delete sessions[id];
	}
}
