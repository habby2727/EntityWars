import { ExpiringMap } from "./expiring_map";

export function createBossIpLimit() {
	const windows = new ExpiringMap<{ windowEnd: number; count: number }>();
	return (ip: string, windowEnd: number, limit: number, now = Date.now()): boolean => {
		if (!ip || limit <= 0) return true;
		const entry = windows.get(ip, now);
		if (!entry || entry.windowEnd !== windowEnd) {
			windows.set(ip, { windowEnd, count: 1 }, windowEnd + 1, now);
			return true;
		}
		if (entry.count >= limit) return false;
		entry.count += 1;
		return true;
	};
}
