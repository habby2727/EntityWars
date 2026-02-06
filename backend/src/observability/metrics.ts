type MetricsSnapshot = {
	requests_total: number;
	errors_total: number;
	avg_latency_ms: number;
	status_counts: Record<string, number>;
};

const metrics = {
	requests: 0,
	errors: 0,
	latencySum: 0,
	latencyCount: 0,
	statusCounts: new Map<string, number>()
};

export function recordRequest(status: number, latencyMs: number): void {
	metrics.requests += 1;
	metrics.latencySum += latencyMs;
	metrics.latencyCount += 1;
	const key = String(status);
	metrics.statusCounts.set(key, (metrics.statusCounts.get(key) ?? 0) + 1);
}

export function recordError(): void {
	metrics.errors += 1;
}

export function snapshotMetrics(): MetricsSnapshot {
	const avg = metrics.latencyCount > 0 ? metrics.latencySum / metrics.latencyCount : 0;
	const statusCounts: Record<string, number> = {};
	for (const [key, value] of metrics.statusCounts.entries()) {
		statusCounts[key] = value;
	}
	return {
		requests_total: metrics.requests,
		errors_total: metrics.errors,
		avg_latency_ms: Math.round(avg),
		status_counts: statusCounts
	};
}
