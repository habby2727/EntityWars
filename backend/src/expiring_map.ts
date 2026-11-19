// Incremental scans bound the work performed by each operation, even for large maps.
export class ExpiringMap<T> {
	private entries = new Map<string, { value: T; expiresAt: number }>();
	private cursor: MapIterator<[string, { value: T; expiresAt: number }]> | undefined;

	private sweep(now: number) {
		if (!this.cursor) this.cursor = this.entries.entries();
		for (let i = 0; i < 16; i++) {
			const next = this.cursor.next();
			if (next.done) { this.cursor = undefined; break; }
			if (next.value[1].expiresAt <= now) this.entries.delete(next.value[0]);
		}
	}
	get(key: string, now = Date.now()): T | undefined {
		this.sweep(now);
		const entry = this.entries.get(key);
		if (entry && entry.expiresAt <= now) { this.entries.delete(key); return undefined; }
		return entry?.value;
	}
	set(key: string, value: T, expiresAt: number, now = Date.now()): void {
		this.sweep(now);
		this.entries.set(key, { value, expiresAt });
	}
	delete(key: string): void { this.entries.delete(key); }
	get size(): number { return this.entries.size; }
}
