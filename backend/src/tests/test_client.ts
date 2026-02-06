export type HttpResult<T = any> = {
	status: number;
	data: T;
};

type RateLimitOptions = {
	windowMs: number;
	max: number;
};

const DEFAULT_BASE_URL = Bun.env.BASE_URL || "http://127.0.0.1:8787";
const DEFAULT_WINDOW_MS = Number(Bun.env.RATE_LIMIT_WINDOW_MS || 60_000);
const DEFAULT_MAX = Number(Bun.env.RATE_LIMIT_MAX || 60);

class RateLimiter {
	private readonly windowMs: number;
	private readonly max: number;
	private readonly timestamps: number[] = [];

	constructor(options: RateLimitOptions) {
		this.windowMs = Math.max(1, options.windowMs || 60_000);
		this.max = Math.max(1, options.max || 60);
	}

	async waitForSlot(): Promise<void> {
		const now = Date.now();
		this.prune(now);
		if (this.timestamps.length < this.max) {
			this.timestamps.push(now);
			return;
		}
		const oldest = this.timestamps[0] ?? now;
		const waitMs = Math.max(0, oldest + this.windowMs - now + 5);
		await sleep(waitMs);
		this.prune(Date.now());
		this.timestamps.push(Date.now());
	}

	private prune(now: number): void {
		while (this.timestamps.length > 0 && now - this.timestamps[0] >= this.windowMs) {
			this.timestamps.shift();
		}
	}
}

export function createClient(baseUrl = DEFAULT_BASE_URL) {
	const limiter = new RateLimiter({ windowMs: DEFAULT_WINDOW_MS, max: DEFAULT_MAX });

	async function requestJson(
		method: string,
		path: string,
		body?: any,
		token?: string,
		rawBody?: string
	): Promise<HttpResult> {
		const url = `${baseUrl}${path}`;
		const headers: Record<string, string> = {};
		if (token) {
			headers.Authorization = `Bearer ${token}`;
		}
		if (method === "POST") {
			await limiter.waitForSlot();
			headers["Content-Type"] = "application/json";
		}
		const res = await fetch(url, {
			method,
			headers,
			body: rawBody ?? (body ? JSON.stringify(body) : undefined)
		});
		let data: any = {};
		try {
			data = await res.json();
		} catch {
			data = {};
		}
		return { status: res.status, data };
	}

	function buildQuery(params: Record<string, string | number | undefined | null>): string {
		const search = new URLSearchParams();
		for (const [key, value] of Object.entries(params)) {
			if (value === undefined || value === null || value === "") {
				continue;
			}
			search.set(key, String(value));
		}
		const query = search.toString();
		return query ? `?${query}` : "";
	}

	return {
		baseUrl,
		requestJson,
		getJson: (path: string, token?: string) => requestJson("GET", path, undefined, token),
		postJson: (path: string, body: any, token?: string) => requestJson("POST", path, body, token),
		postRaw: (path: string, rawBody: string, token?: string) =>
			requestJson("POST", path, undefined, token, rawBody),
		dev_login: (name: string) => requestJson("POST", "/auth/dev_login", { name }),
		get_static_version: () => requestJson("GET", "/static/version"),
		get_player_state: (token: string) => requestJson("GET", "/player/state", undefined, token),
		post_action: (token: string, action: any) => requestJson("POST", "/player/action", action, token),
		market_orders: (params: { resource_id?: string; type?: string; status?: string; seller_id?: string }) =>
			requestJson("GET", `/market/orders${buildQuery(params)}`),
		market_create_order: (token: string, body: any) => requestJson("POST", "/market/order", body, token),
		market_cancel: (token: string, body: any) => requestJson("POST", "/market/cancel", body, token),
		market_buy: (token: string, body: any) => requestJson("POST", "/market/buy", body, token),
		trade_jobs: (params: { output_resource_id?: string; status?: string }) =>
			requestJson("GET", `/trade/jobs${buildQuery(params)}`),
		trade_create_job: (token: string, body: any) => requestJson("POST", "/trade/jobs", body, token),
		trade_submit: (token: string, body: any) => requestJson("POST", "/trade/submit", body, token),
		trade_claim: (token: string, body: any) => requestJson("POST", "/trade/claim", body, token),
		world_state: (token?: string) => requestJson("GET", "/world/state", undefined, token),
		world_enter: (token: string, body: any) => requestJson("POST", "/world/enter", body, token),
		world_farm: (token: string, body: any) => requestJson("POST", "/world/farm", body, token),
		world_claim: (token: string, body: any) => requestJson("POST", "/world/claim", body, token),
		boss_state: () => requestJson("GET", "/boss/state"),
		boss_attack: (token: string, body: any) => requestJson("POST", "/boss/attack", body, token),
		boss_claim: (token: string, body: any) => requestJson("POST", "/boss/claim_rewards", body, token)
	};
}

export function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, Math.max(0, ms)));
}
