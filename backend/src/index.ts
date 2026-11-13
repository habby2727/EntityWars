import { Database } from "bun:sqlite";
import { createHash, createHmac } from "crypto";
import { existsSync, mkdirSync, readFileSync } from "fs";
import { dirname, resolve } from "path";
import defaultConfig from "./config/default";
import devConfig from "./config/dev.local";
import prodConfig from "./config/prod";
import {
    getAccessToken,
    issueAccessToken,
    issueTokenPair,
    revokeAccessToken,
    revokeRefreshToken,
    rotateRefreshToken
} from "./auth/tokens";
import { AccountStatusUnavailableError, isUserDisabled, pingPostgres, postgresExample, upsertUser } from "./db/postgres";
import { ensureRedisReady, getRedis, pingRedis, redisExample } from "./db/redis";
import { extractToken, getSession as getLegacySession, issueSession, revokeSession } from "./middleware/auth";
import { rateLimit } from "./middleware/rateLimit";
import { enqueueJob, getJobQueueSize } from "./jobs/queue";
import { logError, logInfo, logWarn } from "./observability/logger";
import { recordError, recordRequest, snapshotMetrics } from "./observability/metrics";
import { normalizeSpellProgress, startSpellResearch, claimSpellResearch, setSpellLoadout, type SpellProgress } from "./spell_research";
import { claimVerifiedCombatReward, CombatRewardError } from "./combat_rewards";

const IS_PRODUCTION = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some(
	(value) => value?.toLowerCase() == "production" || value?.toLowerCase() == "prod"
);
function economicSecret(name: string, developmentDefault: string): string {
	const secret = Bun.env[name];
	if (IS_PRODUCTION && (!secret || secret.trim().length < 32 || ["dev_experiment_secret", "dev_trade_secret", "dev_world_secret"].includes(secret.trim()))) {
		throw new Error(`${name} must be configured with a non-development secret of at least 32 characters in production.`);
	}
	return secret || developmentDefault;
}
const EXPERIMENT_SECRET = economicSecret("EXPERIMENT_SECRET", "dev_experiment_secret");
const TRADE_SECRET = economicSecret("TRADE_SECRET", "dev_trade_secret");
const WORLD_SECRET = economicSecret("WORLD_SECRET", "dev_world_secret");
const TOKEN_SIGNING_SECRET = Bun.env.TOKEN_SIGNING_SECRET || "";

type RateLimitConfig = {
	windowMs: number;
	maxPostsPerWindow: number;
};

type Config = {
	env: string;
	host: string;
	port: number;
	apiVersion: string;
	dbPath: string;
	maxBodyBytes: number;
	rateLimit: RateLimitConfig;
	tokenTtlMs: number;
};

type BuildingRuntime = {
	stored_output?: number;
	last_tick?: number;
};

type BuildingState = {
	level: number;
	route?: string;
	runtime?: BuildingRuntime;
};

type BoostState = {
	started_at?: number;
	expires_at: number;
};

type ResearchRuntime = {
	active_id?: string;
	queued_id?: string;
	started_at?: number;
	completes_at?: number;
};

type LabRuntime = {
	cooldowns: Record<string, number>;
	boosts: Record<string, BoostState>;
	research: ResearchRuntime;
	experiment_stability?: { failures: number };
	experiment_last?: { id: string; success: boolean; chance: number; at: number; expires_at: number };
	directive?: { id: string; starts_at: number; ends_at: number };
	reactor_overcharge?: { progress: number; last_used_at: number };
	anomaly?: { next_at: number; last_choice: string; last_reward: ResourceWallet; last_at: number };
	sync_project?: { project_id: string; partner_kind: string; partner_id: string; started_at: number; completes_at: number };
	npc_trade?: { day_key: number; daily_uses: Record<string, number>; week_key: number; weekly_uses: Record<string, number> };
};

type LabState = {
	hqLevel: number;
	hqPath: string;
	buildings: Record<string, BuildingState>;
	runtime: LabRuntime;
};

type ResourceWallet = Record<string, number>;

type ZoneDropTable = Record<string, number>;

type ZoneDef = {
	id: string;
	name: string;
	drops: ZoneDropTable;
	rare_drops?: ZoneDropTable;
	modifiers?: string[];
};

type BossDef = {
	id: string;
	name: string;
	modifiers?: string[];
	max_hp?: number;
};

type ZoneRotation = {
	zone_id: string;
	modifier_ids: string[];
	rotation_ends_at: number;
	seed: string;
};

type BossState = {
	boss_id: string;
	hp: number;
	max_hp: number;
	phase: number;
	window_starts_at: number;
	window_ends_at: number;
	modifiers: string[];
	contributors: Record<string, number>;
};

type WorldStateData = {
	zones: ZoneRotation[];
	active_events: any[];
	bosses: BossState[];
	updated_at: number;
};

type ZoneProgress = {
	heat: number;
	reputation: number;
	last_heat_at: number;
};

type WorldSession = {
	session_id: string;
	zone_id: string;
	started_at: number;
	last_farm_at: number;
	pending_loot: ResourceWallet;
	blocks_farmed: number;
	modifiers: string[];
};

type PlayerWorldState = {
	zone_progress: Record<string, ZoneProgress>;
	daily_entries: number;
	last_entry_reset_at: number;
	last_gate_entry_at: number;
	stamina: number;
	last_stamina_at: number;
	boss_tickets: number;
	last_boss_ticket_at: number;
	boss_claims: Record<string, number>;
	boss_tokens: number;
	sessions: Record<string, WorldSession>;
};

type PlayerState = {
	player_id: string;
	state_revision: number;
	display_name?: string;
	wallet: ResourceWallet;
	lab: LabState;
	world: PlayerWorldState;
	research_flags: Record<string, boolean>;
	spell_progress: SpellProgress;
	item_progress: Record<string, ItemProgress>;
	homunculus_progress: Record<string, HomunculusProgress>;
	updated_at: number;
};

type ItemProgress = {
	level: number;
	[key: string]: unknown;
};

type HomunculusProgress = { level: number; mutation_id?: string; mutation_changed_at?: number };

function normalizeHomunculusProgress(value: unknown): Record<string, HomunculusProgress> {
	if (!value || typeof value !== "object" || Array.isArray(value)) return {};
	const result: Record<string, HomunculusProgress> = {};
	for (const [id, raw] of Object.entries(value)) {
		if (!staticData.homunculusIds.has(id) || !raw || typeof raw !== "object" || Array.isArray(raw)) continue;
		const entry = raw as Record<string, unknown>;
		const level = Number(entry.level);
		const progress: HomunculusProgress = { level: Number.isInteger(level) ? Math.max(0, Math.min(10, level)) : 0 };
		if (typeof entry.mutation_id === "string" && staticData.mutationIds.has(entry.mutation_id)) {
			progress.mutation_id = entry.mutation_id;
			progress.mutation_changed_at = clampInt(entry.mutation_changed_at, 0, Number.MAX_SAFE_INTEGER);
		}
		result[id] = progress;
	}
	return result;
}

function normalizeItemProgress(value: unknown): Record<string, ItemProgress> {
	if (!value || typeof value !== "object" || Array.isArray(value)) return {};
	const result: Record<string, ItemProgress> = {};
	for (const [id, raw] of Object.entries(value)) {
		if (!/^[a-z][a-z0-9_]{0,63}$/.test(id) || !raw || typeof raw !== "object" || Array.isArray(raw)) continue;
		const item = raw as Record<string, unknown>;
		const level = Number(item.level);
		result[id] = {
			...item,
			level: Number.isInteger(level) ? Math.max(0, Math.min(10, level)) : 0,
		};
	}
	return result;
}

class HttpError extends Error {
	status: number;
	constructor(status: number, message: string) {
		super(message);
		this.status = status;
	}
}

type RequestContext = {
	requestId: string;
	rateLimitBypass: boolean;
	startAt: number;
	ip: string;
	path: string;
	userId?: string | null;
};

const config = loadConfig();
const staticData = loadStaticData();
const ACCESS_TTL_MS = getEnvNumber("ACCESS_TTL_SECONDS", 15 * 60) * 1000;
const REFRESH_TTL_MS = getEnvNumber("REFRESH_TTL_SECONDS", 7 * 24 * 60 * 60) * 1000;
const EXPENSIVE_RATE_WINDOW = getEnvNumber("EXPENSIVE_RATE_LIMIT_WINDOW_SECONDS", 60);
const EXPENSIVE_RATE_MAX = getEnvNumber("EXPENSIVE_RATE_LIMIT_MAX", 60);
const CORS_ORIGINS = parseCorsOrigins();
const dbFilePath = ensureDbPath(config.dbPath);
const db = new Database(dbFilePath);
db.exec("PRAGMA busy_timeout = 5000;");
for (let attempt = 0; ; attempt++) {
	try {
		db.exec("PRAGMA journal_mode = WAL;");
		break;
	} catch (err) {
		if (attempt >= 50 || typeof err !== "object" || err === null || !String((err as { code?: unknown }).code).startsWith("SQLITE_BUSY")) throw err;
		Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
	}
}
const getPlayerByIdStmt = db.prepare(
	"SELECT player_id, display_name, state_json, updated_at FROM players WHERE player_id = ?"
);
const getPlayerByNameStmt = db.prepare(
	"SELECT player_id, display_name, state_json, updated_at FROM players WHERE display_name = ?"
);
const insertPlayerStmt = db.prepare(
	"INSERT INTO players (player_id, display_name, state_json, updated_at) VALUES (?, ?, ?, ?)"
);
const updatePlayerStmt = db.prepare(
	"UPDATE players SET state_json = json_set(?, '$.state_revision', CASE WHEN json_valid(state_json) THEN MAX(0, CAST(COALESCE(json_extract(state_json, '$.state_revision'), 0) AS INTEGER)) + 1 ELSE 1 END), updated_at = ? WHERE player_id = ?"
);
const getActionStmt = db.prepare(
	"SELECT player_id, action_type, payload_json, result_state_json FROM action_log WHERE player_id = ? AND client_action_id = ?"
);
const insertActionStmt = db.prepare(
	"INSERT INTO action_log (player_id, client_action_id, action_type, payload_json, result_state_json, created_at) VALUES (?, ?, ?, ?, ?, ?)"
);
const insertOrderStmt = db.prepare(
	"INSERT INTO market_orders (order_id, seller_id, type, resource_id, amount, price_resource_id, price_amount, fee_bps, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
);
const getOrderStmt = db.prepare(
	"SELECT order_id, seller_id, type, resource_id, amount, price_resource_id, price_amount, fee_bps, status, created_at FROM market_orders WHERE order_id = ?"
);
const updateOrderStatusStmt = db.prepare(
	"UPDATE market_orders SET status = ? WHERE order_id = ?"
);
const getOrderFillsSumStmt = db.prepare(
	"SELECT COALESCE(SUM(amount), 0) as filled FROM market_fills WHERE order_id = ?"
);
const insertFillStmt = db.prepare(
	"INSERT INTO market_fills (fill_id, order_id, buyer_id, amount, total_price, fee, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
);
const getEscrowStmt = db.prepare(
	"SELECT amount FROM escrow WHERE player_id = ? AND resource_id = ?"
);
const addEscrowStmt = db.prepare(
	"INSERT INTO escrow (player_id, resource_id, amount) VALUES (?, ?, ?) ON CONFLICT(player_id, resource_id) DO UPDATE SET amount = amount + excluded.amount"
);
const setEscrowStmt = db.prepare(
	"INSERT INTO escrow (player_id, resource_id, amount) VALUES (?, ?, ?) ON CONFLICT(player_id, resource_id) DO UPDATE SET amount = excluded.amount"
);
const listOrdersStmt = db.prepare(
	"SELECT order_id, seller_id, type, resource_id, amount, price_resource_id, price_amount, fee_bps, status, created_at FROM market_orders WHERE (? IS NULL OR resource_id = ?) AND (? IS NULL OR type = ?) AND (? IS NULL OR status = ?) AND (? IS NULL OR seller_id = ?) ORDER BY created_at DESC LIMIT ?"
);
const insertTradeJobStmt = db.prepare(
	"INSERT INTO trade_jobs (job_id, provider_id, input_resource_id, input_amount, output_resource_id, output_min, output_max, duration_sec, commission_resource_id, commission_amount, queue_limit, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
);
const getTradeJobStmt = db.prepare(
	"SELECT job_id, provider_id, input_resource_id, input_amount, output_resource_id, output_min, output_max, duration_sec, commission_resource_id, commission_amount, queue_limit, status, created_at FROM trade_jobs WHERE job_id = ?"
);
const listTradeJobsStmt = db.prepare(
	"SELECT job_id, provider_id, input_resource_id, input_amount, output_resource_id, output_min, output_max, duration_sec, commission_resource_id, commission_amount, queue_limit, status, created_at FROM trade_jobs WHERE (? IS NULL OR output_resource_id = ?) AND (? IS NULL OR status = ?) ORDER BY created_at DESC LIMIT ?"
);
const insertTradeRunStmt = db.prepare(
	"INSERT INTO trade_job_runs (run_id, job_id, customer_id, submitted_at, completes_at, input_locked, status, output_amount, rng_seed) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
);
const getTradeRunStmt = db.prepare(
	"SELECT run_id, job_id, customer_id, submitted_at, completes_at, input_locked, status, output_amount, rng_seed FROM trade_job_runs WHERE run_id = ?"
);
const updateTradeRunStmt = db.prepare(
	"UPDATE trade_job_runs SET status = ?, output_amount = ? WHERE run_id = ?"
);
const countTradeRunsStmt = db.prepare(
	"SELECT COUNT(*) as count FROM trade_job_runs WHERE job_id = ? AND status = ?"
);
const insertAuditStmt = db.prepare(
	"INSERT INTO audit_wallet (audit_id, player_id, delta_wallet, reason, related_id, created_at) VALUES (?, ?, ?, ?, ?, ?)"
);
const countAuditStmt = db.prepare(
	"SELECT COUNT(*) as count FROM audit_wallet WHERE player_id = ?"
);
const getWorldStmt = db.prepare("SELECT state_json, updated_at FROM world LIMIT 1");
const insertWorldStmt = db.prepare("INSERT INTO world (state_json, updated_at) VALUES (?, ?)");
const updateWorldStmt = db.prepare("UPDATE world SET state_json = ?, updated_at = ?");

const bossIpWindow = new Map<string, { windowEnd: number; count: number }>();
const sockets = new Set<WebSocket>();
const DEBUG_BYPASS = !IS_PRODUCTION && Bun.env.DEBUG_BYPASS == "1";

function developmentLoginAllowed(address: string | undefined, origin: string | null): boolean {
	if (IS_PRODUCTION || !address) return false;
	if (origin) {
		try {
			const parsed = new URL(origin);
			if (!["http:", "https:"].includes(parsed.protocol) || !["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname)) return false;
		} catch { return false; }
	}
	const peer = address.startsWith("::ffff:") ? address.slice(7) : address;
	if (peer === "127.0.0.1" || peer === "::1") return true;
	if (Bun.env.DEV_DOCKER_LOCAL_LOGIN !== "1") return false;
	try {
		for (const line of readFileSync("/proc/net/route", "utf8").split("\n").slice(1)) {
			const fields = line.trim().split(/\s+/);
			if (fields[1] !== "00000000" || !/^[0-9A-Fa-f]{8}$/.test(fields[2] ?? "")) continue;
			const gateway = Number.parseInt(fields[2], 16);
			const ip = [gateway & 255, (gateway >>> 8) & 255, (gateway >>> 16) & 255, (gateway >>> 24) & 255].join(".");
			if (peer === ip && ip !== "0.0.0.0") return true;
		}
	} catch { /* Non-Linux or no gateway: fail closed. */ }
	return false;
}

// TODO: world module
// TODO: sync module
// TODO: anomalies module


function loadConfig(): Config {
	const env = (Bun.env.NODE_ENV || Bun.env.BUN_ENV || "").toLowerCase();
	let merged: Config = mergeConfig(defaultConfig, {});
	if (env == "production" || env == "prod") {
		merged = mergeConfig(merged, prodConfig);
	} else {
		merged = mergeConfig(merged, devConfig);
	}
	merged.dbPath = Bun.env.DB_PATH || merged.dbPath;
	merged.port = Math.max(1, Math.min(65535, Math.trunc(getEnvNumber("PORT", merged.port))));
	merged.host = Bun.env.HOST || merged.host;
	const maxBody = getEnvNumber("MAX_BODY_BYTES", merged.maxBodyBytes);
	const tokenSeconds = getEnvNumber("SESSION_TTL_SECONDS", merged.tokenTtlMs / 1000);
	merged.maxBodyBytes = Math.max(1024, maxBody);
	merged.tokenTtlMs = Math.max(1000, tokenSeconds * 1000);
	return merged;
}

function mergeConfig(base: Config, override: Partial<Config>): Config {
	const rateLimit = { ...base.rateLimit, ...(override.rateLimit || {}) };
	return { ...base, ...override, rateLimit };
}

function getEnvNumber(name: string, fallback: number): number {
	const raw = Bun.env[name];
	if (raw == null || raw == "") {
		return fallback;
	}
	const parsed = Number(raw);
	return Number.isFinite(parsed) ? parsed : fallback;
}

function parseCorsOrigins(): string[] {
	const raw = Bun.env.CORS_ORIGINS;
	if (!raw) {
		return [];
	}
	return raw
		.split(",")
		.map((value) => value.trim())
		.filter((value) => value.length > 0);
}

function ensureDbPath(path: string): string {
	const resolved = resolve(process.cwd(), path);
	const dir = dirname(resolved);
	if (!existsSync(dir)) {
		mkdirSync(dir, { recursive: true });
	}
	return resolved;
}

function normalizeLoginEmail(name: string): string {
	const trimmed = name.trim();
	if (trimmed.includes("@")) {
		return trimmed.toLowerCase();
	}
	const slug = trimmed
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, ".")
		.replace(/^\.+|\.+$/g, "");
	return `${slug || "dev"}@dev.local`;
}

function getClientIp(req: Request): string {
	const forwarded = req.headers.get("x-forwarded-for");
	if (forwarded) {
		return forwarded.split(",")[0].trim();
	}
	const real = req.headers.get("x-real-ip");
	if (real) {
		return real.trim();
	}
	return "unknown";
}

function getRequestId(req: Request): string {
	const existing = req.headers.get("x-request-id");
	if (existing && existing.length > 0) {
		return existing;
	}
	return crypto.randomUUID();
}

function isDebugBypass(req: Request): boolean {
	if (!DEBUG_BYPASS) {
		return false;
	}
	const header = req.headers.get("x-debug-bypass");
	if (!header) {
		return false;
	}
	return header == "1" || header.toLowerCase() == "true";
}

function isOriginAllowed(origin: string): boolean {
	if (CORS_ORIGINS.length == 0) {
		const env = (Bun.env.NODE_ENV || Bun.env.BUN_ENV || "").toLowerCase();
		if (env == "production" || env == "prod") {
			return false;
		}
		return origin.startsWith("http://localhost") || origin.startsWith("http://127.0.0.1");
	}
	if (CORS_ORIGINS.includes("*")) {
		return true;
	}
	return CORS_ORIGINS.includes(origin);
}

function buildCorsHeaders(req: Request): Record<string, string> {
	const origin = req.headers.get("origin");
	if (!origin) {
		return {};
	}
	if (!isOriginAllowed(origin)) {
		return {};
	}
	return {
		"Access-Control-Allow-Origin": origin,
		"Access-Control-Allow-Methods": "GET,POST,OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type,Authorization,X-Dev-Token,X-Request-Id",
		"Access-Control-Max-Age": "600",
		Vary: "Origin"
	};
}

function applyResponseHeaders(res: Response, ctx: RequestContext, corsHeaders: Record<string, string>): Response {
	const headers = new Headers(res.headers);
	headers.set("X-Request-Id", ctx.requestId);
	if (ctx.rateLimitBypass) {
		headers.set("X-RateLimit-Bypass", "1");
	}
	headers.set("X-Content-Type-Options", "nosniff");
	headers.set("X-Frame-Options", "DENY");
	headers.set("Referrer-Policy", "no-referrer");
	for (const [key, value] of Object.entries(corsHeaders)) {
		headers.set(key, value);
	}
	return new Response(res.body, { status: res.status, headers });
}

async function applyRateLimit(
	ctx: RequestContext,
	options: Omit<Parameters<typeof rateLimit>[0], "ip" | "route"> & { route?: string }
): Promise<void> {
	const result = await rateLimit({
		...options,
		ip: ctx.ip,
		route: options.route ?? ctx.path
	});
	if (result.bypass) {
		ctx.rateLimitBypass = true;
	}
	if (!result.allowed) {
		logWarn(result.status == 503 ? "rate limit unavailable" : "rate limit exceeded", {
			ip: ctx.ip,
			path: ctx.path,
			key: options.keyPrefix
		});
		throw new HttpError(result.status ?? 429, result.message || "Rate limit exceeded.");
	}
}

async function readJson(req: Request, maxBytes: number): Promise<any> {
	const buf = await req.arrayBuffer();
	if (buf.byteLength > maxBytes) {
		throw new HttpError(413, "Body too large.");
	}
	if (buf.byteLength == 0) {
		return {};
	}
	try {
		return JSON.parse(new TextDecoder().decode(buf));
	} catch {
		throw new HttpError(400, "Invalid JSON.");
	}
}

function jsonResponse(data: unknown, status = 200): Response {
	return new Response(JSON.stringify(data), {
		status,
		headers: { "Content-Type": "application/json" }
	});
}

function getSchemaVersion(): string | null {
	try {
		const row = db.query("SELECT id FROM schema_migrations ORDER BY applied_at DESC LIMIT 1").get() as
			| { id: string }
			| undefined;
		return row?.id ?? null;
	} catch {
		return null;
	}
}

async function staticVersionResponse(): Promise<Response> {
	const cacheKey = "cache:static:version";
	const schemaVersion = getSchemaVersion();
	const staticVersion = staticData.balance?.static_version ?? null;
	const payload = {
		ok: true,
		api_version: config.apiVersion,
		env: config.env,
		server_time_unix_ms: Date.now(),
		schema_version: schemaVersion,
		static_version: staticVersion
	};
	let redisHealthy = true;
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			throw new Error("Redis unavailable");
		}
		const cached = await redis.get(cacheKey);
		if (cached) {
			return jsonResponse(JSON.parse(cached));
		}
	} catch (err) {
		console.warn("[cache] static/version redis read failed", err);
		redisHealthy = false;
	}
	if (redisHealthy) {
		try {
			const redis = getRedis();
			await redis.set(cacheKey, JSON.stringify(payload), "EX", 60);
		} catch (err) {
			console.warn("[cache] static/version redis write failed", err);
		}
	}
	return jsonResponse(payload);
}

async function healthResponse(): Promise<Response> {
	const [pgOk, redisOk] = await Promise.all([pingPostgres(), pingRedis()]);
	return jsonResponse({
		ok: true,
		postgres: pgOk ? "up" : "down",
		redis: redisOk ? "up" : "down",
		version: config.apiVersion
	});
}

async function metricsResponse(): Promise<Response> {
	const [pgOk, redisOk, queueSize] = await Promise.all([
		pingPostgres(),
		pingRedis(),
		getJobQueueSize()
	]);
	return jsonResponse({
		ok: true,
		...snapshotMetrics(),
		postgres: pgOk ? "up" : "down",
		redis: redisOk ? "up" : "down",
		job_queue_size: queueSize
	});
}

function stateResponse(state: PlayerState, ok = true, error?: string, status = 200): Response {
	const current = getPlayerByIdStmt.get(state.player_id) as { state_json: string } | undefined;
	const authoritative = current ? safeParseState(current.state_json, state.player_id, state.display_name ?? "") ?? state : state;
	return jsonResponse(
		{
			ok,
			server_time_unix_ms: Date.now(),
			updated_player_state: authoritative,
			error: error ?? null
		},
		status
	);
}

function stateResponseExtra(state: PlayerState, extra: Record<string, unknown> = {}): Response {
	const current = getPlayerByIdStmt.get(state.player_id) as { state_json: string } | undefined;
	const authoritative = current ? safeParseState(current.state_json, state.player_id, state.display_name ?? "") ?? state : state;
	return jsonResponse({
		ok: true,
		server_time_unix_ms: Date.now(),
		updated_player_state: authoritative,
		...extra
	});
}

function loginResponse(playerId: string, token: string): Response {
	return jsonResponse({
		ok: true,
		server_time_unix_ms: Date.now(),
		player_id: playerId,
		token
	});
}

function tokenPairResponse(accessToken: string, refreshToken: string): Response {
	return jsonResponse({
		ok: true,
		server_time_unix_ms: Date.now(),
		access_token: accessToken,
		refresh_token: refreshToken,
		access_expires_in: Math.floor(ACCESS_TTL_MS / 1000),
		refresh_expires_in: Math.floor(REFRESH_TTL_MS / 1000)
	});
}

function errorResponse(message: string, status: number): Response {
	return jsonResponse(
		{
			ok: false,
			server_time_unix_ms: Date.now(),
			error: message
		},
		status
	);
}

function getSessionTtlMs(): number {
	const envSeconds = Number(Bun.env.SESSION_TTL_SECONDS || 0);
	if (Number.isFinite(envSeconds) && envSeconds > 0) {
		return Math.floor(envSeconds * 1000);
	}
	return config.tokenTtlMs;
}

async function issueToken(playerId: string): Promise<string> {
	return issueSession(playerId, getSessionTtlMs());
}

async function requireAuth(req: Request, ctx?: RequestContext): Promise<string> {
	const token = extractToken(req);
	if (!token) {
		throw new HttpError(401, "Missing auth token.");
	}
	const access = await getAccessToken(token);
	const legacy = access ? null : await getLegacySession(token);
	const entry = access ?? legacy;
	if (!entry) {
		throw new HttpError(401, "Invalid token.");
	}
	if (await isUserDisabled(entry.userId)) {
		throw new HttpError(403, "User disabled.");
	}
	if (ctx) {
		ctx.userId = entry.userId;
	}
	return entry.userId;
}

async function tryAuth(req: Request, ctx?: RequestContext): Promise<string | null> {
	const token = extractToken(req);
	if (!token) {
		return null;
	}
	const access = await getAccessToken(token);
	const legacy = access ? null : await getLegacySession(token);
	const entry = access ?? legacy;
	if (!entry) {
		return null;
	}
	if (await isUserDisabled(entry.userId)) {
		return null;
	}
	if (ctx) {
		ctx.userId = entry.userId;
	}
	return entry.userId;
}

function findOrCreatePlayer(name: string): { player_id: string; display_name: string } {
	const existing = getPlayerByNameStmt.get(name) as
		| { player_id: string; display_name: string; state_json: string; updated_at: number }
		| undefined;
	if (existing) {
		return { player_id: existing.player_id, display_name: existing.display_name };
	}
	const playerId = crypto.randomUUID();
	const now = Date.now();
	const state = createDefaultState(playerId, name, now, true);
	insertPlayerStmt.run(playerId, name, JSON.stringify(state), now);
	return { player_id: playerId, display_name: name };
}

function ensurePlayerState(playerId: string): PlayerState {
	const row = getPlayerByIdStmt.get(playerId) as
		| { player_id: string; display_name: string; state_json: string; updated_at: number }
		| undefined;
	if (!row) {
		throw new HttpError(404, "Player not found.");
	}
	const parsed = safeParseState(row.state_json, row.player_id, row.display_name);
	if (!parsed) {
		const now = Date.now();
		const state = createDefaultState(row.player_id, row.display_name, now);
		updatePlayerStmt.run(JSON.stringify(state), now, row.player_id);
		return state;
	}
	return parsed;
}

function getIdempotentState(playerId: string, clientActionId: string, actionType?: string, payload?: unknown): PlayerState | null {
	const already = getActionStmt.get(playerId, clientActionId) as
		| { player_id: string; action_type: string; payload_json: string; result_state_json: string | null }
		| undefined;
	if (!already) {
		return null;
	}
	if (actionType) {
		let previous: unknown;
		try { previous = JSON.parse(already.payload_json); } catch { throw new HttpError(409, "Stored action payload is invalid."); }
		if (already.action_type !== actionType || canonicalActionPayload(previous) !== canonicalActionPayload(payload)) throw new HttpError(409, "Action ID already used with different content.");
		return ensurePlayerState(playerId);
	}
	if (already.result_state_json) {
		const parsed = safeParseState(already.result_state_json, playerId, "");
		if (parsed) {
			return parsed;
		}
	}
	return ensurePlayerState(playerId);
}

function canonicalActionPayload(value: unknown): string {
	if (Array.isArray(value)) return `[${value.map(canonicalActionPayload).join(",")}]`;
	if (value !== null && typeof value === "object") {
		const obj = value as Record<string, unknown>;
		return `{${Object.keys(obj).sort().map((key) => `${JSON.stringify(key)}:${canonicalActionPayload(obj[key])}`).join(",")}}`;
	}
	return JSON.stringify(value) ?? "null";
}

function safeParseState(
	stateJson: string,
	playerId: string,
	displayName: string
): PlayerState | null {
	try {
	const parsed = JSON.parse(stateJson);
	if (typeof parsed != "object" || parsed == null) {
		return null;
	}
	const resolvedName =
		displayName || (typeof (parsed as any).display_name == "string" ? (parsed as any).display_name : "");
	const wallet = normalizeWallet(parsed.wallet);
	const lab = normalizeLab(parsed.lab);
	const world = normalizeWorld(parsed.world, Date.now());
	const researchFlags = normalizeResearchFlags(parsed.research_flags);
	return {
		...parsed,
		player_id: playerId,
		state_revision: Number.isSafeInteger(parsed.state_revision) && parsed.state_revision >= 0 ? parsed.state_revision : 0,
		display_name: resolvedName,
		wallet,
		lab,
		world,
		research_flags: researchFlags,
		spell_progress: normalizeSpellProgress(parsed.spell_progress),
		item_progress: normalizeItemProgress(parsed.item_progress),
		homunculus_progress: normalizeHomunculusProgress(parsed.homunculus_progress),
		updated_at: Number(parsed.updated_at ?? Date.now())
	};
	} catch {
		return null;
	}
}

function createDefaultState(playerId: string, displayName: string, now: number, newAccount = false): PlayerState {
	const wallet = normalizeWallet(newAccount ? { essence: 120, core: 5 } : {});
	const lab = normalizeLab({});
	const world = normalizeWorld({}, now);
	return {
		player_id: playerId,
		state_revision: 0,
		display_name: displayName,
		wallet,
		lab,
		world,
		research_flags: {},
		spell_progress: normalizeSpellProgress(null),
		item_progress: {},
		homunculus_progress: {},
		updated_at: now
	};
}

function applyAction(
	state: PlayerState,
	actionType: string,
	payload: any,
	clientActionId = "",
	debugBypass = false
): { state: PlayerState; error?: string } {
	const now = Date.now();
	const next: PlayerState = {
		...state,
		wallet: { ...state.wallet },
		research_flags: { ...state.research_flags },
		spell_progress: normalizeSpellProgress(state.spell_progress),
		item_progress: normalizeItemProgress(state.item_progress),
		homunculus_progress: normalizeHomunculusProgress(state.homunculus_progress),
		lab: {
			...state.lab,
			buildings: { ...state.lab.buildings },
			runtime: cloneLabRuntime(state.lab.runtime)
		}
	};
	const runtime = ensureLabRuntime(next);
	cleanupLabRuntime(runtime, now);
	autoCompleteResearch(next, now);
	if (actionType == "UPGRADE_BUILDING") {
		return applyUpgrade(next, payload, debugBypass);
	}
	if (actionType === "HOM_UPGRADE" || actionType === "HOM_MUTATE") {
		const id = typeof payload?.homunculus_id === "string" ? payload.homunculus_id : "";
		if (!staticData.homunculusIds.has(id)) return { state: next, error: "Unknown homunculus." };
		if ((next.lab.buildings.homunculus_vat?.level ?? 0) < 1) return { state: next, error: "Homunculus Vat is not constructed." };
		const current = next.homunculus_progress[id] ?? { level: 0 };
		let cost: ResourceWallet;
		if (actionType === "HOM_UPGRADE") {
			if (next.lab.hqLevel < 2 || current.level >= 10) return { state: next, error: "Homunculus upgrade unavailable." };
			cost = { essence: Math.trunc(getBalanceNumber("hom_upgrade_essence_base", 25) + current.level * getBalanceNumber("hom_upgrade_essence_per_level", 15)) };
			if (current.level >= 5) cost.core = 1;
		} else {
			if (current.level < 3 || typeof payload?.mutation_id !== "string" || !staticData.mutationIds.has(payload.mutation_id) || payload.mutation_id === current.mutation_id || ((current.mutation_changed_at ?? 0) > 0 && now < current.mutation_changed_at! + getBalanceNumber("hom_mutation_cooldown_seconds", 21600) * 1000)) return { state: next, error: "Mutation unavailable." };
			cost = staticData.balance.hom_mutation_cost;
		}
		if (!cost || typeof cost !== "object" || Array.isArray(cost) || Object.keys(cost).some(id => !staticData.resources.has(id)) || Object.values(cost).some(amount => !Number.isSafeInteger(amount) || amount < 0)) return { state: next, error: "Invalid homunculus cost configuration." };
		if (Object.entries(cost).some(([res, amount]) => (next.wallet[res] ?? 0) < amount)) return { state: next, error: "Insufficient resources." };
		for (const [res, amount] of Object.entries(cost)) next.wallet[res] = (next.wallet[res] ?? 0) - amount;
		next.homunculus_progress[id] = actionType === "HOM_UPGRADE" ? { ...current, level: current.level + 1 } : { ...current, mutation_id: payload.mutation_id, mutation_changed_at: now };
		return { state: next };
	}
	if (actionType == "FORGE_UPGRADE") {
		const id = typeof payload?.item_id === "string" ? payload.item_id : "";
		if (!staticData.itemIds.has(id)) return { state: next, error: "Unknown item_id." };
		if ((next.lab.buildings.build_forge?.level ?? 0) < 1) return { state: next, error: "Build Forge is not constructed." };
		const current = next.item_progress[id] ?? { level: 0 };
		if (current.level >= 10) return { state: next, error: "Item level cap reached." };
		const cost = Math.max(0, Math.trunc(getBalanceNumber("forge_upgrade_essence_base", 20) + current.level * getBalanceNumber("forge_upgrade_essence_per_level", 10)));
		if ((next.wallet.essence ?? 0) < cost) return { state: next, error: "Insufficient essence." };
		next.wallet.essence -= cost;
		next.item_progress[id] = { ...current, level: current.level + 1 };
		return { state: next };
	}
	if (actionType === "FORGE_FUSE") {
		const id = typeof payload?.item_id === "string" ? payload.item_id : "";
		const donor = typeof payload?.donor_id === "string" ? payload.donor_id : "";
		if (!staticData.itemIds.has(id) || !staticData.itemIds.has(donor) || id === donor) return { state: next, error: "Invalid fusion weapons." };
		if ((next.lab.buildings.build_forge?.level ?? 0) < 1) return { state: next, error: "Build Forge is not constructed." };
		const current = next.item_progress[id] ?? { level: 0 };
		if (current.level < 3 || (next.item_progress[donor]?.level ?? 0) < 3) return { state: next, error: "Both weapons require level 3." };
		if (current.pending_reroll != null || (current.fusion as any)?.donor_id === donor) return { state: next, error: "Fusion unavailable." };
		const rarity = staticData.itemRarities[donor];
		const imprint = staticData.balance.forge_fusion_imprints?.[donor];
		const cost = staticData.balance[`forge_fusion_cost_${rarity}`];
		const effectIds = ["true_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "dot_true", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"];
		if (!["basic", "advanced"].includes(rarity) || !imprint || typeof imprint !== "object" || Array.isArray(imprint) || Object.entries(imprint).length !== 1 || Object.entries(imprint).some(([key, value]) => !effectIds.includes(key) || typeof value !== "number" || !Number.isFinite(value) || value <= 0) || !cost || typeof cost !== "object" || Array.isArray(cost) || Object.keys(cost).sort().join(",") !== "arcane_shard,core,essence" || Object.values(cost).some(value => !Number.isSafeInteger(value) || (value as number) < 0)) return { state: next, error: "Invalid fusion configuration." };
		if (Object.entries(cost).some(([resource, amount]) => (next.wallet[resource] ?? 0) < (amount as number))) return { state: next, error: "Insufficient resources." };
		for (const [resource, amount] of Object.entries(cost)) next.wallet[resource] = (next.wallet[resource] ?? 0) - (amount as number);
		next.item_progress[id] = { ...current, fusion: { donor_id: donor } };
		return { state: next };
	}
	if (["FORGE_SPECIALIZE", "FORGE_ALLOCATE_TRAIT", "FORGE_REROLL_TRAIT", "FORGE_CHOOSE_REROLL"].includes(actionType)) {
		const id = typeof payload?.item_id === "string" ? payload.item_id : "";
		if (!staticData.itemIds.has(id)) return { state: next, error: "Unknown item_id." };
		const current = next.item_progress[id] ?? { level: 0 };
		const isSpecialize = actionType === "FORGE_SPECIALIZE";
		const isReroll = actionType === "FORGE_REROLL_TRAIT";
		const isChoose = actionType === "FORGE_CHOOSE_REROLL";
		if ((isSpecialize || isReroll) && (next.lab.buildings.build_forge?.level ?? 0) < 1) return { state: next, error: "Build Forge is not constructed." };
		const path = isSpecialize ? payload?.path : current.specialization;
		if (typeof path !== "string" || !["aggressive", "defensive", "technical"].includes(path)) return { state: next, error: "Invalid specialization." };
		if (isSpecialize && (current.level < 1 || current.specialization != null)) return { state: next, error: "Item cannot be specialized." };
		const pool = staticData.balance.forge_trait_pool?.[path];
		if (!pool || typeof pool !== "object" || Array.isArray(pool)) return { state: next, error: "Invalid trait configuration." };
		const ids = Object.keys(pool);
		if (ids.length < 3 || ids.some(key => typeof pool[key] !== "number" || !Number.isFinite(pool[key]) || pool[key] <= 0)) return { state: next, error: "Invalid trait configuration." };
		const maxPoints = getBalanceNumber("forge_trait_max_points_per_slot", 4);
		if (!Number.isInteger(maxPoints) || maxPoints < 1) return { state: next, error: "Invalid trait configuration." };
		let traits: { id: string; points: number }[] = [];
		if (!isSpecialize) {
			if (!Array.isArray(current.traits) || current.traits.length !== 3) return { state: next, error: "Invalid item traits." };
			traits = current.traits.map((trait: any) => ({ ...trait }));
			if (traits.some(t => !t || typeof t.id !== "string" || !ids.includes(t.id) || !Number.isInteger(t.points) || t.points < 0 || t.points > maxPoints) || new Set(traits.map(t => t.id)).size !== 3 || traits.reduce((sum, t) => sum + t.points, 0) > current.level) return { state: next, error: "Invalid item traits." };
		}
		const slot = payload?.slot;
		if (!isSpecialize && (!Number.isInteger(slot) || slot < 0 || slot > 2)) return { state: next, error: "Invalid trait slot." };
		if (!isSpecialize && !isChoose && current.pending_reroll != null) return { state: next, error: "Resolve the pending reroll first." };
		if (!isSpecialize && !isReroll && !isChoose && (traits[slot].points >= maxPoints || traits.reduce((sum, t) => sum + t.points, 0) >= current.level)) return { state: next, error: "No available trait points." };
		const pending = current.pending_reroll as { slot?: unknown; options?: unknown } | undefined;
		if (isChoose && (!pending || pending.slot !== slot || !Array.isArray(pending.options) || pending.options.length !== 3 || new Set(pending.options).size !== 3 || pending.options.some(option => typeof option !== "string" || !ids.includes(option) || traits.some(t => t.id === option)) || typeof payload?.trait_id !== "string" || !pending.options.includes(payload.trait_id))) return { state: next, error: "Invalid or stale reroll selection." };
		const chooseTrait = (candidates: string[], slotIndex: number): string => {
			const digest = createHmac("sha256", EXPERIMENT_SECRET).update(JSON.stringify(["forge_trait_v1", state.player_id, id, slotIndex, clientActionId])).digest();
			return candidates[digest.readUInt32BE(0) % candidates.length];
		};
		if (isReroll && ids.filter(candidate => !traits.some(t => t.id === candidate)).length < 3) return { state: next, error: "Not enough alternative traits available." };
		if (isSpecialize || isReroll) {
			const configuredCost = staticData.balance[isSpecialize ? "forge_specialize_cost" : "forge_reroll_cost"];
			if (!configuredCost || typeof configuredCost !== "object" || Array.isArray(configuredCost)) return { state: next, error: "Invalid forge cost configuration." };
			const cost: ResourceWallet = { essence: configuredCost.essence, core: configuredCost.core };
			if (isReroll && current.level >= 7) cost.arcane_shard = getBalanceNumber("forge_reroll_high_level_shard", 1);
			if (Object.values(cost).some(amount => !Number.isSafeInteger(amount) || amount < 0)) return { state: next, error: "Invalid forge cost configuration." };
			if (Object.entries(cost).some(([resource, amount]) => (next.wallet[resource] ?? 0) < amount)) return { state: next, error: "Insufficient resources." };
			for (const [resource, amount] of Object.entries(cost)) next.wallet[resource] = (next.wallet[resource] ?? 0) - amount;
		}
		if (isSpecialize) {
			for (let i = 0; i < 3; i++) traits.push({ id: chooseTrait(ids.filter(candidate => !traits.some(t => t.id === candidate)), i), points: 0 });
		} else if (isReroll) {
			const options: string[] = [];
			for (let i = 0; i < 3; i++) {
				const candidates = ids.filter(candidate => !traits.some(t => t.id === candidate) && !options.includes(candidate));
				const digest = createHmac("sha256", EXPERIMENT_SECRET).update(JSON.stringify(["forge_reroll_offer_v1", state.player_id, id, slot, clientActionId, i])).digest();
				options.push(candidates[digest.readUInt32BE(0) % candidates.length]);
			}
			next.item_progress[id] = { ...current, specialization: path, traits, pending_reroll: { slot, options } };
			return { state: next };
		} else if (isChoose) {
			traits[slot] = { ...traits[slot], id: payload.trait_id };
			const { pending_reroll: _pending, ...remaining } = current;
			next.item_progress[id] = { ...remaining, specialization: path, traits };
			return { state: next };
		} else {
			traits[slot] = { ...traits[slot], points: traits[slot].points + 1 };
		}
		next.item_progress[id] = { ...current, specialization: path, traits };
		return { state: next };
	}
	if (actionType == "SET_BUILDING_ROUTE") {
		return applyRouteChange(next, payload);
	}
	if (actionType == "CLAIM_PRODUCTION") {
		return applyClaim(next, payload, now);
	}
	if (actionType === "NPC_TRADE") {
		if (next.lab.hqLevel < 2 || (next.lab.buildings.trade_hall?.level ?? 0) < 1) return { state: next, error: "Trade Hall unavailable." };
		const listing = npcTradeOffers(runtime, now);
		const offer = listing.offers.find(entry => entry.id === payload?.offer_id && entry.period_key === payload?.period_key);
		if (!offer || offer.remaining <= 0) return { state: next, error: "NPC offer unavailable or expired." };
		if (Object.entries(offer.pay).some(([id, amount]) => (next.wallet[id] ?? 0) < amount)) return { state: next, error: "Insufficient resources." };
		for (const [id, amount] of Object.entries(offer.pay)) next.wallet[id] = (next.wallet[id] ?? 0) - amount;
		applyWalletGrant(next.wallet, offer.receive);
		const counts = runtime.npc_trade ?? { day_key: listing.day_key, week_key: listing.week_key, daily_uses: {}, weekly_uses: {} };
		if (counts.day_key !== listing.day_key) { counts.day_key = listing.day_key; counts.daily_uses = {}; }
		if (counts.week_key !== listing.week_key) { counts.week_key = listing.week_key; counts.weekly_uses = {}; }
		const uses = offer.period === "daily" ? counts.daily_uses : counts.weekly_uses;
		uses[offer.id] = (uses[offer.id] ?? 0) + 1;
		runtime.npc_trade = counts;
		return { state: next };
	}
	if (actionType === "SYNC_START") {
		if (next.lab.hqLevel < 4 || (next.lab.buildings.sync_nexus?.level ?? 0) < 1) return { state: next, error: "Sync Nexus unavailable." };
		if (runtime.sync_project) return { state: next, error: "Sync project already active." };
		const duration = getBalanceNumber("sync_npc_duration_seconds", 28800);
		if (!Number.isSafeInteger(duration) || duration <= 0) return { state: next, error: "Invalid sync duration." };
		runtime.sync_project = { project_id: "calibration", partner_kind: "npc", partner_id: "echo", started_at: now, completes_at: now + duration * 1000 };
		return { state: next };
	}
	if (actionType === "SYNC_CLAIM") {
		const project = runtime.sync_project;
		if (!project || now < project.completes_at) return { state: next, error: "Sync project is not ready." };
		const reward = staticData.balance.sync_npc_reward;
		if (!reward || typeof reward !== "object" || Array.isArray(reward) || Object.entries(reward).some(([id, amount]) => !["essence", "core", "arcane_shard", "time_crystal"].includes(id) || !staticData.resources.has(id) || !Number.isSafeInteger(amount) || (amount as number) < 0)) return { state: next, error: "Invalid sync reward configuration." };
		applyWalletGrant(next.wallet, reward);
		delete runtime.sync_project;
		return { state: next };
	}
	if (actionType === "ANOMALY_RESOLVE") {
		const choice = payload?.choice;
		const level = next.lab.buildings.anomaly_containment?.level ?? 0;
		if (!["seal", "investigate"].includes(choice) || level < 1 || next.lab.hqLevel < (HQ_RULES.anomaly_containment?.unlock ?? 5)) return { state: next, error: "Anomaly unavailable." };
		if ((runtime.anomaly?.next_at ?? 0) > now) return { state: next, error: "Anomaly on cooldown." };
		const validReward = (reward: any): reward is ResourceWallet => !!reward && typeof reward === "object" && !Array.isArray(reward) && Object.entries(reward).every(([id, amount]) => ["essence", "core", "arcane_shard", "time_crystal"].includes(id) && staticData.resources.has(id) && Number.isSafeInteger(amount) && (amount as number) >= 0);
		let reward: ResourceWallet;
		if (choice === "seal") {
			reward = staticData.balance.anomaly_seal_reward;
			if (!validReward(reward)) return { state: next, error: "Invalid anomaly reward configuration." };
		} else {
			const outcomes = staticData.balance.anomaly_investigate_outcomes;
			if (!Array.isArray(outcomes) || !outcomes.length || outcomes.some(entry => !entry || typeof entry.weight !== "number" || !Number.isFinite(entry.weight) || entry.weight < 0 || !validReward(entry.reward)) || Math.abs(outcomes.reduce((sum, entry) => sum + entry.weight, 0) - 1) > 0.000001) return { state: next, error: "Invalid anomaly outcome configuration." };
			const digest = createHmac("sha256", EXPERIMENT_SECRET).update(JSON.stringify(["anomaly_resolve_v1", state.player_id, clientActionId])).digest();
			const roll = digest.readUInt32BE(0) / 0x100000000;
			let cumulative = 0;
			reward = outcomes[outcomes.length - 1].reward;
			for (const outcome of outcomes) { cumulative += outcome.weight; if (roll < cumulative) { reward = outcome.reward; break; } }
		}
		const base = getBalanceNumber("anomaly_cooldown_base_seconds", 28800);
		const reduction = getBalanceNumber("anomaly_cooldown_reduction_per_level", 900);
		if (base <= 0 || reduction < 0 || base - (level - 1) * reduction <= 0) return { state: next, error: "Invalid anomaly cooldown configuration." };
		applyWalletGrant(next.wallet, reward);
		runtime.anomaly = { next_at: now + (base - (level - 1) * reduction) * 1000, last_choice: choice, last_reward: { ...reward }, last_at: now };
		return { state: next };
	}
	if (actionType === "SET_HQ_DIRECTIVE") {
		const id = payload?.directive;
		if (!["production", "research", "experimentation"].includes(id) || next.lab.hqLevel < 1) return { state: next, error: "Invalid HQ directive." };
		if ((runtime.directive?.ends_at ?? 0) > now) return { state: next, error: "HQ directive is active." };
		const reactor = ensureBuildingState(next, "essence_reactor");
		const storage = ensureBuildingState(next, "storage_vault");
		if (reactor.level > 0) tickProduction(reactor, now, reactor.level, reactor.route || "stable", storage.route || "", next.lab.hqPath, runtime);
		runtime.directive = { id, starts_at: now, ends_at: now + Math.max(1, getBalanceNumber("hq_directive_duration_seconds", 86400)) * 1000 };
		return { state: next };
	}
	if (actionType === "REACTOR_OVERCHARGE") {
		const threshold = Math.max(1, Math.trunc(getBalanceNumber("reactor_overcharge_threshold", 300)));
		const charge = runtime.reactor_overcharge ?? { progress: 0, last_used_at: 0 };
		if ((next.lab.buildings.essence_reactor?.level ?? 0) < 1 || charge.progress < threshold || (charge.last_used_at > 0 && now < charge.last_used_at + getBalanceNumber("reactor_overcharge_cooldown_seconds", 10800) * 1000)) return { state: next, error: "Overcharge is not ready." };
		const reward = staticData.balance.reactor_overcharge_reward;
		if (!reward || typeof reward !== "object" || Array.isArray(reward) || Object.entries(reward).some(([id, amount]) => !staticData.resources.has(id) || !Number.isSafeInteger(amount) || (amount as number) < 0)) return { state: next, error: "Invalid overcharge reward." };
		applyWalletGrant(next.wallet, reward);
		runtime.reactor_overcharge = { progress: 0, last_used_at: now };
		return { state: next };
	}
	if (actionType == "START_EXPERIMENT") {
		return applyStartExperiment(next, payload, clientActionId, now);
	}
	if (actionType == "START_RESEARCH") {
		return applyStartResearch(next, payload, now);
	}
	if (actionType === "QUEUE_RESEARCH") {
		const id = typeof payload?.research_id === "string" ? payload.research_id.trim() : "";
		const node = staticData.research[id];
		const activeId = runtime.research.active_id ?? "";
		const active = staticData.research[activeId];
		if (!node || !active || id === activeId || runtime.research.queued_id || next.research_flags[node.flag_id]) return { state: next, error: "Research queue unavailable." };
		if (next.lab.hqLevel < (HQ_RULES.arcane_archives?.unlock ?? 3) || (next.lab.buildings.arcane_archives?.level ?? 0) < 1) return { state: next, error: "Arcane Archives not built or locked." };
		if (node.requires.some(req => !next.research_flags[req] && req !== active.flag_id)) return { state: next, error: "Research requirements not met." };
		const fee = getBalanceNumber("archive_queue_fee_essence", 10);
		if (!Number.isSafeInteger(fee) || fee < 0) return { state: next, error: "Invalid queue fee." };
		const cost: ResourceWallet = { essence: fee };
		for (const [resource, amount] of Object.entries(node.cost)) {
			if (!staticData.resources.has(resource) || !Number.isSafeInteger(amount) || amount < 0) return { state: next, error: "Invalid research cost." };
			cost[resource] = (cost[resource] ?? 0) + amount;
		}
		if (Object.entries(cost).some(([resource, amount]) => (next.wallet[resource] ?? 0) < amount)) return { state: next, error: "Insufficient resources." };
		for (const [resource, amount] of Object.entries(cost)) next.wallet[resource] = (next.wallet[resource] ?? 0) - amount;
		runtime.research.queued_id = id;
		return { state: next };
	}
	if (actionType == "START_SPELL_RESEARCH") {
		const error = startSpellResearch(next, payload, now, staticData.resources, staticData.balance, isBoostActive(runtime, "fast_spells", now) ? experimentEffect("fast_spells", "spell_time_mult", 0.85) : 1);
		return error ? { state: next, error } : { state: next };
	}
	if (actionType == "SET_SPELL_LOADOUT") {
		const error = setSpellLoadout(next, payload);
		return error ? { state: next, error } : { state: next };
	}
	if (actionType == "CLAIM_SPELL_RESEARCH") {
		const error = claimSpellResearch(next, payload, now);
		return error ? { state: next, error } : { state: next };
	}
	if (actionType == "CLAIM_RESEARCH" || actionType == "COMPLETE_RESEARCH") {
		return applyClaimResearch(next, payload, now);
	}
	return { state: next, error: "Unknown action_type." };
}

function broadcast(message: unknown): void {
	const payload = JSON.stringify(message);
	for (const socket of sockets) {
		socket.send(payload);
	}
}

async function maybeRunExternalExamples(): Promise<void> {
	const runPostgres = Bun.env.PG_EXAMPLE == "1" || Bun.env.POSTGRES_EXAMPLE == "1";
	const runRedis = Bun.env.REDIS_EXAMPLE == "1";
	if (runPostgres) {
		await postgresExample();
	}
	if (runRedis) {
		await redisExample();
	}
}

async function startServer(): Promise<void> {
	void maybeRunExternalExamples();
	const server = Bun.serve({
		hostname: config.host,
		port: config.port,
		fetch: async (req, server) => {
			const ctx: RequestContext = {
				requestId: getRequestId(req),
				rateLimitBypass: false,
				startAt: Date.now(),
				ip: getClientIp(req),
				path: new URL(req.url).pathname
			};
			const corsHeaders = buildCorsHeaders(req);
			if (req.method == "OPTIONS") {
				const res = new Response(null, { status: 204 });
				const finalRes = applyResponseHeaders(res, ctx, corsHeaders);
				recordRequest(finalRes.status, Date.now() - ctx.startAt);
				return finalRes;
			}
			try {
				const res = await (async () => {
					const url = new URL(req.url);
				if (url.pathname == "/ws") {
						const address = server.requestIP(req)?.address;
						if (IS_PRODUCTION || !["127.0.0.1", "::1", "::ffff:127.0.0.1"].includes(address ?? "")) {
							return jsonResponse({ error: "WebSocket unavailable." }, 403);
						}
					const upgraded = server.upgrade(req, { data: { ip: getClientIp(req) } });
					if (upgraded) {
						return;
					}
					return jsonResponse({ error: "Upgrade required" }, 426);
				}

				if (req.method == "POST" && url.pathname == "/auth/dev_login") {
						const address = server.requestIP(req)?.address;
						if (!developmentLoginAllowed(address, req.headers.get("origin"))) {
							throw new HttpError(403, "Development login unavailable.");
						}
					await applyRateLimit(ctx, {
						keyPrefix: "rl:login",
						windowSeconds: getEnvNumber("LOGIN_RATE_LIMIT_WINDOW_SECONDS", 600),
						max: getEnvNumber("LOGIN_RATE_LIMIT_MAX", 10),
						keyBy: "ip"
					});
					const body = await readJson(req, config.maxBodyBytes);
					const name = typeof body?.name == "string" ? body.name.trim() : "";
					if (!name || name.length > 64) {
						logWarn("Auth invalid dev_login name", { name: body?.name });
						throw new HttpError(400, "Missing or invalid name.");
					}
					const player = findOrCreatePlayer(name);
					const token = await issueToken(player.player_id);
					const email = normalizeLoginEmail(name);
					await upsertUser({ id: player.player_id, email, displayName: name });
					return loginResponse(player.player_id, token);
				}

				if (req.method == "POST" && url.pathname == "/v1/auth/login") {
						const address = server.requestIP(req)?.address;
						if (!developmentLoginAllowed(address, req.headers.get("origin"))) {
							throw new HttpError(403, "Development login unavailable.");
						}
					await applyRateLimit(ctx, {
						keyPrefix: "rl:login",
						windowSeconds: getEnvNumber("LOGIN_RATE_LIMIT_WINDOW_SECONDS", 600),
						max: getEnvNumber("LOGIN_RATE_LIMIT_MAX", 10),
						keyBy: "ip"
					});
					const body = await readJson(req, config.maxBodyBytes);
					const emailRaw = typeof body?.email == "string" ? body.email.trim() : "";
					const nameRaw = typeof body?.name == "string" ? body.name.trim() : "";
					const displayName = nameRaw || (emailRaw ? emailRaw.split("@")[0] : "");
					if (!displayName) {
						throw new HttpError(400, "Missing email or name.");
					}
					const player = findOrCreatePlayer(displayName);
					const email = emailRaw ? emailRaw.toLowerCase() : normalizeLoginEmail(displayName);
					await upsertUser({ id: player.player_id, email, displayName });
					if (await isUserDisabled(player.player_id)) {
						throw new HttpError(403, "User disabled.");
					}
					const fingerprint = typeof body?.fingerprint == "string" ? body.fingerprint : undefined;
					const pair = await issueTokenPair(
						player.player_id,
						ACCESS_TTL_MS,
						REFRESH_TTL_MS,
						fingerprint
					);
					return tokenPairResponse(pair.accessToken, pair.refreshToken);
				}

				if (req.method == "POST" && url.pathname == "/v1/auth/refresh") {
					await applyRateLimit(ctx, {
						keyPrefix: "rl:refresh",
						windowSeconds: getEnvNumber("REFRESH_RATE_LIMIT_WINDOW_SECONDS", 600),
						max: getEnvNumber("REFRESH_RATE_LIMIT_MAX", 20),
						keyBy: "ip"
					});
					const body = await readJson(req, config.maxBodyBytes);
					const refreshToken =
						typeof body?.refresh_token == "string" ? body.refresh_token.trim() : "";
					if (!refreshToken) {
						throw new HttpError(400, "Missing refresh_token.");
					}
					const fingerprint = typeof body?.fingerprint == "string" ? body.fingerprint : undefined;
					const rotated = await rotateRefreshToken(refreshToken, REFRESH_TTL_MS, fingerprint);
					if (!rotated) {
						throw new HttpError(401, "Invalid refresh token.");
					}
					if (await isUserDisabled(rotated.record.userId)) {
						throw new HttpError(403, "User disabled.");
					}
					const accessToken = await issueAccessToken(rotated.record.userId, ACCESS_TTL_MS);
					return tokenPairResponse(accessToken, rotated.refreshToken);
				}

				if (req.method == "POST" && url.pathname == "/v1/auth/logout") {
					const body = await readJson(req, config.maxBodyBytes);
					const refreshToken =
						typeof body?.refresh_token == "string" ? body.refresh_token.trim() : "";
					if (refreshToken) {
						await revokeRefreshToken(refreshToken);
					}
					const accessToken = extractToken(req);
					if (accessToken) {
						await revokeAccessToken(accessToken);
					}
					return jsonResponse({ ok: true, server_time_unix_ms: Date.now() });
				}

				if (req.method == "POST" && url.pathname == "/auth/logout") {
					const token = extractToken(req);
					if (!token) {
						throw new HttpError(401, "Missing auth token.");
					}
					await revokeSession(token);
					await revokeAccessToken(token);
					return jsonResponse({ ok: true, server_time_unix_ms: Date.now() });
				}

				if (url.pathname == "/player/state") {
					const playerId = await requireAuth(req, ctx);
					return db.transaction(() => {
					const state = ensurePlayerState(playerId);
					const now = Date.now();
					const runtime = ensureLabRuntime(state);
					let changed = cleanupLabRuntime(runtime, now);
					changed = autoCompleteResearch(state, now) || changed;
					changed = refreshWorldPlayer(state.world, now) || changed;
					if (changed) {
						state.updated_at = now;
						updatePlayerStmt.run(JSON.stringify(state), now, playerId);
					}
					return stateResponse(state);
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/combat/rewards/claim") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, { keyPrefix: "rl:action", windowSeconds: EXPENSIVE_RATE_WINDOW, max: EXPENSIVE_RATE_MAX, keyBy: "user", userId: playerId });
					const body = await readJson(req, config.maxBodyBytes);
					const matchId = typeof body?.match_id === "string" ? body.match_id.trim().toLowerCase() : "";
					const actionId = typeof body?.client_action_id === "string" ? body.client_action_id.trim().toLowerCase() : "";
					const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
					if (!uuid.test(matchId) || !uuid.test(actionId)) throw new HttpError(400, "match_id and client_action_id must be UUIDs.");
					const payload = { match_id: matchId };
					const result = claimVerifiedCombatReward(db, matchId, playerId, (reward, duplicate) => {
						const prior = getIdempotentState(playerId, actionId, "COMBAT_REWARD_CLAIM", payload);
						if (prior && !duplicate) throw new HttpError(409, "Inconsistent combat reward action.");
						const state = prior ?? ensurePlayerState(playerId);
						const now = Date.now();
						if (!duplicate && reward) {
							if (!isValidResourceId(reward.resource_id)) throw new HttpError(400, "Unknown reward resource.");
							const before = { ...state.wallet };
							applyWalletGrant(state.wallet, { [reward.resource_id]: reward.amount });
							assertWalletInvariant(state.wallet);
							state.updated_at = now;
							updatePlayerStmt.run(JSON.stringify(state), now, playerId);
							auditWalletMutation(playerId, computeWalletDelta(before, state.wallet), "COMBAT_REWARD_CLAIM", matchId, now);
						}
						if (!prior) insertActionStmt.run(playerId, actionId, "COMBAT_REWARD_CLAIM", JSON.stringify(payload), JSON.stringify(state), now);
						return state;
					});
					return stateResponseExtra(result.state, { match_id: matchId, reward: result.reward, duplicate: result.duplicate });
				}

				if (req.method == "POST" && url.pathname == "/player/action") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:action",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					const actionType =
						typeof body?.action_type == "string" ? body.action_type.trim() : "";
					let payload = body?.payload ?? {};
					const clientTimeRaw = body?.client_time_unix_ms;
					const clientTime =
						typeof clientTimeRaw == "number" ? clientTimeRaw : Number(clientTimeRaw ?? 0);
					if (!clientActionId || !actionType || clientActionId.length > 64) {
						console.warn("Action: missing client_action_id/action_type", body);
						throw new HttpError(400, "Missing client_action_id or action_type.");
					}
					if (!Number.isFinite(clientTime)) {
						console.warn("Action: missing or invalid client_time_unix_ms", clientTimeRaw);
					}
					void clientTime;
					if (!payload || typeof payload != "object") {
						console.warn("Action: payload must be an object");
						payload = {};
					}
					const debugBypass = isDebugBypass(req);
					const result = db.transaction(() => {
						const already = getActionStmt.get(playerId, clientActionId) as { action_type: string; payload_json: string; result_state_json: string | null } | undefined;
						if (already) {
							let previousPayload: unknown;
							try { previousPayload = JSON.parse(already.payload_json); } catch { throw new HttpError(409, "Cannot verify previous action payload."); }
							if (already.action_type !== actionType || canonicalActionPayload(previousPayload) !== canonicalActionPayload(payload)) throw new HttpError(409, "Action ID already used with different content.");
							return { state: ensurePlayerState(playerId), duplicate: true };
						}
						const state = ensurePlayerState(playerId);
						const updated = applyAction(state, actionType, payload, clientActionId, debugBypass);
						if (updated.error) throw new HttpError(400, updated.error);
						const walletDelta = computeWalletDelta(state.wallet, updated.state.wallet);
						checkSuspiciousDelta(playerId, walletDelta, actionType, clientActionId);
						const invariantError = getWalletInvariantError(updated.state.wallet);
						if (invariantError) throw new HttpError(400, invariantError);
						const now = Date.now();
						updated.state.updated_at = now;
						assertWalletInvariant(updated.state.wallet);
						updatePlayerStmt.run(JSON.stringify(updated.state), now, playerId);
						insertActionStmt.run(
							playerId,
							clientActionId,
							actionType,
							JSON.stringify(payload ?? {}),
							JSON.stringify(updated.state),
							now
						);
						auditWalletMutation(playerId, walletDelta, actionType, clientActionId, now);
						return { state: updated.state, duplicate: false };
					}).immediate();
					if (result.duplicate) return stateResponseExtra(result.state, { duplicate: true });
					void enqueueJob("audit_snapshot", {
						player_id: playerId,
						action_type: actionType,
						at: Date.now()
					});
					broadcast({ type: "player_action", player_id: playerId, action_type: actionType });
					return stateResponse(result.state);
				}

				if (req.method == "GET" && url.pathname == "/market/orders") {
					const resourceIdRaw = url.searchParams.get("resource_id");
					const typeRaw = url.searchParams.get("type");
					const statusRaw = url.searchParams.get("status");
					const sellerRaw = url.searchParams.get("seller_id");
					const resourceId = resourceIdRaw ? resourceIdRaw.trim() : "";
					if (resourceId && !isValidResourceId(resourceId)) {
						console.warn("Market: invalid resource_id", resourceId);
						throw new HttpError(400, "Unknown resource_id.");
					}
					let type = typeRaw ? typeRaw.trim().toUpperCase() : "";
					if (type && type != MARKET_TYPE_SELL && type != MARKET_TYPE_BUY) {
						console.warn("Market: invalid type", typeRaw);
						throw new HttpError(400, "Invalid order type.");
					}
					let status = statusRaw ? statusRaw.trim().toUpperCase() : MARKET_STATUS_OPEN;
					if (status && status != MARKET_STATUS_OPEN && status != MARKET_STATUS_FILLED && status != MARKET_STATUS_CANCELED) {
						console.warn("Market: invalid status", statusRaw);
						throw new HttpError(400, "Invalid status.");
					}
					const sellerId = sellerRaw ? sellerRaw.trim() : "";
					const resourceParam = resourceId || null;
					const typeParam = type || null;
					const statusParam = status || null;
					const sellerParam = sellerId || null;
					const rows = listOrdersStmt.all(
						resourceParam,
						resourceParam,
						typeParam,
						typeParam,
						statusParam,
						statusParam,
						sellerParam,
						sellerParam,
						MARKET_LIST_LIMIT
					) as Array<Record<string, any>>;
					const orders = rows.map((row) => {
						const amount = clampAmount(row.amount);
						const remaining = getOrderRemaining(String(row.order_id), amount);
						return {
							order_id: row.order_id,
							seller_id: row.seller_id,
							type: row.type,
							resource_id: row.resource_id,
							amount,
							remaining,
							price_resource_id: row.price_resource_id,
							price_amount: clampAmount(row.price_amount),
							fee_bps: clampInt(row.fee_bps, 0, 10_000),
							status: row.status,
							created_at: row.created_at
						};
					});
					return jsonResponse({ ok: true, orders });
				}

				if (req.method == "POST" && url.pathname == "/market/order") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:market",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Market: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const stored = getIdempotentState(playerId, clientActionId, "MARKET_ORDER", body);
					const orderId = makeOrderId(playerId, clientActionId);
					if (stored) {
						return stateResponseExtra(stored, { order_id: orderId });
					}
					const existingOrder = getOrderStmt.get(orderId) as Record<string, any> | undefined;
					if (existingOrder) {
						const current = ensurePlayerState(playerId);
						return stateResponseExtra(current, { order_id: orderId });
					}
					let type =
						typeof body?.type == "string" && body.type.trim() != ""
							? body.type.trim().toUpperCase()
							: MARKET_TYPE_SELL;
					if (type != MARKET_TYPE_SELL) {
						console.warn("Market: unsupported order type", type);
						throw new HttpError(400, "Only SELL orders are supported.");
					}
					const resourceId =
						typeof body?.resource_id == "string" ? body.resource_id.trim() : "";
					if (!resourceId || !isValidResourceId(resourceId)) {
						console.warn("Market: invalid resource_id", resourceId);
						throw new HttpError(400, "Unknown resource_id.");
					}
					let priceResourceId =
						typeof body?.price_resource_id == "string" ? body.price_resource_id.trim() : "";
					if (!priceResourceId) {
						priceResourceId = "essence";
					}
					if (!isValidResourceId(priceResourceId)) {
						console.warn("Market: invalid price_resource_id", priceResourceId);
						throw new HttpError(400, "Unknown price_resource_id.");
					}
					const amount = clampInt(body?.amount ?? 0, 0, MARKET_MAX_AMOUNT);
					if (amount <= 0 || amount > MARKET_MAX_AMOUNT) {
						console.warn("Market: invalid amount", body?.amount);
						throw new HttpError(400, "Invalid amount.");
					}
					const priceAmount = clampInt(body?.price_amount ?? 0, 0, MARKET_MAX_PRICE);
					if (priceAmount <= 0 || priceAmount > MARKET_MAX_PRICE) {
						console.warn("Market: invalid price_amount", body?.price_amount);
						throw new HttpError(400, "Invalid price_amount.");
					}
					const feeBps = getMarketFeeBps();
					if (isSuspiciousAmount(amount) || isSuspiciousAmount(priceAmount) || isSuspiciousAmount(amount * priceAmount)) {
						logSuspiciousAction(playerId, { [resourceId]: -amount }, "MARKET_ORDER", orderId);
						throw new HttpError(400, "Suspicious order amount.");
					}
					const now = Date.now();
					let state: PlayerState | null = null;
					db.transaction(() => {
						state = ensurePlayerState(playerId);
						const beforeWallet = cloneWallet(state.wallet);
						const available = clampAmount(state.wallet[resourceId] ?? 0);
						if (available < amount) {
							throw new HttpError(400, "Insufficient resources.");
						}
						state.wallet[resourceId] = available - amount;
						addEscrow(playerId, resourceId, amount);
						insertOrderStmt.run(
							orderId,
							playerId,
							type,
							resourceId,
							amount,
							priceResourceId,
							priceAmount,
							feeBps,
							MARKET_STATUS_OPEN,
							now
						);
						assertWalletInvariant(state.wallet);
						state.updated_at = now;
						updatePlayerStmt.run(JSON.stringify(state), now, playerId);
						insertActionStmt.run(
							playerId,
							clientActionId,
							"MARKET_ORDER",
							JSON.stringify(body ?? {}),
							JSON.stringify(state),
							now
						);
						const delta = computeWalletDelta(beforeWallet, state.wallet);
						auditWalletMutation(playerId, delta, "MARKET_ORDER", orderId, now);
					})();
					if (!state) {
						throw new HttpError(500, "Failed to resolve seller state.");
					}
					return stateResponseExtra(state, { order_id: orderId });
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/market/cancel") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:market",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Market: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const stored = getIdempotentState(playerId, clientActionId, "MARKET_CANCEL", body);
					if (stored) {
						return stateResponse(stored);
					}
					const orderId =
						typeof body?.order_id == "string" ? body.order_id.trim() : "";
					if (!orderId) {
						console.warn("Market: missing order_id", body);
						throw new HttpError(400, "Missing order_id.");
					}
					const order = getOrderStmt.get(orderId) as Record<string, any> | undefined;
					if (!order) {
						throw new HttpError(404, "Order not found.");
					}
					if (order.seller_id != playerId) {
						throw new HttpError(403, "Cannot cancel another seller's order.");
					}
					if (String(order.status).toUpperCase() != MARKET_STATUS_OPEN) {
						throw new HttpError(400, "Order is not open.");
					}
					const totalAmount = clampAmount(order.amount);
					const now = Date.now();
					let state: PlayerState | null = null;
					db.transaction(() => {
						state = ensurePlayerState(playerId);
						const beforeWallet = cloneWallet(state.wallet);
						updateOrderStatusStmt.run(MARKET_STATUS_CANCELED, orderId);
						const remaining = getOrderRemaining(orderId, totalAmount);
						if (remaining > 0) {
							if (!subtractEscrow(playerId, order.resource_id, remaining)) {
								throw new HttpError(400, "Escrow mismatch.");
							}
							state.wallet[order.resource_id] = clampAmount(state.wallet[order.resource_id] ?? 0) + remaining;
						}
						assertWalletInvariant(state.wallet);
						state.updated_at = now;
						updatePlayerStmt.run(JSON.stringify(state), now, playerId);
						insertActionStmt.run(
							playerId,
							clientActionId,
							"MARKET_CANCEL",
							JSON.stringify(body ?? {}),
							JSON.stringify(state),
							now
						);
						const delta = computeWalletDelta(beforeWallet, state.wallet);
						auditWalletMutation(playerId, delta, "MARKET_CANCEL", orderId, now);
					})();
					if (!state) {
						throw new HttpError(500, "Failed to resolve seller state.");
					}
					return stateResponse(state);
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/market/buy") {
					const buyerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:market",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: buyerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Market: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const stored = getIdempotentState(buyerId, clientActionId, "MARKET_BUY", body);
					if (stored) {
						return stateResponse(stored);
					}
					const orderId =
						typeof body?.order_id == "string" ? body.order_id.trim() : "";
					if (!orderId) {
						console.warn("Market: missing order_id", body);
						throw new HttpError(400, "Missing order_id.");
					}
					const requestedAmount = clampInt(body?.amount ?? 0, 0, MARKET_MAX_AMOUNT);
					if (requestedAmount <= 0 || requestedAmount > MARKET_MAX_AMOUNT) {
						console.warn("Market: invalid buy amount", body?.amount);
						throw new HttpError(400, "Invalid amount.");
					}
					const previewOrder = getOrderStmt.get(orderId) as Record<string, any> | undefined;
					if (!previewOrder) {
						throw new HttpError(404, "Order not found.");
					}
					const previewUnitPrice = clampInt(previewOrder.price_amount ?? 0, 0, MARKET_MAX_PRICE);
					rejectSuspiciousMarketBuy(
						buyerId,
						orderId,
						String(previewOrder.resource_id || ""),
						String(previewOrder.price_resource_id || "essence"),
						requestedAmount,
						previewUnitPrice
					);
					let buyerState: PlayerState | null = null;
					let sellerState: PlayerState | null = null;
					const now = Date.now();
					db.transaction(() => {
						const order = getOrderStmt.get(orderId) as Record<string, any> | undefined;
						if (!order) {
							throw new HttpError(404, "Order not found.");
						}
						if (String(order.status).toUpperCase() != MARKET_STATUS_OPEN) {
							throw new HttpError(400, "Order is not open.");
						}
						if (String(order.type).toUpperCase() != MARKET_TYPE_SELL) {
							throw new HttpError(400, "Only SELL orders are supported.");
						}
						if (order.seller_id == buyerId) {
							throw new HttpError(400, "Cannot buy your own order.");
						}
						const resourceId = String(order.resource_id);
						if (!isValidResourceId(resourceId)) {
							throw new HttpError(400, "Unknown resource_id.");
						}
						const priceResourceId = String(order.price_resource_id || "essence");
						if (!isValidResourceId(priceResourceId)) {
							throw new HttpError(400, "Unknown price_resource_id.");
						}
						const totalAmount = clampAmount(order.amount);
						const remaining = getOrderRemaining(orderId, totalAmount);
						if (remaining <= 0) {
							updateOrderStatusStmt.run(MARKET_STATUS_FILLED, orderId);
							throw new HttpError(400, "Order already filled.");
						}
						const fillAmount = Math.min(remaining, requestedAmount);
						if (fillAmount <= 0) {
							throw new HttpError(400, "Invalid amount.");
						}
						const unitPrice = clampInt(order.price_amount ?? 0, 0, MARKET_MAX_PRICE);
						if (unitPrice <= 0) {
							throw new HttpError(400, "Invalid price.");
						}
						const totalPrice = unitPrice * fillAmount;
						if (totalPrice <= 0 || totalPrice > MARKET_MAX_PRICE * MARKET_MAX_AMOUNT) {
							throw new HttpError(400, "Invalid total price.");
						}
						const feeBps = clampInt(order.fee_bps ?? 0, 0, 10_000);
						const fee = Math.floor((totalPrice * feeBps) / 10_000);
						buyerState = ensurePlayerState(buyerId);
						sellerState = ensurePlayerState(order.seller_id);
						const beforeBuyer = cloneWallet(buyerState.wallet);
						const beforeSeller = cloneWallet(sellerState.wallet);
						const buyerWallet = buyerState.wallet;
						const sellerWallet = sellerState.wallet;
						if (clampAmount(buyerWallet[priceResourceId] ?? 0) < totalPrice) {
							throw new HttpError(400, "Insufficient funds.");
						}
						buyerWallet[priceResourceId] = clampAmount(buyerWallet[priceResourceId] ?? 0) - totalPrice;
						applyWalletGrant(buyerWallet, { [resourceId]: fillAmount });
						const sellerCredit = Math.max(0, totalPrice - fee);
						sellerWallet[priceResourceId] = clampAmount(sellerWallet[priceResourceId] ?? 0) + sellerCredit;
						if (!subtractEscrow(order.seller_id, resourceId, fillAmount)) {
							throw new HttpError(400, "Escrow mismatch.");
						}
						const fillId = crypto.randomUUID();
						insertFillStmt.run(fillId, orderId, buyerId, fillAmount, totalPrice, fee, now);
						if (fillAmount >= remaining) {
							updateOrderStatusStmt.run(MARKET_STATUS_FILLED, orderId);
						}
						assertWalletInvariant(buyerWallet);
						assertWalletInvariant(sellerWallet);
						buyerState.updated_at = now;
						sellerState.updated_at = now;
						updatePlayerStmt.run(JSON.stringify(buyerState), now, buyerId);
						updatePlayerStmt.run(JSON.stringify(sellerState), now, order.seller_id);
						insertActionStmt.run(
							buyerId,
							clientActionId,
							"MARKET_BUY",
							JSON.stringify(body ?? {}),
							JSON.stringify(buyerState),
							now
						);
						const buyerDelta = computeWalletDelta(beforeBuyer, buyerWallet);
						const sellerDelta = computeWalletDelta(beforeSeller, sellerWallet);
						auditWalletMutation(buyerId, buyerDelta, "MARKET_BUY_BUYER", orderId, now);
						auditWalletMutation(order.seller_id, sellerDelta, "MARKET_BUY_SELLER", orderId, now);
					})();
					if (!buyerState) {
						throw new HttpError(500, "Failed to resolve buyer state.");
					}
					return stateResponse(buyerState);
					}).immediate();
				}

				if (req.method == "GET" && url.pathname == "/trade/npc/offers") {
					const playerId = await requireAuth(req, ctx);
					const now = Date.now();
					return jsonResponse({ ok: true, server_time_unix_ms: now, ...npcTradeOffers(ensureLabRuntime(ensurePlayerState(playerId)), now) });
				}
				if (req.method == "GET" && url.pathname == "/trade/jobs") {
					const outputResourceRaw = url.searchParams.get("output_resource_id");
					const statusRaw = url.searchParams.get("status");
					const outputResource = outputResourceRaw ? outputResourceRaw.trim() : "";
					if (outputResource && !isValidResourceId(outputResource)) {
						console.warn("Trade: invalid output_resource_id", outputResource);
						throw new HttpError(400, "Unknown output_resource_id.");
					}
					let status = statusRaw ? statusRaw.trim().toUpperCase() : TRADE_JOB_STATUS_OPEN;
					if (status && status != TRADE_JOB_STATUS_OPEN && status != TRADE_JOB_STATUS_CLOSED) {
						console.warn("Trade: invalid status", statusRaw);
						throw new HttpError(400, "Invalid status.");
					}
					const outputParam = outputResource || null;
					const statusParam = status || null;
					const rows = listTradeJobsStmt.all(
						outputParam,
						outputParam,
						statusParam,
						statusParam,
						TRADE_LIST_LIMIT
					) as Array<Record<string, any>>;
					const jobs = rows.map((row) => {
						const pendingRow = countTradeRunsStmt.get(row.job_id, TRADE_RUN_STATUS_PENDING) as
							| { count: number }
							| undefined;
						const pending = pendingRow ? clampInt(pendingRow.count, 0, TRADE_MAX_QUEUE) : 0;
						return {
							job_id: row.job_id,
							provider_id: row.provider_id,
							input_resource_id: row.input_resource_id,
							input_amount: clampAmount(row.input_amount),
							output_resource_id: row.output_resource_id,
							output_min: clampAmount(row.output_min),
							output_max: clampAmount(row.output_max),
							duration_sec: clampInt(row.duration_sec, 0, TRADE_MAX_DURATION_SEC),
							commission_resource_id: row.commission_resource_id,
							commission_amount: clampAmount(row.commission_amount),
							queue_limit: clampInt(row.queue_limit, 1, TRADE_MAX_QUEUE),
							status: row.status,
							created_at: row.created_at,
							pending_count: pending
						};
					});
					return jsonResponse({ ok: true, jobs });
				}

				if (req.method == "POST" && url.pathname == "/trade/jobs") {
					const providerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:trade",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: providerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Trade: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const existing = getIdempotentState(providerId, clientActionId, "TRADE_JOB_CREATE", body);
					const jobId = makeTradeJobId(providerId, clientActionId);
					if (existing) {
						return stateResponseExtra(existing, { job_id: jobId });
					}
					const createResult = createTradeJob(providerId, clientActionId, body);
					if (createResult.error || !createResult.state || !createResult.jobId) {
						throw new HttpError(400, createResult.error || "Failed to create trade job.");
					}
					return stateResponseExtra(createResult.state, { job_id: createResult.jobId });
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/trade/submit") {
					const customerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:trade",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: customerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Trade: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					getIdempotentState(customerId, clientActionId, "TRADE_SUBMIT", body);
					const submitResult = submitTradeRun(customerId, clientActionId, body);
					if (submitResult.error || !submitResult.state) {
						throw new HttpError(400, submitResult.error || "Failed to submit trade.");
					}
					return stateResponseExtra(submitResult.state, {
						run_id: submitResult.runId,
						completes_at: submitResult.completesAt
					});
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/trade/claim") {
					const customerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:trade",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: customerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Trade: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					getIdempotentState(customerId, clientActionId, "TRADE_CLAIM", body);
					const claimResult = claimTradeRun(customerId, clientActionId, body);
					if (claimResult.error || !claimResult.state) {
						throw new HttpError(400, claimResult.error || "Failed to claim trade.");
					}
					return stateResponseExtra(claimResult.state, {
						output_amount: claimResult.outputAmount
					});
					}).immediate();
				}

				if (req.method == "GET" && url.pathname == "/world/state") {
					const playerId = await tryAuth(req, ctx);
					return db.transaction(() => {
					const now = Date.now();
					const worldState = ensureWorldState(now);
					if (playerId) {
						const state = ensurePlayerState(playerId);
						const world = ensurePlayerWorld(state, now);
						if (refreshWorldPlayer(world, now)) {
							state.updated_at = now;
							updatePlayerStmt.run(JSON.stringify(state), now, playerId);
						}
						return jsonResponse({
							ok: true,
							server_time_unix_ms: now,
							world_state: worldState,
							player_world: world
						});
					}
					return jsonResponse({
						ok: true,
						server_time_unix_ms: now,
						world_state: worldState
					});
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/world/enter") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:world",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("World: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const duplicate = getIdempotentState(playerId, clientActionId, "WORLD_ENTER", body);
					if (duplicate) {
						const zoneId = String(body.zone_id ?? "").trim();
						const sessionId = makeWorldSessionId(playerId, clientActionId, zoneId);
						return stateResponseExtra(duplicate, { session_id: sessionId, zone_id: zoneId, modifiers: duplicate.world.sessions[sessionId]?.modifiers ?? [], duplicate: true });
					}
					const debugBypass = isDebugBypass(req);
					const result = enterWorldSession(playerId, clientActionId, body, debugBypass);
					if (result.error || !result.state) {
						throw new HttpError(400, result.error || "Failed to enter world zone.");
					}
					return stateResponseExtra(result.state, {
						session_id: result.sessionId,
						zone_id: result.zoneId,
						modifiers: result.modifiers
					});
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/world/farm") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:world",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("World: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const duplicate = getIdempotentState(playerId, clientActionId, "WORLD_FARM", body);
					if (duplicate) {
						const sessionId = String(body.session_id ?? "");
						const zoneId = duplicate.world.sessions[sessionId]?.zone_id;
						return stateResponseExtra(duplicate, { session_id: sessionId, drops: {}, heat: zoneId ? duplicate.world.zone_progress[zoneId]?.heat ?? 0 : 0, stamina: duplicate.world.stamina, duplicate: true });
					}
					const result = farmWorldSession(playerId, clientActionId, body);
					if (result.error || !result.state) {
						throw new HttpError(400, result.error || "Failed to farm world zone.");
					}
					return stateResponseExtra(result.state, {
						session_id: result.sessionId,
						drops: result.drops,
						heat: result.heat,
						stamina: result.stamina
					});
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/world/claim") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:world",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("World: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const duplicate = getIdempotentState(playerId, clientActionId, "WORLD_CLAIM", body);
					if (duplicate) return stateResponseExtra(duplicate, { session_id: body.session_id, claimed: {}, duplicate: true });
					const result = claimWorldSession(playerId, clientActionId, body);
					if (result.error || !result.state) {
						throw new HttpError(400, result.error || "Failed to claim world loot.");
					}
					return stateResponseExtra(result.state, {
						session_id: result.sessionId,
						claimed: result.claimed
					});
					}).immediate();
				}

				if (req.method == "GET" && url.pathname == "/world/boss-hunts") {
					return jsonResponse(soloBossSchedule(Date.now()));
				}
				if (req.method == "GET" && url.pathname == "/boss/state") {
					return db.transaction(() => {
					const now = Date.now();
					const worldState = ensureWorldState(now);
					return jsonResponse({
						ok: true,
						server_time_unix_ms: now,
						bosses: worldState.bosses
					});
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/boss/attack") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:boss",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Boss: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const duplicate = getIdempotentState(playerId, clientActionId, "BOSS_ATTACK", body);
					if (duplicate) {
						const boss = getBossFromWorld(ensureWorldState(Date.now()), String(body.boss_id ?? ""));
						return stateResponseExtra(duplicate, boss ? { duplicate: true, damage: 0, boss_hp: boss.hp, boss_max_hp: boss.max_hp, phase: boss.phase, contributor_score: boss.contributors[playerId] ?? 0, tokens_earned: 0 } : { duplicate: true });
					}
					const ip = getClientIp(req);
					const result = attackBoss(playerId, clientActionId, body, ip);
					if (result.error || !result.state || !result.boss) {
						throw new HttpError(400, result.error || "Failed to attack boss.");
					}
					return stateResponseExtra(result.state, {
						damage: result.damage ?? 0,
						boss_hp: result.boss.hp,
						boss_max_hp: result.boss.max_hp,
						phase: result.boss.phase,
						contributor_score: result.contributorScore ?? 0,
						tokens_earned: result.tokens ?? 0
					});
					}).immediate();
				}

				if (req.method == "POST" && url.pathname == "/boss/claim_rewards") {
					const playerId = await requireAuth(req, ctx);
					await applyRateLimit(ctx, {
						keyPrefix: "rl:boss",
						windowSeconds: EXPENSIVE_RATE_WINDOW,
						max: EXPENSIVE_RATE_MAX,
						keyBy: "user",
						userId: playerId
					});
					const body = await readJson(req, config.maxBodyBytes);
					const clientActionId =
						typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
					if (!clientActionId || clientActionId.length > 64) {
						console.warn("Boss: missing client_action_id", body);
						throw new HttpError(400, "Missing client_action_id.");
					}
					return db.transaction(() => {
					const duplicate = getIdempotentState(playerId, clientActionId, "BOSS_CLAIM", body);
					if (duplicate) return stateResponseExtra(duplicate, { claimed: {}, duplicate: true });
					const result = claimBossRewards(playerId, clientActionId, body);
					if (result.error || !result.state) {
						throw new HttpError(400, result.error || "Failed to claim boss rewards.");
					}
					return stateResponseExtra(result.state, {
						tier: result.tier ?? "none",
						claimed: result.claimed ?? {}
					});
					}).immediate();
				}

				if (req.method == "GET" && url.pathname == "/static/version") {
					return await staticVersionResponse();
				}

				if (req.method == "GET" && url.pathname == "/health") {
					return await healthResponse();
				}

				if (req.method == "GET" && url.pathname == "/metrics") {
					return await metricsResponse();
				}

				return jsonResponse({ error: "Not found" }, 404);
				})();
				const finalRes = applyResponseHeaders(res, ctx, corsHeaders);
				recordRequest(finalRes.status, Date.now() - ctx.startAt);
				logInfo("request", {
					req_id: ctx.requestId,
					method: req.method,
					path: ctx.path,
					status: finalRes.status,
					latency_ms: Date.now() - ctx.startAt
				});
				return finalRes;
			} catch (err) {
				recordError();
				const sqliteBusy = typeof err === "object" && err !== null && typeof (err as { code?: unknown }).code === "string" && String((err as { code: string }).code).startsWith("SQLITE_BUSY");
				const message = sqliteBusy ? "Database temporarily busy; retry the same action ID." : err instanceof HttpError || err instanceof CombatRewardError || err instanceof AccountStatusUnavailableError ? err.message : "Internal server error";
				const status = sqliteBusy || err instanceof AccountStatusUnavailableError ? 503 : err instanceof HttpError || err instanceof CombatRewardError ? err.status : 500;
				const res = errorResponse(message, status);
				const finalRes = applyResponseHeaders(res, ctx, corsHeaders);
				recordRequest(finalRes.status, Date.now() - ctx.startAt);
				logError("request error", {
					req_id: ctx.requestId,
					method: req.method,
					path: ctx.path,
					status,
					error: String(err)
				});
				return finalRes;
			}
		},
		websocket: {
			open(ws) {
				sockets.add(ws);
				ws.send(JSON.stringify({ type: "hello", server_time: Date.now() }));
			},
			message(ws, message) {
				if (typeof message == "string" && message.toLowerCase() == "ping") {
					ws.send("pong");
				}
			},
			close(ws) {
				sockets.delete(ws);
			}
		}
	});

	console.log(`Backend listening on http://${config.host}:${config.port}`);
	void server;
}

type StaticData = {
	itemIds: Set<string>;
	homunculusIds: Set<string>;
	mutationIds: Set<string>;
	itemRarities: Record<string, string>;
	resources: Set<string>;
	buildings: Record<string, any>;
	hqPaths: string[];
	balance: Record<string, any>;
	research: Record<string, ResearchNode>;
	researchFlags: Set<string>;
	zones: Record<string, ZoneDef>;
	bosses: Record<string, BossDef>;
	soloBosses: SoloBossCatalog;
};

function loadStaticData(): StaticData {
	const staticDir = resolve(import.meta.dir, "..", "..", "data", "static");
	const itemsRaw = JSON.parse(readFileSync(resolve(staticDir, "..", "items.json"), "utf8"));
	const homunculiRaw = JSON.parse(readFileSync(resolve(staticDir, "..", "homunculi.json"), "utf8"));
	const mutationsRaw = JSON.parse(readFileSync(resolve(staticDir, "mutations.json"), "utf8"));
	const itemIds = new Set<string>((Array.isArray(itemsRaw.items) ? itemsRaw.items : []).map((item: any) => item.id).filter((id: unknown): id is string => typeof id === "string"));
	const itemRarities: Record<string, string> = Object.fromEntries((Array.isArray(itemsRaw.items) ? itemsRaw.items : []).filter((item: any) => typeof item.id === "string" && typeof item.rarity === "string").map((item: any) => [item.id, item.rarity]));
	const resources = loadResourceIds(resolve(staticDir, "resources.json"));
	const buildingsData = loadBuildings(resolve(staticDir, "buildings.json"));
	const balance = loadBalance(resolve(staticDir, "balance.json"));
	const researchData = loadResearch(resolve(staticDir, "research.json"));
	const zones = loadZones(resolve(staticDir, "zones.json"));
	const bosses = loadBosses(resolve(staticDir, "bosses.json"));
	return {
		itemIds,
		homunculusIds: new Set<string>((homunculiRaw.homunculi ?? []).map((entry: any) => entry.id).filter((id: unknown): id is string => typeof id === "string")),
		mutationIds: new Set<string>((mutationsRaw.mutations ?? []).map((entry: any) => entry.id).filter((id: unknown): id is string => typeof id === "string")),
		itemRarities,
		resources: resources.ids,
		buildings: buildingsData.buildings,
		hqPaths: buildingsData.hqPaths,
		balance,
		research: researchData.nodes,
		researchFlags: researchData.flags,
		zones,
		bosses,
		soloBosses: loadSoloBossCatalog(resolve(staticDir, "solo_bosses.json"), resolve(staticDir, "..", "spells.json"))
	};
}

type SoloBoss = { id: string; name: string; tier: string; texture_id: string; texture_variants?: string[]; minion_texture_id?: string; hp_mult: number; attack_mult: number; minions: number; shield_reduction: number; shield_turns: number; fury_mult: number; shield_heal_ratio: number; signature_pool: string[] };
type SoloBossCatalog = { rotation: { interval_seconds: number; window_seconds: number; common_cooldown_seconds: number; weights: Record<string, number> }; bosses: SoloBoss[] };

function loadSoloBossCatalog(path: string, spellsPath: string): SoloBossCatalog {
	const catalog = readJsonFile(path), spells = readJsonFile(spellsPath);
	const tiers = ["common", "mythic", "rare", "epic", "legendary"];
	const rotation = catalog?.rotation;
	const invalid = () => { throw new Error("Invalid solo boss catalog configuration."); };
	if (!rotation || !Number.isSafeInteger(rotation.interval_seconds) || rotation.interval_seconds !== 10800 || !Number.isSafeInteger(rotation.window_seconds) || rotation.window_seconds !== 2700 || !Number.isSafeInteger(rotation.common_cooldown_seconds) || rotation.common_cooldown_seconds !== 60 || !rotation.weights || Object.keys(rotation.weights).sort().join(",") !== tiers.slice(1).sort().join(",") || tiers.slice(1).some(tier => typeof rotation.weights[tier] !== "number" || !Number.isFinite(rotation.weights[tier]) || rotation.weights[tier] <= 0) || Math.abs(tiers.slice(1).reduce((sum, tier) => sum + rotation.weights[tier], 0) - 1) > 0.000001 || !Array.isArray(catalog?.bosses) || catalog.bosses.length !== 5 || !Array.isArray(spells?.spells)) return invalid();
	const spellIds = new Set(spells.spells.map((spell: any) => spell.id));
	const bossTextures = ["boss_common", "boss_colossus", "boss_leviathan", "tier3boss", "boss_temporal", "ghost_boss"];
	const seenIds = new Set<string>(), seenTiers = new Set<string>();
	for (const boss of catalog.bosses) {
		if (!boss || typeof boss.id !== "string" || !/^hunt_[a-z0-9_]+$/.test(boss.id) || seenIds.has(boss.id) || !tiers.includes(boss.tier) || seenTiers.has(boss.tier) || typeof boss.name !== "string" || !boss.name.trim() || !bossTextures.includes(boss.texture_id) || (boss.texture_variants !== undefined && (!Array.isArray(boss.texture_variants) || boss.texture_variants.length === 0 || new Set(boss.texture_variants).size !== boss.texture_variants.length || !boss.texture_variants.includes(boss.texture_id) || boss.texture_variants.some((id: unknown) => typeof id !== "string" || !bossTextures.includes(id)))) || (boss.minions > 0 ? boss.minion_texture_id !== "summoned-boss" : boss.minion_texture_id !== undefined && boss.minion_texture_id !== "summoned-boss") || [boss.hp_mult, boss.attack_mult, boss.fury_mult].some(value => typeof value !== "number" || !Number.isFinite(value) || value <= 0) || [boss.shield_reduction, boss.shield_heal_ratio].some(value => typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) || !Number.isSafeInteger(boss.minions) || boss.minions < 0 || boss.minions > 2 || !Number.isSafeInteger(boss.shield_turns) || boss.shield_turns < 1 || !Array.isArray(boss.signature_pool) || boss.signature_pool.length === 0 || boss.signature_pool.some((id: unknown) => typeof id !== "string" || !spellIds.has(id))) return invalid();
		seenIds.add(boss.id); seenTiers.add(boss.tier);
	}
	return catalog as SoloBossCatalog;
}

function soloBossSchedule(now: number): object {
	const { rotation, bosses } = staticData.soloBosses;
	const interval = rotation.interval_seconds * 1000, window = rotation.window_seconds * 1000;
	const key = Math.floor(now / interval), start = key * interval, end = start + window;
	const roll = createHmac("sha256", WORLD_SECRET).update(String(key)).digest().readUInt32BE(0) / 0x100000000;
	let cumulative = 0, chosen = "legendary";
	for (const tier of ["mythic", "rare", "epic", "legendary"]) { cumulative += rotation.weights[tier]; if (roll < cumulative) { chosen = tier; break; } }
	const special = bosses.find(boss => boss.tier === chosen)!;
	return { server_time_unix_ms: now, rotation_key: key, current_special_id: special.id, next_rotation_at: start + interval, special_window_ends_at: end, bosses: bosses.map(boss => ({ ...boss, display_texture_id: boss.texture_variants?.[key % boss.texture_variants.length] ?? boss.texture_id, available: boss.tier === "common" || (boss.id === special.id && now < end), appearance_starts_at: boss.tier === "common" ? null : (boss.id === special.id ? start : null), appearance_ends_at: boss.tier === "common" ? null : (boss.id === special.id ? end : null) })) };
}

function loadResourceIds(path: string): { ids: Set<string> } {
	const fallback = [
		"essence",
		"core",
		"arcane_shard",
		"time_crystal"
	];
	const data = readJsonFile(path);
	if (!data || typeof data != "object") {
		return { ids: new Set(fallback) };
	}
	const list = (data as any).resources;
	if (!Array.isArray(list)) {
		return { ids: new Set(fallback) };
	}
	const ids = new Set<string>();
	for (const entry of list) {
		if (entry && typeof entry.id == "string") {
			ids.add(entry.id);
		}
	}
	return { ids: ids.size > 0 ? ids : new Set(fallback) };
}

function loadBuildings(path: string): { buildings: Record<string, any>; hqPaths: string[] } {
	const fallbackIds = [
		"lab_th",
		"essence_reactor",
		"storage_vault",
		"build_forge",
		"homunculus_vat",
		"ultrahit_tower",
		"experiment_chamber",
		"arcane_archives",
		"sync_nexus",
		"anomaly_containment",
		"trade_hall",
		"world_gate"
	];
	const data = readJsonFile(path);
	if (!data || typeof data != "object") {
		const fallback: Record<string, any> = {};
		for (const id of fallbackIds) {
			fallback[id] = { id };
		}
		return { buildings: fallback, hqPaths: ["Scientific", "Chaotic", "Industrial"] };
	}
	const list = (data as any).buildings;
	const hqPaths = Array.isArray((data as any).hq_paths)
		? (data as any).hq_paths
		: ["Scientific", "Chaotic", "Industrial"];
	const out: Record<string, any> = {};
	if (Array.isArray(list)) {
		for (const entry of list) {
			if (entry && typeof entry.id == "string") {
				out[entry.id] = entry;
			}
		}
	}
	if (Object.keys(out).length == 0) {
		for (const id of fallbackIds) {
			out[id] = { id };
		}
	}
	return { buildings: out, hqPaths };
}

function loadZones(path: string): Record<string, ZoneDef> {
	const fallback = defaultZoneDefs();
	const fallbackMap = new Map<string, ZoneDef>();
	for (const entry of fallback) {
		fallbackMap.set(entry.id, entry);
	}
	const data = readJsonFile(path);
	const list = data && typeof data == "object" ? (data as any).zones : null;
	const out: Record<string, ZoneDef> = {};
	if (Array.isArray(list)) {
		for (const entry of list) {
			if (!entry || typeof entry.id != "string") {
				continue;
			}
			const id = entry.id.trim();
			if (!id || out[id]) {
				continue;
			}
			const name = typeof entry.name == "string" ? entry.name.trim() : id;
			let drops = normalizeDropTable(entry.drops);
			let rareDrops = normalizeDropTable(entry.rare_drops);
			const fallbackZone = fallbackMap.get(id);
			if (Object.keys(drops).length == 0) {
				drops = fallbackZone?.drops ?? { essence: 1 };
			}
			if (Object.keys(rareDrops).length == 0 && fallbackZone?.rare_drops) {
				rareDrops = fallbackZone.rare_drops;
			}
			const modifiers = Array.isArray(entry.modifiers)
				? entry.modifiers
						.map((value: any) => (typeof value == "string" ? value.trim() : ""))
						.filter((value: string) => value.length > 0)
				: fallbackZone?.modifiers ?? [];
			const zone: ZoneDef = {
				id,
				name,
				drops
			};
			if (Object.keys(rareDrops).length > 0) {
				zone.rare_drops = rareDrops;
			}
			if (modifiers.length > 0) {
				zone.modifiers = modifiers;
			}
			out[id] = zone;
		}
	}
	if (Object.keys(out).length == 0) {
		for (const entry of fallback) {
			out[entry.id] = entry;
		}
	}
	return out;
}

function loadBosses(path: string): Record<string, BossDef> {
	const fallback = defaultBossDefs();
	const fallbackMap = new Map<string, BossDef>();
	for (const entry of fallback) {
		fallbackMap.set(entry.id, entry);
	}
	const data = readJsonFile(path);
	const list = data && typeof data == "object" ? (data as any).bosses : null;
	const out: Record<string, BossDef> = {};
	if (Array.isArray(list)) {
		for (const entry of list) {
			if (!entry || typeof entry.id != "string") {
				continue;
			}
			const id = entry.id.trim();
			if (!id || out[id]) {
				continue;
			}
			const name = typeof entry.name == "string" ? entry.name.trim() : id;
			const modifiers = normalizeModifierList(entry.modifiers);
			const maxHp = clampInt(entry.max_hp ?? 0, 0, Number.MAX_SAFE_INTEGER);
			const fallbackBoss = fallbackMap.get(id);
			out[id] = {
				id,
				name,
				modifiers: modifiers.length > 0 ? modifiers : fallbackBoss?.modifiers,
				max_hp: maxHp > 0 ? maxHp : fallbackBoss?.max_hp
			};
		}
	}
	if (Object.keys(out).length == 0) {
		for (const entry of fallback) {
			out[entry.id] = entry;
		}
	}
	return out;
}

function loadBalance(path: string): Record<string, any> {
	const data = readJsonFile(path);
	if (!data || typeof data != "object") {
		return {};
	}
	if ((data as any).balance && typeof (data as any).balance == "object") {
		return (data as any).balance;
	}
	return data as any;
}

function loadResearch(path: string): { nodes: Record<string, ResearchNode>; flags: Set<string> } {
	const fallback = defaultResearchNodes();
	const data = readJsonFile(path);
	const list = data && typeof data == "object" ? (data as any).research : null;
	const nodes: Record<string, ResearchNode> = {};
	if (Array.isArray(list)) {
		for (const entry of list) {
			if (!entry || typeof entry.id != "string") {
				continue;
			}
			const id = entry.id.trim();
			if (!id || nodes[id]) {
				continue;
			}
			const name = typeof entry.name == "string" ? entry.name.trim() : id;
			const flagId = typeof entry.flag_id == "string" ? entry.flag_id.trim() : "";
			const cost = entry.cost && typeof entry.cost == "object" ? entry.cost : {};
			const timeSec = typeof entry.time_sec == "number" ? entry.time_sec : Number(entry.time_sec);
			const requires = Array.isArray(entry.requires) ? entry.requires.filter((v: any) => typeof v == "string") : [];
			if (!flagId || !Number.isFinite(timeSec)) {
				continue;
			}
			nodes[id] = {
				id,
				name,
				flag_id: flagId,
				cost,
				time_sec: Math.max(0, Math.floor(timeSec)),
				requires
			};
		}
	}
	if (Object.keys(nodes).length == 0) {
		for (const entry of fallback) {
			nodes[entry.id] = entry;
		}
	}
	const flags = new Set<string>();
	for (const node of Object.values(nodes)) {
		if (node.flag_id) {
			flags.add(node.flag_id);
		}
	}
	return { nodes, flags };
}

function normalizeDropTable(raw: any): ZoneDropTable {
	const out: ZoneDropTable = {};
	if (!raw || typeof raw != "object") {
		return out;
	}
	for (const [key, value] of Object.entries(raw)) {
		const id = typeof key == "string" ? key.trim() : "";
		if (!id) {
			continue;
		}
		const weight = typeof value == "number" ? value : Number(value);
		if (!Number.isFinite(weight) || weight <= 0) {
			continue;
		}
		out[id] = weight;
	}
	return out;
}

function defaultZoneDefs(): ZoneDef[] {
	return [
		{
			id: "zone_corrupted",
			name: "Corrupted Zone",
			drops: {
				essence: 70,
				arcane_shard: 30
			},
			rare_drops: {
				time_crystal: 10
			},
			modifiers: ["corrupt_fog", "unstable_flux", "spiteful_echoes"]
		},
		{
			id: "zone_crystal",
			name: "Crystal Zone",
			drops: {
				essence: 60,
				core: 25,
				time_crystal: 15
			},
			rare_drops: {
				time_crystal: 4,
				arcane_shard: 6
			},
			modifiers: ["resonant_growth", "shard_bloom", "prismatic_shift"]
		},
		{
			id: "zone_chaos",
			name: "Chaos Zone",
			drops: {
				essence: 50,
				arcane_shard: 40,
				core: 10
			},
			rare_drops: {
				time_crystal: 10
			},
			modifiers: ["entropy_surge", "wild_flux", "rift_winds"]
		}
	];
}

function defaultBossDefs(): BossDef[] {
	return [
		{
			id: "boss_common",
			name: "Common Boss",
			modifiers: ["staggering_roar", "volatile_hide"],
			max_hp: 50000
		},
		{
			id: "boss_colossus",
			name: "Giant Arcane Colossus",
			modifiers: ["arcane_bulwark", "runic_spikes"],
			max_hp: 120000
		},
		{
			id: "boss_leviathan",
			name: "Corrupted Energy Leviathan",
			modifiers: ["corrupt_surge", "void_tide"],
			max_hp: 90000
		},
		{
			id: "boss_temporal",
			name: "Temporal Warden Titan",
			modifiers: ["time_dilation", "chronoshield"],
			max_hp: 150000
		}
	];
}

function defaultResearchNodes(): ResearchNode[] {
	return [
		{
			id: "archive_basics",
			name: "Archive Basics",
			flag_id: "archive_basics",
			cost: { essence: 30 },
			time_sec: 30,
			requires: []
		},
		{
			id: "trade_jobs",
			name: "Trade Jobs",
			flag_id: "unlock_trade_jobs",
			cost: { essence: 80, core: 5 },
			time_sec: 120,
			requires: ["archive_basics"]
		},
		{
			id: "world_zones",
			name: "World Zones",
			flag_id: "unlock_world_zones",
			cost: { essence: 120, arcane_shard: 2 },
			time_sec: 180,
			requires: ["archive_basics"]
		},
		{
			id: "sync_theory",
			name: "Sync Theory",
			flag_id: "unlock_sync",
			cost: { essence: 150, core: 10 },
			time_sec: 240,
			requires: ["unlock_world_zones"]
		},
		{
			id: "anomaly_theory",
			name: "Anomaly Theory",
			flag_id: "unlock_anomalies",
			cost: { essence: 200, arcane_shard: 2 },
			time_sec: 300,
			requires: ["unlock_sync"]
		},
		{
			id: "experiment_cooldown",
			name: "Experiment Cooldown",
			flag_id: "reduce_experiment_cooldown",
			cost: { essence: 100, arcane_shard: 2 },
			time_sec: 180,
			requires: ["archive_basics"]
		},
		{
			id: "storage_protocols",
			name: "Storage Protocols",
			flag_id: "increase_storage_capacity",
			cost: { essence: 110, core: 4 },
			time_sec: 180,
			requires: ["archive_basics"]
		},
		{
			id: "reactor_notes",
			name: "Reactor Notes",
			flag_id: "reactor_efficiency",
			cost: { essence: 90, core: 3 },
			time_sec: 150,
			requires: ["archive_basics"]
		},
		{
			id: "arcane_catalog",
			name: "Arcane Catalog",
			flag_id: "unlock_arcane_catalog",
			cost: { essence: 130, arcane_shard: 3 },
			time_sec: 200,
			requires: ["reactor_efficiency"]
		},
		{
			id: "gateway_studies",
			name: "Gateway Studies",
			flag_id: "unlock_gateway_studies",
			cost: { essence: 160, time_crystal: 1 },
			time_sec: 220,
			requires: ["unlock_world_zones"]
		}
	];
}

function readJsonFile(path: string): any | null {
	try {
		if (!existsSync(path)) {
			console.error(`Static data missing: ${path}`);
			return null;
		}
		const raw = readFileSync(path, "utf8");
		return JSON.parse(raw);
	} catch (err) {
		console.error(`Failed to read JSON: ${path}`, err);
		return null;
	}
}

function normalizeWallet(walletRaw: any): ResourceWallet {
	const wallet: ResourceWallet = {};
	const allowAll = staticData.resources.size == 0;
	if (walletRaw && typeof walletRaw == "object") {
		for (const [key, value] of Object.entries(walletRaw)) {
			if (!allowAll && !staticData.resources.has(key)) {
				continue;
			}
			const amount = clampAmount(value);
			if (amount >= 0) {
				wallet[key] = amount;
			}
		}
	} else if (typeof walletRaw == "number") {
		const amount = clampAmount(walletRaw);
		if (amount > 0) {
			wallet["essence"] = amount;
		}
	}
	if (!allowAll) {
		for (const id of staticData.resources) {
			if (wallet[id] == null) {
				wallet[id] = 0;
			}
		}
	}
	return wallet;
}

function normalizeLoot(raw: any): ResourceWallet {
	const out: ResourceWallet = {};
	if (!raw || typeof raw != "object") {
		return out;
	}
	const allowAll = staticData.resources.size == 0;
	for (const [key, value] of Object.entries(raw)) {
		if (!allowAll && !staticData.resources.has(key)) {
			continue;
		}
		const amount = clampAmount(value);
		if (amount > 0) {
			out[key] = amount;
		}
	}
	return out;
}

function normalizeResearchFlags(raw: any): Record<string, boolean> {
	const out: Record<string, boolean> = {};
	const allowAll = staticData.researchFlags.size == 0;
	if (raw && typeof raw == "object") {
		for (const [key, value] of Object.entries(raw)) {
			if (!allowAll && !staticData.researchFlags.has(key)) {
				continue;
			}
			if (value) {
				out[key] = true;
			}
		}
	}
	return out;
}

function normalizeLab(labRaw: any): LabState {
	const hqPaths = staticData.hqPaths.length > 0 ? staticData.hqPaths : ["Scientific"];
	const defaultPath = hqPaths[0];
	const hqLevel = clampInt(labRaw?.hqLevel ?? 1, 0, 999);
	const hqPath = canonicalHqPath(labRaw?.hqPath, hqPaths) ?? defaultPath;
	const runtime = normalizeLabRuntime(labRaw?.runtime);
	const buildings: Record<string, BuildingState> = {};
	const rawBuildings = labRaw?.buildings;
	if (rawBuildings && typeof rawBuildings == "object") {
		for (const [id, entry] of Object.entries(rawBuildings)) {
			if (!staticData.buildings[id]) {
				continue;
			}
			const data = entry as any;
			const level = clampInt(data?.level ?? 0, 0, 999);
			const route = typeof data?.route == "string" ? data.route : "";
			const runtime = data?.runtime && typeof data.runtime == "object" ? data.runtime : {};
			buildings[id] = {
				level,
				route,
				runtime: {
					stored_output: clampAmount(runtime.stored_output ?? 0),
					last_tick: clampInt(runtime.last_tick ?? Date.now(), 0, Number.MAX_SAFE_INTEGER)
				}
			};
		}
	}
	if (!buildings["lab_th"]) {
		buildings["lab_th"] = { level: hqLevel, route: hqPath, runtime: {} };
	} else if (buildings["lab_th"].level < hqLevel) {
		buildings["lab_th"].level = hqLevel;
	}
	return {
		hqLevel,
		hqPath,
		buildings,
		runtime
	};
}

function normalizeLabRuntime(runtimeRaw: any): LabRuntime {
	const cooldowns: Record<string, number> = {};
	const boosts: Record<string, BoostState> = {};
	const research: ResearchRuntime = {};
	if (runtimeRaw && typeof runtimeRaw == "object") {
		const rawCooldowns = (runtimeRaw as any).cooldowns;
		if (rawCooldowns && typeof rawCooldowns == "object") {
			for (const [id, value] of Object.entries(rawCooldowns)) {
				const ts = clampInt(value, 0, Number.MAX_SAFE_INTEGER);
				if (ts > 0) {
					cooldowns[id] = ts;
				}
			}
		}
		const rawBoosts = (runtimeRaw as any).boosts;
		if (rawBoosts && typeof rawBoosts == "object") {
			for (const [id, value] of Object.entries(rawBoosts)) {
				if (typeof value == "number") {
					const ts = clampInt(value, 0, Number.MAX_SAFE_INTEGER);
					if (ts > 0) {
						boosts[id] = { started_at: 0, expires_at: ts };
					}
					continue;
				}
				if (value && typeof value == "object") {
					const ts = clampInt((value as any).expires_at, 0, Number.MAX_SAFE_INTEGER);
					if (ts > 0) {
						boosts[id] = { started_at: clampInt((value as any).started_at ?? 0, 0, ts), expires_at: ts };
					}
				}
			}
		}
		const rawResearch = (runtimeRaw as any).research;
		if (rawResearch && typeof rawResearch == "object") {
			const activeId = typeof rawResearch.active_id == "string" ? rawResearch.active_id : "";
			const startedAt = clampInt(rawResearch.started_at ?? 0, 0, Number.MAX_SAFE_INTEGER);
			const completesAt = clampInt(rawResearch.completes_at ?? 0, 0, Number.MAX_SAFE_INTEGER);
			if (activeId && completesAt > 0) {
				research.active_id = activeId;
				research.started_at = startedAt;
				research.completes_at = completesAt;
				if (typeof rawResearch.queued_id === "string" && rawResearch.queued_id !== activeId && staticData.research[rawResearch.queued_id]) research.queued_id = rawResearch.queued_id;
			}
		}
	}
	const result: LabRuntime = { cooldowns, boosts, research };
	result.experiment_stability = { failures: clampInt(runtimeRaw?.experiment_stability?.failures, 0, 3) };
	const last = runtimeRaw?.experiment_last;
	if (last && typeof last.id === "string" && typeof last.success === "boolean" && Number.isFinite(last.chance)) result.experiment_last = { id: last.id, success: last.success, chance: clampChance(last.chance), at: clampInt(last.at, 0, Number.MAX_SAFE_INTEGER), expires_at: clampInt(last.expires_at, 0, Number.MAX_SAFE_INTEGER) };
	const directive = runtimeRaw?.directive;
	if (directive && ["production", "research", "experimentation"].includes(directive.id)) {
		const starts = clampInt(directive.starts_at, 0, Number.MAX_SAFE_INTEGER);
		const ends = clampInt(directive.ends_at, 0, Number.MAX_SAFE_INTEGER);
		if (ends > starts) result.directive = { id: directive.id, starts_at: starts, ends_at: ends };
	}
	if (runtimeRaw?.reactor_overcharge && typeof runtimeRaw.reactor_overcharge === "object") result.reactor_overcharge = { progress: clampInt(runtimeRaw.reactor_overcharge.progress, 0, Math.max(1, getBalanceNumber("reactor_overcharge_threshold", 300))), last_used_at: clampInt(runtimeRaw.reactor_overcharge.last_used_at, 0, Number.MAX_SAFE_INTEGER) };
	const anomaly = runtimeRaw?.anomaly;
	if (anomaly && typeof anomaly === "object" && ["seal", "investigate"].includes(anomaly.last_choice)) {
		const reward: ResourceWallet = {};
		if (anomaly.last_reward && typeof anomaly.last_reward === "object" && !Array.isArray(anomaly.last_reward)) for (const [id, amount] of Object.entries(anomaly.last_reward)) if (["essence", "core", "arcane_shard", "time_crystal"].includes(id) && Number.isSafeInteger(amount) && (amount as number) >= 0) reward[id] = amount as number;
		result.anomaly = { next_at: clampInt(anomaly.next_at, 0, Number.MAX_SAFE_INTEGER), last_at: clampInt(anomaly.last_at, 0, Number.MAX_SAFE_INTEGER), last_choice: anomaly.last_choice, last_reward: reward };
	}
	const sync = runtimeRaw?.sync_project;
	if (sync && sync.project_id === "calibration" && sync.partner_kind === "npc" && sync.partner_id === "echo") {
		const started = clampInt(sync.started_at, 0, Number.MAX_SAFE_INTEGER);
		const completes = clampInt(sync.completes_at, 0, Number.MAX_SAFE_INTEGER);
		if (started > 0 && completes > started) result.sync_project = { project_id: "calibration", partner_kind: "npc", partner_id: "echo", started_at: started, completes_at: completes };
	}
	const trade = runtimeRaw?.npc_trade;
	if (trade && typeof trade === "object") {
		const normalizeUses = (raw: any, prefix: string, max: number): Record<string, number> => {
			const uses: Record<string, number> = {};
			if (raw && typeof raw === "object" && !Array.isArray(raw)) for (const [id, amount] of Object.entries(raw)) if (new RegExp(`^${prefix}[1-${max}]$`).test(id) && Number.isSafeInteger(amount) && (amount as number) >= 0) uses[id] = amount as number;
			return uses;
		};
		result.npc_trade = { day_key: clampInt(trade.day_key, 0, Number.MAX_SAFE_INTEGER), week_key: clampInt(trade.week_key, 0, Number.MAX_SAFE_INTEGER), daily_uses: normalizeUses(trade.daily_uses, "d", 8), weekly_uses: normalizeUses(trade.weekly_uses, "w", 6) };
	}
	return result;
}

type NpcOffer = { id: string; period: "daily" | "weekly"; period_key: number; pay: ResourceWallet; receive: ResourceWallet; max: number; remaining: number };

function npcTradeOffers(runtime: LabRuntime, now: number): { offers: NpcOffer[]; day_key: number; week_key: number; next_daily_at: number; next_weekly_at: number } {
	const values = staticData.balance.npc_trade_values;
	const daily = staticData.balance.npc_trade_daily;
	const weekly = staticData.balance.npc_trade_weekly;
	const ids = ["essence", "core", "arcane_shard", "time_crystal"];
	if (!values || typeof values !== "object" || Object.keys(values).sort().join(",") !== [...ids].sort().join(",") || ids.some(id => !Number.isSafeInteger(values[id]) || values[id] <= 0) || !Array.isArray(daily) || daily.length !== 8 || !Array.isArray(weekly) || weekly.length !== 6) throw new HttpError(503, "Invalid NPC trade configuration.");
	const seen = new Set<string>();
	const amountValue = (amounts: any): number => {
		if (!amounts || typeof amounts !== "object" || Array.isArray(amounts) || Object.keys(amounts).length !== 1) throw new HttpError(503, "Invalid NPC trade configuration.");
		const [id, amount] = Object.entries(amounts)[0];
		if (!ids.includes(id) || !staticData.resources.has(id) || !Number.isSafeInteger(amount) || (amount as number) <= 0 || !Number.isSafeInteger((amount as number) * values[id])) throw new HttpError(503, "Invalid NPC trade configuration.");
		return (amount as number) * values[id];
	};
	for (const [pool, prefix] of [[daily, "d"], [weekly, "w"]] as const) for (let i = 0; i < pool.length; i++) {
		const offer = pool[i];
		if (!offer || offer.id !== `${prefix}${i + 1}` || seen.has(offer.id)) throw new HttpError(503, "Invalid NPC trade configuration.");
		seen.add(offer.id);
		const payValue = amountValue(offer.pay), receiveValue = amountValue(offer.receive);
		if (Object.keys(offer.pay)[0] === Object.keys(offer.receive)[0] || !Number.isSafeInteger(payValue * 4) || !Number.isSafeInteger(receiveValue * 5) || payValue * 4 < receiveValue * 5) throw new HttpError(503, "Invalid NPC trade configuration.");
	}
	const day = Math.floor(now / 86400000), week = Math.floor((day + 3) / 7);
	const counts = runtime.npc_trade;
	const select = (pool: any[], period: "daily" | "weekly", key: number, quantity: number, step: number, max: number): NpcOffer[] => Array.from({ length: quantity }, (_, i) => {
		const offer = pool[(key + step * i) % pool.length];
		const uses = period === "daily" ? (counts?.day_key === day ? counts.daily_uses : {}) : (counts?.week_key === week ? counts.weekly_uses : {});
		return { id: offer.id, period, period_key: key, pay: offer.pay, receive: offer.receive, max, remaining: Math.max(0, max - (uses[offer.id] ?? 0)) };
	});
	return { offers: [...select(daily, "daily", day, 3, 3, 2), ...select(weekly, "weekly", week, 2, 2, 1)], day_key: day, week_key: week, next_daily_at: (day + 1) * 86400000, next_weekly_at: ((week + 1) * 7 - 3) * 86400000 };
}

function normalizeWorld(worldRaw: any, now: number): PlayerWorldState {
	const zoneProgress: Record<string, ZoneProgress> = {};
	const rawProgress = worldRaw?.zone_progress;
	if (rawProgress && typeof rawProgress == "object") {
		for (const [zoneId, value] of Object.entries(rawProgress)) {
			if (!isValidZoneId(zoneId)) {
				continue;
			}
			const entry = value as any;
			const heat = clampInt(entry?.heat ?? 0, 0, Number.MAX_SAFE_INTEGER);
			const reputation = clampInt(entry?.reputation ?? 0, 0, Number.MAX_SAFE_INTEGER);
			const lastHeatAt = clampInt(entry?.last_heat_at ?? now, 0, Number.MAX_SAFE_INTEGER);
			zoneProgress[zoneId] = { heat, reputation, last_heat_at: lastHeatAt };
		}
	}
	const sessions: Record<string, WorldSession> = {};
	const rawSessions = worldRaw?.sessions;
	if (rawSessions && typeof rawSessions == "object") {
		for (const [sessionId, value] of Object.entries(rawSessions)) {
			if (!sessionId) {
				continue;
			}
			const entry = value as any;
			const zoneId = typeof entry?.zone_id == "string" ? entry.zone_id.trim() : "";
			if (!zoneId || !isValidZoneId(zoneId)) {
				continue;
			}
			const modifiers = normalizeModifierList(entry?.modifiers);
			sessions[sessionId] = {
				session_id: sessionId,
				zone_id: zoneId,
				started_at: clampInt(entry?.started_at ?? now, 0, Number.MAX_SAFE_INTEGER),
				last_farm_at: clampInt(entry?.last_farm_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
				pending_loot: normalizeLoot(entry?.pending_loot),
				blocks_farmed: clampInt(entry?.blocks_farmed ?? 0, 0, Number.MAX_SAFE_INTEGER),
				modifiers
			};
		}
	}
	const maxStamina = getWorldMaxStamina();
	const stamina = clampInt(worldRaw?.stamina ?? maxStamina, 0, maxStamina);
	const lastStaminaAt = clampInt(worldRaw?.last_stamina_at ?? now, 0, Number.MAX_SAFE_INTEGER);
	const dailyEntries = clampInt(worldRaw?.daily_entries ?? 0, 0, Number.MAX_SAFE_INTEGER);
	const lastEntryResetAt = clampInt(worldRaw?.last_entry_reset_at ?? now, 0, Number.MAX_SAFE_INTEGER);
	const maxTickets = getBossTicketMax();
	const bossTickets = clampInt(worldRaw?.boss_tickets ?? maxTickets, 0, maxTickets);
	const lastBossTicketAt = clampInt(worldRaw?.last_boss_ticket_at ?? now, 0, Number.MAX_SAFE_INTEGER);
	const bossTokens = clampInt(worldRaw?.boss_tokens ?? 0, 0, Number.MAX_SAFE_INTEGER);
	const bossClaims: Record<string, number> = {};
	const rawClaims = worldRaw?.boss_claims;
	if (rawClaims && typeof rawClaims == "object") {
		for (const [bossId, value] of Object.entries(rawClaims)) {
			if (!isValidBossId(bossId)) {
				continue;
			}
			const ts = clampInt(value, 0, Number.MAX_SAFE_INTEGER);
			if (ts > 0) {
				bossClaims[bossId] = ts;
			}
		}
	}
	const world: PlayerWorldState = {
		zone_progress: zoneProgress,
		daily_entries: dailyEntries,
		last_entry_reset_at: lastEntryResetAt,
		last_gate_entry_at: clampInt(worldRaw?.last_gate_entry_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
		stamina,
		last_stamina_at: lastStaminaAt,
		boss_tickets: bossTickets,
		last_boss_ticket_at: lastBossTicketAt,
		boss_claims: bossClaims,
		boss_tokens: bossTokens,
		sessions
	};
	return world;
}

function normalizeModifierList(raw: any): string[] {
	if (!Array.isArray(raw)) {
		return [];
	}
	const out: string[] = [];
	for (const entry of raw) {
		if (typeof entry == "string") {
			const trimmed = entry.trim();
			if (trimmed) {
				out.push(trimmed);
			}
		}
	}
	return out;
}

function ensurePlayerWorld(state: PlayerState, now: number): PlayerWorldState {
	const world = normalizeWorld(state.world, now);
	state.world = world;
	return world;
}

function refreshWorldPlayer(world: PlayerWorldState, now: number): boolean {
	let changed = false;
	if (resetDailyEntries(world, now)) {
		changed = true;
	}
	if (regenWorldStamina(world, now)) {
		changed = true;
	}
	if (regenBossTickets(world, now)) {
		changed = true;
	}
	return changed;
}

function resetDailyEntries(world: PlayerWorldState, now: number): boolean {
	const resetMs = getWorldDailyResetMs();
	if (now - world.last_entry_reset_at >= resetMs) {
		world.daily_entries = 0;
		world.last_entry_reset_at = now;
		return true;
	}
	return false;
}

function regenWorldStamina(world: PlayerWorldState, now: number): boolean {
	const maxStamina = getWorldMaxStamina();
	const rechargeMs = getWorldStaminaRechargeMs();
	if (rechargeMs <= 0) {
		if (world.stamina != maxStamina) {
			world.stamina = maxStamina;
			world.last_stamina_at = now;
			return true;
		}
		return false;
	}
	const elapsed = now - world.last_stamina_at;
	if (elapsed <= 0) {
		return false;
	}
	const regen = Math.floor(elapsed / rechargeMs);
	if (regen <= 0) {
		return false;
	}
	world.stamina = Math.min(maxStamina, world.stamina + regen);
	world.last_stamina_at += regen * rechargeMs;
	if (world.stamina >= maxStamina) {
		world.last_stamina_at = now;
	}
	return true;
}

function regenBossTickets(world: PlayerWorldState, now: number): boolean {
	const maxTickets = getBossTicketMax();
	const rechargeMs = getBossTicketRechargeMs();
	if (rechargeMs <= 0) {
		if (world.boss_tickets != maxTickets) {
			world.boss_tickets = maxTickets;
			world.last_boss_ticket_at = now;
			return true;
		}
		return false;
	}
	const elapsed = now - world.last_boss_ticket_at;
	if (elapsed <= 0) {
		return false;
	}
	const regen = Math.floor(elapsed / rechargeMs);
	if (regen <= 0) {
		return false;
	}
	world.boss_tickets = Math.min(maxTickets, world.boss_tickets + regen);
	world.last_boss_ticket_at += regen * rechargeMs;
	if (world.boss_tickets >= maxTickets) {
		world.last_boss_ticket_at = now;
	}
	return true;
}

function ensureZoneProgress(
	world: PlayerWorldState,
	zoneId: string,
	now: number
): ZoneProgress {
	let progress = world.zone_progress[zoneId];
	if (!progress) {
		progress = { heat: 0, reputation: 0, last_heat_at: now };
		world.zone_progress[zoneId] = progress;
		return progress;
	}
	decayZoneHeat(progress, now);
	return progress;
}

function decayZoneHeat(progress: ZoneProgress, now: number): void {
	const decayPerHour = getWorldHeatDecayPerHour();
	if (decayPerHour <= 0) {
		return;
	}
	const elapsed = now - progress.last_heat_at;
	if (elapsed <= 0) {
		return;
	}
	const hours = elapsed / 3600000;
	const decay = Math.floor(hours * decayPerHour);
	if (decay <= 0) {
		return;
	}
	progress.heat = Math.max(0, progress.heat - decay);
	progress.last_heat_at = now;
}

function getWorldDailyEntryLimit(): number {
	return clampInt(getBalanceNumber("world_daily_entries", 10), 1, 1000);
}

function getWorldDailyResetMs(): number {
	const hours = getBalanceNumber("world_daily_reset_hours", 24);
	return Math.max(1, hours) * 3600 * 1000;
}

function getWorldMaxStamina(): number {
	return clampInt(getBalanceNumber("world_max_stamina", 12), 1, 1000);
}

function getWorldStaminaRechargeMs(): number {
	const seconds = getBalanceNumber("world_stamina_recharge_seconds", 300);
	return Math.max(0, seconds) * 1000;
}

function getWorldMaxBlocksPerAction(): number {
	return clampInt(getBalanceNumber("world_max_blocks_per_action", 4), 1, 100);
}

function getWorldHeatGain(): number {
	return clampInt(getBalanceNumber("world_heat_gain", 2), 0, 100);
}

function getWorldHeatMax(): number {
	return clampInt(getBalanceNumber("world_heat_max", 100), 1, 10000);
}

function getWorldHeatDecayPerHour(): number {
	return getBalanceNumber("world_heat_decay_per_hour", 1);
}

function getWorldRotationMs(): number {
	const seconds = getBalanceNumber("world_rotation_seconds", 0);
	if (seconds > 0) {
		return seconds * 1000;
	}
	const hours = getBalanceNumber("world_rotation_hours", 24);
	return Math.max(1, hours) * 3600 * 1000;
}

function getWorldEntryFee(): number {
	return clampInt(getBalanceNumber("world_entry_fee_essence", 0), 0, 1_000_000_000);
}

function getBossTicketMax(): number {
	return clampInt(getBalanceNumber("boss_ticket_max", 5), 1, 999);
}

function getBossTicketRechargeMs(): number {
	const minutes = getBalanceNumber("boss_ticket_recharge_minutes", 30);
	return Math.max(0, minutes) * 60 * 1000;
}

function getBossAttackFee(): number {
	return clampInt(getBalanceNumber("boss_attack_fee_essence", 0), 0, 1_000_000_000);
}

function getBossIpLimitPerWindow(): number {
	return clampInt(getBalanceNumber("boss_ip_limit_per_window", 200), 0, 100000);
}

function allowBossIp(ip: string, windowEnd: number): boolean {
	const limit = getBossIpLimitPerWindow();
	if (!ip || limit <= 0) {
		return true;
	}
	const entry = bossIpWindow.get(ip);
	if (!entry || entry.windowEnd != windowEnd) {
		bossIpWindow.set(ip, { windowEnd, count: 1 });
		return true;
	}
	if (entry.count >= limit) {
		return false;
	}
	entry.count += 1;
	return true;
}

function cloneLabRuntime(runtime?: LabRuntime | null): LabRuntime {
	return normalizeLabRuntime(runtime ?? {});
}

function ensureLabRuntime(state: PlayerState): LabRuntime {
	if (!state.lab.runtime) {
		state.lab.runtime = { cooldowns: {}, boosts: {}, research: {} };
		return state.lab.runtime;
	}
	if (!state.lab.runtime.cooldowns) {
		state.lab.runtime.cooldowns = {};
	}
	if (!state.lab.runtime.boosts) {
		state.lab.runtime.boosts = {};
	}
	if (!state.lab.runtime.research) {
		state.lab.runtime.research = {};
	}
	return state.lab.runtime;
}

function cleanupLabRuntime(runtime: LabRuntime, nowMs: number): boolean {
	let changed = false;
	for (const [id, ts] of Object.entries(runtime.cooldowns)) {
		if (!Number.isFinite(ts) || ts <= nowMs) {
			delete runtime.cooldowns[id];
			changed = true;
		}
	}
	// Preserve expired intervals until production and queued research are settled.
	return changed;
}

function autoCompleteResearch(state: PlayerState, nowMs: number): boolean {
	const runtime = ensureLabRuntime(state);
	let changed = false;
	for (let i = 0; i < 2; i++) {
		const research = runtime.research;
		const completesAt = research?.completes_at ?? 0;
		if (!research?.active_id || !Number.isFinite(completesAt) || completesAt <= 0 || completesAt > nowMs) break;
		const node = staticData.research[research.active_id];
		if (node?.flag_id) state.research_flags[node.flag_id] = true;
		const queued = research.queued_id ? staticData.research[research.queued_id] : undefined;
		runtime.research = queued ? { active_id: queued.id, started_at: completesAt, completes_at: completesAt + Math.max(1, queued.time_sec * (directiveActive(runtime, "research", completesAt) ? getBalanceNumber("hq_directive_research_time_mult", 0.9) : 1) * (isBoostActive(runtime, "fast_research", completesAt) ? experimentEffect("fast_research", "archive_time_mult", 0.85) : 1)) * 1000 } : {};
		changed = true;
	}
	return changed;
}

function canonicalHqPath(value: any, paths: string[]): string | null {
	if (typeof value != "string") {
		return null;
	}
	for (const path of paths) {
		if (path.toLowerCase() == value.toLowerCase()) {
			return path;
		}
	}
	return null;
}

function clampAmount(value: any): number {
	const num = typeof value == "number" ? value : Number(value ?? 0);
	if (!Number.isFinite(num)) {
		return 0;
	}
	const clamped = Math.max(0, Math.min(num, 1_000_000_000));
	return Math.floor(clamped);
}

function clampInt(value: any, min: number, max: number): number {
	const num = typeof value == "number" ? value : Number(value ?? 0);
	if (!Number.isFinite(num)) {
		return min;
	}
	return Math.max(min, Math.min(Math.floor(num), max));
}

function cloneWallet(wallet: ResourceWallet): ResourceWallet {
	return { ...wallet };
}

function computeWalletDelta(before: ResourceWallet, after: ResourceWallet): Record<string, number> {
	const delta: Record<string, number> = {};
	const keys = new Set<string>([...Object.keys(before), ...Object.keys(after)]);
	for (const key of keys) {
		const beforeVal = clampAmount(before[key] ?? 0);
		const afterVal = clampAmount(after[key] ?? 0);
		const diff = afterVal - beforeVal;
		if (diff != 0) {
			delta[key] = diff;
		}
	}
	return delta;
}

function hasWalletDelta(delta: Record<string, number>): boolean {
	return Object.keys(delta).length > 0;
}

function auditWalletMutation(
	playerId: string,
	delta: Record<string, number>,
	reason: string,
	relatedId: string,
	ts: number
): void {
	if (!hasWalletDelta(delta)) {
		return;
	}
	const auditId = crypto.randomUUID();
	insertAuditStmt.run(auditId, playerId, JSON.stringify(delta), reason, relatedId, ts);
}

function getWalletCap(resourceId: string): number {
	const caps = staticData.balance.wallet_caps;
	if (caps && typeof caps == "object" && caps[resourceId] != null) {
		const value = caps[resourceId];
		if (typeof value == "number" && Number.isFinite(value) && value > 0) {
			return Math.floor(value);
		}
	}
	const fallback = getBalanceNumber("wallet_max_per_resource", 1_000_000_000);
	return Math.max(1, Math.floor(fallback));
}

function getWalletInvariantError(wallet: ResourceWallet): string | null {
	for (const [resId, amountRaw] of Object.entries(wallet)) {
		const amount = typeof amountRaw == "number" ? amountRaw : Number(amountRaw);
		if (!Number.isFinite(amount)) {
			return `Invalid wallet amount for ${resId}.`;
		}
		if (!Number.isInteger(amount)) {
			return `Wallet amount must be integer for ${resId}.`;
		}
		if (amount < 0) {
			return `Wallet amount negative for ${resId}.`;
		}
		const cap = getWalletCap(resId);
		if (amount > cap) {
			return `Wallet cap exceeded for ${resId}.`;
		}
	}
	return null;
}

function assertWalletInvariant(wallet: ResourceWallet): void {
	const error = getWalletInvariantError(wallet);
	if (error) {
		throw new HttpError(400, error);
	}
}

function getSuspiciousAmountThreshold(): number {
	return clampInt(getBalanceNumber("wallet_suspicious_threshold", 5_000_000), 1, 1_000_000_000);
}

function isSuspiciousAmount(value: number): boolean {
	return Math.abs(value) > getSuspiciousAmountThreshold();
}

function logSuspiciousAction(
	playerId: string,
	delta: Record<string, number>,
	reason: string,
	relatedId: string
): void {
	const now = Date.now();
	const tag = `SUSPICIOUS_${reason}`;
	auditWalletMutation(playerId, delta, tag, relatedId, now);
}

function checkSuspiciousDelta(
	playerId: string,
	delta: Record<string, number>,
	reason: string,
	relatedId: string
): void {
	for (const value of Object.values(delta)) {
		if (isSuspiciousAmount(value)) {
			logSuspiciousAction(playerId, delta, reason, relatedId);
			throw new HttpError(400, "Suspicious wallet delta.");
		}
	}
}

function rejectSuspiciousMarketBuy(
	buyerId: string,
	orderId: string,
	resourceId: string,
	priceResourceId: string,
	amount: number,
	unitPrice: number
): void {
	const totalPrice = unitPrice * amount;
	if (isSuspiciousAmount(amount) || isSuspiciousAmount(totalPrice)) {
		logSuspiciousAction(
			buyerId,
			{
				[String(priceResourceId || "essence")]: -totalPrice,
				[String(resourceId || "")]: amount
			},
			"MARKET_BUY",
			orderId
		);
		throw new HttpError(400, "Suspicious buy amount.");
	}
}

const REACTOR_ROUTES = ["stable", "volatile", "mutagenic"];
const STORAGE_ROUTES = ["compact", "reactive", "sealed"];
const MARKET_STATUS_OPEN = "OPEN";
const MARKET_STATUS_FILLED = "FILLED";
const MARKET_STATUS_CANCELED = "CANCELED";
const MARKET_TYPE_SELL = "SELL";
const MARKET_TYPE_BUY = "BUY";
const MARKET_MAX_AMOUNT = 1_000_000;
const MARKET_MAX_PRICE = 1_000_000_000;
const MARKET_LIST_LIMIT = 200;
const TRADE_JOB_STATUS_OPEN = "OPEN";
const TRADE_JOB_STATUS_CLOSED = "CLOSED";
const TRADE_RUN_STATUS_PENDING = "PENDING";
const TRADE_RUN_STATUS_CLAIMED = "CLAIMED";
const TRADE_MAX_AMOUNT = 1_000_000;
const TRADE_MAX_DURATION_SEC = 7 * 24 * 3600;
const TRADE_MAX_QUEUE = 100;
const TRADE_LIST_LIMIT = 200;
const HQ_RULES: Record<string, { unlock: number; max: number; cap_per_hq: number }> = {
	lab_th: { unlock: 1, max: 10, cap_per_hq: 1 },
	essence_reactor: { unlock: 1, max: 10, cap_per_hq: 1 },
	storage_vault: { unlock: 1, max: 10, cap_per_hq: 1 },
	build_forge: { unlock: 1, max: 10, cap_per_hq: 1 },
	homunculus_vat: { unlock: 2, max: 10, cap_per_hq: 1 },
	ultrahit_tower: { unlock: 2, max: 10, cap_per_hq: 1 },
	experiment_chamber: { unlock: 3, max: 10, cap_per_hq: 1 },
	arcane_archives: { unlock: 3, max: 10, cap_per_hq: 1 },
	sync_nexus: { unlock: 4, max: 10, cap_per_hq: 1 },
	anomaly_containment: { unlock: 5, max: 10, cap_per_hq: 1 },
	trade_hall: { unlock: 2, max: 10, cap_per_hq: 1 },
	world_gate: { unlock: 1, max: 10, cap_per_hq: 1 }
};

type ExperimentDef = {
	id: string;
	name: string;
	kind: "convert" | "boost";
	cost: Record<string, number>;
	grants?: Record<string, number>;
	success_chance?: number;
	cooldown_s: number;
	boost_id?: string;
	boost_duration_s?: number;
	effect?: Record<string, number>;
};

type ResearchNode = {
	id: string;
	name: string;
	flag_id: string;
	cost: Record<string, number>;
	time_sec: number;
	requires: string[];
};

const experimentCatalog = readJsonFile(resolve(import.meta.dir, "..", "..", "data", "static", "experiments.json"));
const EXPERIMENTS: Record<string, ExperimentDef> = Object.fromEntries((Array.isArray(experimentCatalog?.experiments) ? experimentCatalog.experiments : []).filter((entry: any) => typeof entry?.id === "string").map((entry: ExperimentDef) => [entry.id, entry]));

function experimentEffect(id: string, key: string, fallback: number): number {
	const value = EXPERIMENTS[id]?.effect?.[key];
	return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function applyUpgrade(
	state: PlayerState,
	payload: any,
	debugBypass = false
): { state: PlayerState; error?: string } {
	const buildingId = typeof payload?.building_id == "string" ? payload.building_id.trim() : "";
	if (!buildingId || buildingId.length > 64) {
		return { state, error: "Invalid building_id." };
	}
	if (!staticData.buildings[buildingId]) {
		return { state, error: "Unknown building_id." };
	}
	const current = ensureBuildingState(state, buildingId);
	if (!debugBypass && !canUpgrade(buildingId, current.level, state.lab.hqLevel)) {
		return { state, error: "Upgrade cap reached." };
	}
	const rule = HQ_RULES[buildingId] ?? { unlock: 1, max: 10, cap_per_hq: 1 };
	if (current.level >= rule.max) {
		return { state, error: "Upgrade cap reached." };
	}
	const targetLevel = current.level + 1;
	if (!debugBypass) {
		const cost = resolveUpgradeCost(buildingId, targetLevel, state.lab.hqPath);
		if (!cost.ok) {
			return { state, error: cost.error || "Missing cost data." };
		}
		const wallet = state.wallet;
		for (const [resId, amount] of Object.entries(cost.cost)) {
			if (!staticData.resources.has(resId)) {
				return { state, error: "Unknown resource id in cost." };
			}
			if ((wallet[resId] ?? 0) < amount) {
				return { state, error: "Insufficient resources." };
			}
		}
		for (const [resId, amount] of Object.entries(cost.cost)) {
			wallet[resId] = (wallet[resId] ?? 0) - amount;
			if (wallet[resId] < 0) {
				wallet[resId] = 0;
			}
		}
	}
	current.level = targetLevel;
	if (buildingId == "lab_th" && state.lab.hqLevel < targetLevel) {
		state.lab.hqLevel = targetLevel;
	}
	return { state };
}

function applyRouteChange(state: PlayerState, payload: any): { state: PlayerState; error?: string } {
	const buildingId = typeof payload?.building_id == "string" ? payload.building_id.trim() : "";
	const routeRaw = typeof payload?.route == "string" ? payload.route.trim() : "";
	if (!buildingId || !routeRaw) {
		return { state, error: "Invalid building_id or route." };
	}
	if (!staticData.buildings[buildingId]) {
		return { state, error: "Unknown building_id." };
	}
	const routeKey = routeRaw.toLowerCase();
	if (buildingId == "lab_th") {
		const hqPath = canonicalHqPath(routeRaw, staticData.hqPaths);
		if (!hqPath) {
			return { state, error: "Invalid HQ path." };
		}
		state.lab.hqPath = hqPath;
		const labState = ensureBuildingState(state, buildingId);
		labState.route = hqPath;
		return { state };
	}
	const allowed = getAllowedRoutes(buildingId);
	if (!allowed.includes(routeKey)) {
		return { state, error: "Invalid route." };
	}
	const building = ensureBuildingState(state, buildingId);
	building.route = routeKey;
	return { state };
}

function applyClaim(
	state: PlayerState,
	payload: any,
	nowMs: number
): { state: PlayerState; error?: string } {
	const buildingId = typeof payload?.building_id == "string" ? payload.building_id.trim() : "";
	if (!buildingId) {
		return { state, error: "Invalid building_id." };
	}
	if (!staticData.buildings[buildingId]) {
		return { state, error: "Unknown building_id." };
	}
	if (buildingId != "essence_reactor") {
		return { state, error: "Building has no production." };
	}
	const reactor = ensureBuildingState(state, "essence_reactor");
	const storage = ensureBuildingState(state, "storage_vault");
	const runtime = ensureLabRuntime(state);
	cleanupLabRuntime(runtime, nowMs);
	tickProduction(
		reactor,
		nowMs,
		reactor.level,
		reactor.route || "stable",
		storage.route || "",
		state.lab.hqPath,
		runtime
	);
	const capacity = Math.floor(computeCapacity(storage.level, storage.route || "", state.lab.hqPath) * (isBoostActive(runtime, "extra_storage", nowMs) ? experimentEffect("extra_storage", "capacity_mult", 1.15) : 1));
	const claimResult = claimProduction(
		reactor,
		capacity,
		reactor.route || "stable",
		storage.route || "",
		state.lab.hqPath,
		runtime,
		nowMs
	);
	applyWalletGrant(state.wallet, claimResult.grants);
	const overcharge = runtime.reactor_overcharge ?? { progress: 0, last_used_at: 0 };
	overcharge.progress = Math.min(Math.max(1, Math.trunc(getBalanceNumber("reactor_overcharge_threshold", 300))), overcharge.progress + (claimResult.grants.essence ?? 0));
	runtime.reactor_overcharge = overcharge;
	return { state };
}

function applyStartExperiment(
	state: PlayerState,
	payload: any,
	clientActionId: string,
	nowMs: number
): { state: PlayerState; error?: string } {
	const experimentId =
		typeof payload?.experiment_id == "string" ? payload.experiment_id.trim() : "";
	if (!experimentId || experimentId.length > 64) {
		return { state, error: "Invalid experiment_id." };
	}
	const experiment = EXPERIMENTS[experimentId];
	if (!experiment) {
		return { state, error: "Unknown experiment_id." };
	}
	if (experiment.kind !== "boost" || experiment.boost_id !== experimentId || !Number.isFinite(experiment.success_chance) || experiment.success_chance! < 0 || experiment.success_chance! > 1 || !Number.isSafeInteger(experiment.cooldown_s) || experiment.cooldown_s < 0 || !Number.isSafeInteger(experiment.boost_duration_s) || experiment.boost_duration_s! <= 0 || !experiment.cost || typeof experiment.cost !== "object" || Array.isArray(experiment.cost)) return { state, error: "Invalid experiment configuration." };
	const unlockLevel = HQ_RULES.experiment_chamber?.unlock ?? 1;
	if (state.lab.hqLevel < unlockLevel) {
		return { state, error: "Experiment Chamber locked." };
	}
	const chamber = ensureBuildingState(state, "experiment_chamber");
	if (chamber.level <= 0) {
		return { state, error: "Experiment Chamber not built." };
	}
	const runtime = ensureLabRuntime(state);
	cleanupLabRuntime(runtime, nowMs);
	const cooldownUntil = runtime.cooldowns[experimentId] ?? 0;
	if (cooldownUntil > nowMs || isBoostActive(runtime, experimentId, nowMs)) {
		return { state, error: "Experiment on cooldown." };
	}
	for (const [resId, amountRaw] of Object.entries(experiment.cost)) {
		if (!staticData.resources.has(resId) || !Number.isSafeInteger(amountRaw) || amountRaw < 0) {
			return { state, error: "Unknown resource id in experiment cost." };
		}
		const amount = clampAmount(amountRaw);
		if ((state.wallet[resId] ?? 0) < amount) {
			return { state, error: "Insufficient resources." };
		}
	}
	for (const [resId, amountRaw] of Object.entries(experiment.cost)) {
		const amount = clampAmount(amountRaw);
		state.wallet[resId] = (state.wallet[resId] ?? 0) - amount;
		if (state.wallet[resId] < 0) {
			state.wallet[resId] = 0;
		}
	}
	const stability = runtime.experiment_stability ?? { failures: 0 };
	const chance = clampChance((experiment.success_chance ?? 0) + stability.failures * 0.1 + (directiveActive(runtime, "experimentation", nowMs) ? getBalanceNumber("hq_directive_experiment_chance_bonus", 0.05) : 0) + (experimentId !== "better_odds" && isBoostActive(runtime, "better_odds", nowMs) ? experimentEffect("better_odds", "experiment_chance_bonus", 0.1) : 0));
	const success = chance >= 1 || seededRandom01(`${EXPERIMENT_SECRET}:${clientActionId}:${experimentId}:success`) < chance;
	stability.failures = success ? 0 : Math.min(3, stability.failures + 1);
	runtime.experiment_stability = stability;
	const expiresAt = success ? nowMs + Math.max(0, experiment.boost_duration_s ?? 0) * 1000 : 0;
	if (success) {
		if (["volatile_overclock", "essence_turbo"].includes(experimentId)) {
			const reactor = ensureBuildingState(state, "essence_reactor");
			const storage = ensureBuildingState(state, "storage_vault");
			if (reactor.level > 0) tickProduction(reactor, nowMs, reactor.level, reactor.route || "stable", storage.route || "", state.lab.hqPath, runtime);
		}
		runtime.boosts[experiment.boost_id ?? experimentId] = { started_at: nowMs, expires_at: expiresAt };
	}
	runtime.experiment_last = { id: experimentId, success, chance, at: nowMs, expires_at: expiresAt };
	const cooldownS = Math.max(0, experiment.cooldown_s ?? 0);
	if (cooldownS > 0) {
		runtime.cooldowns[experimentId] = nowMs + cooldownS * 1000;
	}
	return { state };
}

function applyStartResearch(
	state: PlayerState,
	payload: any,
	nowMs: number
): { state: PlayerState; error?: string } {
	const researchId =
		typeof payload?.research_id == "string" ? payload.research_id.trim() : "";
	if (!researchId || researchId.length > 64) {
		return { state, error: "Invalid research_id." };
	}
	const node = staticData.research[researchId];
	if (!node) {
		return { state, error: "Unknown research_id." };
	}
	if (state.research_flags[node.flag_id]) {
		return { state, error: "Research already completed." };
	}
	const unlockLevel = HQ_RULES.arcane_archives?.unlock ?? 1;
	if (state.lab.hqLevel < unlockLevel) {
		return { state, error: "Arcane Archives locked." };
	}
	const archives = ensureBuildingState(state, "arcane_archives");
	if (archives.level <= 0) {
		return { state, error: "Arcane Archives not built." };
	}
	const runtime = ensureLabRuntime(state);
	cleanupLabRuntime(runtime, nowMs);
	autoCompleteResearch(state, nowMs);
	const active = runtime.research?.active_id ?? "";
	if (active) {
		return { state, error: "Research already in progress." };
	}
	for (const req of node.requires) {
		if (!state.research_flags[req]) {
			return { state, error: "Research requirements not met." };
		}
	}
	for (const [resId, amountRaw] of Object.entries(node.cost)) {
		if (!staticData.resources.has(resId)) {
			return { state, error: "Unknown resource id in research cost." };
		}
		const amount = clampAmount(amountRaw);
		if ((state.wallet[resId] ?? 0) < amount) {
			return { state, error: "Insufficient resources." };
		}
	}
	for (const [resId, amountRaw] of Object.entries(node.cost)) {
		const amount = clampAmount(amountRaw);
		state.wallet[resId] = (state.wallet[resId] ?? 0) - amount;
		if (state.wallet[resId] < 0) {
			state.wallet[resId] = 0;
		}
	}
	runtime.research = {
		active_id: researchId,
		started_at: nowMs,
		completes_at: nowMs + Math.max(1, node.time_sec * (directiveActive(runtime, "research", nowMs) ? getBalanceNumber("hq_directive_research_time_mult", 0.9) : 1) * (isBoostActive(runtime, "fast_research", nowMs) ? experimentEffect("fast_research", "archive_time_mult", 0.85) : 1)) * 1000
	};
	return { state };
}

function applyClaimResearch(
	state: PlayerState,
	payload: any,
	nowMs: number
): { state: PlayerState; error?: string } {
	const runtime = ensureLabRuntime(state);
	autoCompleteResearch(state, nowMs);
	const requested = typeof payload?.research_id == "string" ? payload.research_id.trim() : "";
	if (requested && staticData.research[requested] && state.research_flags[staticData.research[requested].flag_id]) return { state };
	const activeId = runtime.research?.active_id ?? "";
	if (!activeId) {
		const requested =
			typeof payload?.research_id == "string" ? payload.research_id.trim() : "";
		if (requested) {
			const node = staticData.research[requested];
			if (node && state.research_flags[node.flag_id]) {
				return { state };
			}
		}
		return { state, error: "No research in progress." };
	}
	if (requested && requested != activeId) {
		return { state, error: "Research mismatch." };
	}
	const completesAt = runtime.research?.completes_at ?? 0;
	if (!Number.isFinite(completesAt) || completesAt > nowMs) {
		return { state, error: "Research not complete." };
	}
	const node = staticData.research[activeId];
	if (node && node.flag_id) {
		state.research_flags[node.flag_id] = true;
	}
	runtime.research = {};
	return { state };
}

function seededRandom01(seed: string): number {
	const hash = createHash("sha256").update(seed).digest();
	const value = hash.readUInt32BE(0);
	return value / 0xffffffff;
}

function getBoostMultipliers(
	labRuntime: LabRuntime,
	nowMs: number
): { outputMult: number; lossChanceMult: number; rareChanceMult: number } {
	const active = getActiveBoosts(labRuntime, nowMs);
	const outputMult = Math.max(1, active.overclock ? experimentEffect("volatile_overclock", "reactor_output_mult", 1.1) : 1, isBoostActive(labRuntime, "essence_turbo", nowMs) ? experimentEffect("essence_turbo", "reactor_output_mult", 1.2) : 1);
	const lossChanceMult = isBoostActive(labRuntime, "safe_reactor", nowMs) ? experimentEffect("safe_reactor", "volatile_loss_mult", 0.65) : 1;
	const rareChanceMult = active.mutagen ? experimentEffect("mutagen_surge", "rare_chance_mult", 1.35) : 1;
	return { outputMult, lossChanceMult, rareChanceMult };
}

function getActiveBoosts(
	labRuntime: LabRuntime,
	nowMs: number
): { overclock: boolean; mutagen: boolean } {
	const overclock = isBoostActive(labRuntime, "volatile_overclock", nowMs);
	const mutagen = isBoostActive(labRuntime, "mutagen_surge", nowMs);
	return { overclock, mutagen };
}

function isBoostActive(labRuntime: LabRuntime, boostId: string, nowMs: number): boolean {
	const entry = labRuntime.boosts[boostId];
	if (!entry) {
		return false;
	}
	const expiresAt = entry.expires_at ?? 0;
	return Number.isFinite(expiresAt) && (entry.started_at ?? 0) <= nowMs && expiresAt > nowMs;
}

function applyWalletGrant(wallet: ResourceWallet, grants: Record<string, number>): void {
	for (const [resId, amountRaw] of Object.entries(grants)) {
		if (!staticData.resources.has(resId)) {
			continue;
		}
		const amount = clampAmount(amountRaw);
		wallet[resId] = (wallet[resId] ?? 0) + amount;
	}
}

function ensureBuildingState(state: PlayerState, id: string): BuildingState {
	if (!state.lab.buildings[id]) {
		state.lab.buildings[id] = { level: 0, route: "", runtime: {} };
	}
	const entry = state.lab.buildings[id];
	if (!entry.runtime) {
		entry.runtime = {};
	}
	if (entry.runtime.stored_output == null) {
		entry.runtime.stored_output = 0;
	}
	if (entry.runtime.last_tick == null) {
		entry.runtime.last_tick = Date.now();
	}
	return entry;
}

function canUpgrade(buildingId: string, currentLevel: number, hqLevel: number): boolean {
	const rule = HQ_RULES[buildingId] ?? { unlock: 1, max: 10, cap_per_hq: 1 };
	if (hqLevel < rule.unlock) {
		return false;
	}
	if (buildingId == "lab_th") {
		return currentLevel < rule.max;
	}
	const cap = Math.min(rule.max, Math.max(0, hqLevel) * Math.max(1, rule.cap_per_hq));
	return currentLevel < cap;
}

function resolveUpgradeCost(
	buildingId: string,
	level: number,
	hqPath: string
): { ok: boolean; cost: Record<string, number>; error?: string } {
	const entry = staticData.buildings[buildingId];
	if (!entry || typeof entry != "object") {
		return { ok: false, cost: {}, error: "Unknown building." };
	}
	const costs = (entry as any).costs;
	if (!costs || typeof costs != "object") {
		return { ok: false, cost: {}, error: "Missing cost data." };
	}
	const costEntry = costs[String(level)];
	if (!costEntry || typeof costEntry != "object") {
		return { ok: false, cost: {}, error: "Missing cost data." };
	}
	const mult = getHqCostMultiplier(hqPath);
	const out: Record<string, number> = {};
	for (const [key, value] of Object.entries(costEntry)) {
		const amount = clampAmount(value);
		out[key] = Math.floor(amount * mult);
	}
	return { ok: true, cost: out };
}

function getHqCostMultiplier(hqPath: string): number {
	const key = hqPath.toLowerCase();
	const map = staticData.balance.hq_cost_mult ?? {
		scientific: 0.95,
		chaotic: 1.05,
		industrial: 1.0
	};
	return getMultiplier(map, key, 1.0);
}

function getAllowedRoutes(buildingId: string): string[] {
	if (buildingId == "essence_reactor") {
		return REACTOR_ROUTES;
	}
	if (buildingId == "storage_vault") {
		return STORAGE_ROUTES;
	}
	const entry = staticData.buildings[buildingId];
	if (entry && Array.isArray(entry.routes)) {
		return entry.routes.map((value: string) => value.toLowerCase());
	}
	return [];
}

function computeCapacity(storageLevel: number, storageRoute: string, hqPath: string): number {
	const base = getBalanceNumber("storage_base_capacity", 1000);
	const perLevel = getBalanceNumber("storage_capacity_per_level", 250);
	const level = Math.max(0, storageLevel);
	const routeMults = staticData.balance.storage_route_capacity_mult ?? {
		compact: 1.0,
		reactive: 1.1,
		sealed: 0.9
	};
	const hqMults = staticData.balance.hq_capacity_mult ?? {
		scientific: 1.05,
		chaotic: 1.0,
		industrial: 1.1
	};
	const routeMult = getMultiplier(routeMults, storageRoute.toLowerCase(), 1.0);
	const hqMult = getMultiplier(hqMults, hqPath.toLowerCase(), 1.0);
	return Math.floor(Math.max(0, (base + perLevel * level) * routeMult * hqMult));
}

function directiveActive(runtime: LabRuntime, id: string, at: number): boolean {
	const directive = runtime.directive;
	return !!directive && directive.id === id && directive.starts_at <= at && at < directive.ends_at;
}

function tickProduction(
	building: BuildingState,
	nowMs: number,
	level: number,
	route: string,
	storageRoute: string,
	hqPath: string,
	labRuntime: LabRuntime
): void {
	if (!building.runtime) {
		building.runtime = {};
	}
	const runtime = building.runtime;
	const lastTick = typeof runtime.last_tick == "number" ? runtime.last_tick : nowMs;
	if (nowMs < lastTick) {
		runtime.last_tick = nowMs;
		return;
	}
	let delta = nowMs - lastTick;
	const capHours = getBalanceNumber("offline_cap_hours", 12);
	const capMs = capHours * 3600 * 1000;
	if (capMs > 0 && delta > capMs) {
		delta = capMs;
	}
	if (delta <= 0) {
		runtime.last_tick = nowMs;
		return;
	}
	const end = nowMs;
	const start = end - delta;
	const boundaries = [start, end];
	for (const period of [labRuntime.directive, labRuntime.boosts.volatile_overclock, labRuntime.boosts.essence_turbo]) {
		if (!period) continue;
		const interval: any = period;
		for (const point of [interval.started_at ?? interval.starts_at ?? 0, interval.expires_at ?? interval.ends_at ?? 0]) if (point > start && point < end) boundaries.push(point);
	}
	boundaries.sort((a, b) => a - b);
	let produced = 0;
	for (let i = 1; i < boundaries.length; i++) {
		const from = boundaries[i - 1], to = boundaries[i], sample = from + (to - from) / 2;
		produced += computeOutputRate(level, route, storageRoute, hqPath, labRuntime, sample) * (to - from) / 1000 * (directiveActive(labRuntime, "production", sample) ? getBalanceNumber("hq_directive_production_mult", 1.1) : 1);
	}
	runtime.stored_output = Math.max(0, (runtime.stored_output ?? 0) + produced);
	runtime.last_tick = nowMs;
}

function computeOutputRate(
	level: number,
	route: string,
	storageRoute: string,
	hqPath: string,
	labRuntime: LabRuntime,
	nowMs: number
): number {
	const base = getBalanceNumber("reactor_base_rate", 1.0);
	const perLevel = getBalanceNumber("reactor_rate_per_level", 0.2);
	const routeMults = staticData.balance.reactor_route_output_mult ?? {
		stable: 0.8,
		volatile: 1.35,
		mutagenic: 0.65
	};
	const storageMults = staticData.balance.storage_route_output_mult ?? {
		reactive: 1.05
	};
	const hqMults = staticData.balance.route_multipliers ?? staticData.balance.hq_output_mult ?? {
		scientific: 1.05,
		chaotic: 1.0,
		industrial: 0.95
	};
	const lvl = Math.max(0, level);
	const baseRate = base + perLevel * lvl;
	const routeMult = getMultiplier(routeMults, route.toLowerCase(), 1.0);
	const storageMult = getMultiplier(storageMults, storageRoute.toLowerCase(), 1.0);
	const hqMult = getMultiplier(hqMults, hqPath.toLowerCase(), 1.0);
	const boosts = getBoostMultipliers(labRuntime, nowMs);
	return Math.max(0, baseRate * routeMult * storageMult * hqMult * boosts.outputMult);
}

function claimProduction(
	building: BuildingState,
	capacity: number,
	route: string,
	storageRoute: string,
	hqPath: string,
	labRuntime: LabRuntime,
	nowMs: number
): { grants: Record<string, number> } {
	if (!building.runtime) {
		building.runtime = {};
	}
	const runtime = building.runtime;
	const available = Math.max(0, runtime.stored_output ?? 0);
	const cap = Math.max(0, capacity);
	const claimable = Math.min(available, cap);
	const boosts = getBoostMultipliers(labRuntime, nowMs);
	let loss = 0;
	if (route.toLowerCase() == "volatile" && claimable > 0) {
		let lossChance = getBalanceNumber("volatile_loss_chance", 0.25);
		lossChance *= getMultiplier(
			staticData.balance.hq_risk_mult ?? { scientific: 0.9, chaotic: 1.1, industrial: 0.85 },
			hqPath.toLowerCase(),
			1.0
		);
		lossChance *= boosts.lossChanceMult;
		lossChance = clampChance(lossChance);
		if (Math.random() < lossChance) {
			let lossPct = getBalanceNumber("volatile_loss_pct", 0.3);
			if (storageRoute.toLowerCase() == "compact") {
				lossPct *= getBalanceNumber("compact_loss_mult", 0.5);
			}
			lossPct = clampChance(lossPct);
			loss = claimable * lossPct;
		}
	}
	const claimed = Math.max(0, claimable - loss);
	runtime.stored_output = Math.max(0, available - claimable);
	const grants: Record<string, number> = { essence: Math.floor(claimed) };
	if (route.toLowerCase() == "mutagenic" && claimed > 0) {
		const rareChance = getMutagenicRareChance(storageRoute, hqPath, boosts.rareChanceMult);
		if (Math.random() < rareChance) {
			grants.arcane_shard = 1;
		}
	}
	return { grants };
}

function getMutagenicRareChance(storageRoute: string, hqPath: string, boostMult = 1.0): number {
	let chance = getBalanceNumber("mutagenic_rare_base_chance", 0.08);
	if (storageRoute.toLowerCase() == "sealed") {
		chance *= getBalanceNumber("sealed_rare_mult", 1.25);
	}
	const hqRare = staticData.balance.hq_rare_mult ?? { scientific: 0.9, chaotic: 1.1, industrial: 0.85 };
	chance *= getMultiplier(hqRare, hqPath.toLowerCase(), 1.0);
	chance *= boostMult;
	const cap = getBalanceNumber("mutagenic_rare_cap", 0.25);
	return clampChance(Math.min(chance, cap));
}

function getBalanceNumber(key: string, fallback: number): number {
	const value = staticData.balance[key];
	if (typeof value == "number" && Number.isFinite(value)) {
		return value;
	}
	return fallback;
}

function getMultiplier(map: any, key: string, fallback: number): number {
	if (map && typeof map == "object" && map[key] != null) {
		const value = map[key];
		if (typeof value == "number" && Number.isFinite(value)) {
			return value;
		}
	}
	if (map && typeof map == "object") {
		for (const [mapKey, value] of Object.entries(map)) {
			if (mapKey.toLowerCase() == key.toLowerCase()) {
				if (typeof value == "number" && Number.isFinite(value)) {
					return value;
				}
			}
		}
	}
	return fallback;
}

function clampChance(value: number): number {
	if (!Number.isFinite(value)) {
		return 0;
	}
	return Math.max(0, Math.min(value, 1));
}

function getMarketFeeBps(): number {
	return clampInt(getBalanceNumber("market_fee_bps", 200), 0, 10_000);
}

function ensureWorldState(now: number): WorldStateData {
	const row = getWorldStmt.get() as { state_json: string; updated_at: number } | undefined;
	const parsed = parseWorldState(row?.state_json);
	let changed = false;
	let state = parsed ?? createDefaultWorldState(now);
	if (!parsed) {
		changed = true;
	}
	const normalized = normalizeWorldState(state, now);
	state = normalized.state;
	changed = changed || normalized.changed;
	if (changed) {
		state.updated_at = now;
		if (row) {
			updateWorldStmt.run(JSON.stringify(state), now);
		} else {
			insertWorldStmt.run(JSON.stringify(state), now);
		}
	}
	return state;
}

function parseWorldState(stateJson?: string | null): WorldStateData | null {
	if (!stateJson) {
		return null;
	}
	try {
		const parsed = JSON.parse(stateJson);
		if (!parsed || typeof parsed != "object") {
			return null;
		}
		const zones = Array.isArray((parsed as any).zones) ? (parsed as any).zones : [];
		const activeEvents = Array.isArray((parsed as any).active_events) ? (parsed as any).active_events : [];
		const bosses = Array.isArray((parsed as any).bosses) ? (parsed as any).bosses : [];
		const updatedAt = clampInt((parsed as any).updated_at ?? 0, 0, Number.MAX_SAFE_INTEGER);
		return {
			zones,
			active_events: activeEvents,
			bosses,
			updated_at: updatedAt
		};
	} catch {
		return null;
	}
}

function normalizeWorldState(
	state: WorldStateData,
	now: number
): { state: WorldStateData; changed: boolean } {
	let changed = false;
	const zoneMap = new Map<string, ZoneRotation>();
	if (Array.isArray(state.zones)) {
		for (const entry of state.zones) {
			if (!entry || typeof entry.zone_id != "string") {
				changed = true;
				continue;
			}
			const zoneId = entry.zone_id.trim();
			if (!zoneId || zoneMap.has(zoneId)) {
				changed = true;
				continue;
			}
			zoneMap.set(zoneId, {
				zone_id: zoneId,
				modifier_ids: normalizeModifierList(entry.modifier_ids),
				rotation_ends_at: clampInt(entry.rotation_ends_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
				seed: typeof entry.seed == "string" ? entry.seed : ""
			});
		}
	} else {
		changed = true;
	}
	const zones: ZoneRotation[] = [];
	const rotationMs = getWorldRotationMs();
	const zoneDefs = Object.values(staticData.zones);
	for (const zone of zoneDefs) {
		let entry = zoneMap.get(zone.id);
		if (!entry) {
			entry = createZoneRotation(zone, now, rotationMs);
			changed = true;
		} else if (!entry.seed) {
			entry.seed = createZoneSeed(zone.id, now);
			changed = true;
		}
		if (!Number.isFinite(entry.rotation_ends_at) || entry.rotation_ends_at <= now) {
			entry = createZoneRotation(zone, now, rotationMs);
			changed = true;
		} else {
			const sanitized = sanitizeModifierIds(entry.modifier_ids, zone);
			if (sanitized.length != entry.modifier_ids.length) {
				entry.modifier_ids = sanitized;
				changed = true;
			}
		}
		zones.push(entry);
	}
	const activeEvents = Array.isArray(state.active_events) ? state.active_events : [];
	if (!Array.isArray(state.active_events)) {
		changed = true;
	}
	const bossMap = new Map<string, BossState>();
	if (Array.isArray(state.bosses)) {
		for (const entry of state.bosses) {
			if (!entry || typeof entry.boss_id != "string") {
				changed = true;
				continue;
			}
			const bossId = entry.boss_id.trim();
			if (!bossId || bossMap.has(bossId)) {
				changed = true;
				continue;
			}
			const contributors =
				entry.contributors && typeof entry.contributors == "object" ? entry.contributors : {};
			bossMap.set(bossId, {
				boss_id: bossId,
				hp: clampInt(entry.hp ?? 0, 0, Number.MAX_SAFE_INTEGER),
				max_hp: clampInt(entry.max_hp ?? 0, 0, Number.MAX_SAFE_INTEGER),
				phase: clampInt(entry.phase ?? 1, 1, 99),
				window_starts_at: clampInt(entry.window_starts_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
				window_ends_at: clampInt(entry.window_ends_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
				modifiers: normalizeModifierList(entry.modifiers),
				contributors: contributors as Record<string, number>
			});
		}
	} else {
		changed = true;
	}
	const bosses: BossState[] = [];
	const bossDefs = Object.values(staticData.bosses);
	for (const boss of bossDefs) {
		let entry = bossMap.get(boss.id);
		if (!entry) {
			entry = createBossState(boss, now);
			changed = true;
		} else {
			const normalized = normalizeBossState(entry, boss, now);
			entry = normalized.boss;
			if (normalized.changed) {
				changed = true;
			}
		}
		bosses.push(entry);
	}
	return {
		state: {
			zones,
			active_events: activeEvents,
			bosses,
			updated_at: state.updated_at ?? now
		},
		changed
	};
}

function createDefaultWorldState(now: number): WorldStateData {
	const rotationMs = getWorldRotationMs();
	const zones: ZoneRotation[] = [];
	for (const zone of Object.values(staticData.zones)) {
		zones.push(createZoneRotation(zone, now, rotationMs));
	}
	const bosses: BossState[] = [];
	for (const boss of Object.values(staticData.bosses)) {
		bosses.push(createBossState(boss, now));
	}
	return {
		zones,
		active_events: [],
		bosses,
		updated_at: now
	};
}

function createZoneRotation(zone: ZoneDef, now: number, rotationMs: number): ZoneRotation {
	const seed = createZoneSeed(zone.id, now);
	const modifierIds = rollZoneModifiers(zone, seed);
	return {
		zone_id: zone.id,
		modifier_ids: modifierIds,
		rotation_ends_at: now + rotationMs,
		seed
	};
}

function createZoneSeed(zoneId: string, now: number): string {
	return createHash("sha256").update(`${WORLD_SECRET}:${zoneId}:${now}`).digest("hex");
}

function sanitizeModifierIds(raw: string[], zone: ZoneDef): string[] {
	const allow = Array.isArray(zone.modifiers) ? zone.modifiers : [];
	if (allow.length == 0) {
		return raw.filter((value) => value && value.trim().length > 0);
	}
	const allowed = new Set<string>(allow.map((value) => value.trim()).filter((value) => value.length > 0));
	return raw.filter((value) => value && allowed.has(value.trim()));
}

function rollZoneModifiers(zone: ZoneDef, seed: string): string[] {
	const list = Array.isArray(zone.modifiers)
		? zone.modifiers.map((value) => value.trim()).filter((value) => value.length > 0)
		: [];
	if (list.length == 0) {
		return [];
	}
	const desired = clampInt(getBalanceNumber("world_modifiers_per_zone", 1), 0, list.length);
	if (desired <= 0) {
		return [];
	}
	const pool = list.slice();
	const selected: string[] = [];
	for (let i = 0; i < desired; i++) {
		const roll = seededRandom01(`${seed}:mod:${i}`);
		const idx = Math.min(pool.length - 1, Math.floor(roll * pool.length));
		selected.push(pool.splice(idx, 1)[0]);
		if (pool.length == 0) {
			break;
		}
	}
	return selected;
}

function createBossState(boss: BossDef, now: number): BossState {
	const maxHp = getBossMaxHp(boss);
	const window = getBossWindowTimes(boss.id, now);
	const seed = createHash("sha256").update(`${WORLD_SECRET}:boss:${boss.id}:${window.start}`).digest("hex");
	const modifiers = rollBossModifiers(boss, seed);
	return {
		boss_id: boss.id,
		hp: maxHp,
		max_hp: maxHp,
		phase: 1,
		window_starts_at: window.start,
		window_ends_at: window.end,
		modifiers,
		contributors: {}
	};
}

function normalizeBossState(
	entry: BossState,
	boss: BossDef,
	now: number
): { boss: BossState; changed: boolean } {
	let changed = false;
	let bossState = { ...entry };
	const maxHp = getBossMaxHp(boss);
	if (bossState.max_hp <= 0 || bossState.max_hp != maxHp) {
		bossState.max_hp = maxHp;
		if (bossState.hp > maxHp) {
			bossState.hp = maxHp;
		}
		changed = true;
	}
	const window = getBossWindowTimes(boss.id, now);
	const windowInvalid =
		bossState.window_ends_at <= now ||
		bossState.window_starts_at != window.start ||
		bossState.window_ends_at != window.end;
	if (windowInvalid) {
		bossState = createBossState(boss, now);
		changed = true;
	} else {
		const sanitized = sanitizeBossModifiers(bossState.modifiers, boss);
		if (sanitized.length != bossState.modifiers.length) {
			bossState.modifiers = sanitized;
			changed = true;
		}
		bossState.phase = computeBossPhase(bossState.hp, bossState.max_hp);
	}
	return { boss: bossState, changed };
}

function getBossWindowTimes(bossId: string, now: number): { start: number; end: number } {
	const intervalMs = getBossIntervalMs();
	const windowMs = getBossWindowMs();
	const offsetLimit = Math.max(1, intervalMs - windowMs);
	const hash = createHash("sha256").update(`${WORLD_SECRET}:boss_offset:${bossId}`).digest();
	const offsetRaw = hash.readUInt32BE(0) % offsetLimit;
	const base = Math.floor((now - offsetRaw) / intervalMs) * intervalMs + offsetRaw;
	return { start: base, end: base + windowMs };
}

function getBossIntervalMs(): number {
	const minutes = getBalanceNumber("boss_interval_minutes", 120);
	return Math.max(1, minutes) * 60 * 1000;
}

function getBossWindowMs(): number {
	const minutes = getBalanceNumber("boss_window_minutes", 15);
	return Math.max(1, minutes) * 60 * 1000;
}

function getBossMaxHp(boss: BossDef): number {
	const map = staticData.balance.boss_hp;
	if (map && typeof map == "object" && map[boss.id] != null) {
		const value = map[boss.id];
		if (typeof value == "number" && Number.isFinite(value) && value > 0) {
			return Math.floor(value);
		}
	}
	const base = getBalanceNumber("boss_base_hp", boss.max_hp ?? 50000);
	const multMap = staticData.balance.boss_hp_mult;
	if (multMap && typeof multMap == "object" && multMap[boss.id] != null) {
		const mult = multMap[boss.id];
		if (typeof mult == "number" && Number.isFinite(mult) && mult > 0) {
			return Math.floor(base * mult);
		}
	}
	return Math.max(1, Math.floor(base));
}

function sanitizeBossModifiers(raw: string[], boss: BossDef): string[] {
	const allow = Array.isArray(boss.modifiers) ? boss.modifiers : [];
	if (allow.length == 0) {
		return raw.filter((value) => value && value.trim().length > 0);
	}
	const allowed = new Set<string>(allow.map((value) => value.trim()).filter((value) => value.length > 0));
	return raw.filter((value) => value && allowed.has(value.trim()));
}

function rollBossModifiers(boss: BossDef, seed: string): string[] {
	const list = Array.isArray(boss.modifiers)
		? boss.modifiers.map((value) => value.trim()).filter((value) => value.length > 0)
		: [];
	const pool = list.length > 0 ? list : getBossModifierPool();
	if (pool.length == 0) {
		return [];
	}
	const desired = clampInt(getBalanceNumber("boss_modifiers_per_window", 1), 0, pool.length);
	if (desired <= 0) {
		return [];
	}
	const pickPool = pool.slice();
	const selected: string[] = [];
	for (let i = 0; i < desired; i++) {
		const roll = seededRandom01(`${seed}:boss_mod:${i}`);
		const idx = Math.min(pickPool.length - 1, Math.floor(roll * pickPool.length));
		selected.push(pickPool.splice(idx, 1)[0]);
		if (pickPool.length == 0) {
			break;
		}
	}
	return selected;
}

function getBossModifierPool(): string[] {
	const pool = staticData.balance.boss_modifier_pool;
	if (Array.isArray(pool)) {
		return pool
			.map((value: any) => (typeof value == "string" ? value.trim() : ""))
			.filter((value: string) => value.length > 0);
	}
	return ["feral_rage", "arcane_flux", "void_surge"];
}

function computeBossPhase(hp: number, maxHp: number): number {
	if (maxHp <= 0) {
		return 1;
	}
	if (hp <= 0) {
		return getBossPhaseThresholds().length + 1;
	}
	const ratio = hp / maxHp;
	const thresholds = getBossPhaseThresholds();
	let phase = 1;
	for (let i = 0; i < thresholds.length; i++) {
		if (ratio <= thresholds[i]) {
			phase = i + 2;
		}
	}
	return Math.max(1, phase);
}

function getBossPhaseThresholds(): number[] {
	const raw = staticData.balance.boss_phase_thresholds;
	if (Array.isArray(raw)) {
		const list = raw
			.map((value: any) => (typeof value == "number" ? value : Number(value)))
			.filter((value: number) => Number.isFinite(value) && value > 0 && value < 1)
			.sort((a: number, b: number) => b - a);
		if (list.length > 0) {
			return list;
		}
	}
	return [0.66, 0.33];
}

function getBossFromWorld(worldState: WorldStateData, bossId: string): BossState | null {
	for (const entry of worldState.bosses) {
		if (entry.boss_id == bossId) {
			return entry;
		}
	}
	return null;
}

function getPlayerPowerScore(state: PlayerState): number {
	const hqLevel = clampInt(state.lab.hqLevel ?? 1, 0, 999);
	const hqMult = getBalanceNumber("boss_power_hq_mult", 10);
	const buildingMult = getBalanceNumber("boss_power_building_mult", 2);
	let total = hqLevel * hqMult;
	const buildings = state.lab.buildings || {};
	for (const [id, entry] of Object.entries(buildings)) {
		if (id == "lab_th") {
			continue;
		}
		const level = clampInt((entry as any)?.level ?? 0, 0, 999);
		total += level * buildingMult;
	}
	if (!Number.isFinite(total) || total <= 0) {
		total = 1;
	}
	return Math.floor(total);
}

function computeBossTokens(damage: number): number {
	const divisor = Math.max(1, getBalanceNumber("boss_token_divisor", 1000));
	const tokens = Math.floor(damage / divisor);
	return clampInt(tokens, 0, 1_000_000);
}

function computeBossRewards(
	boss: BossState,
	playerId: string
): { rewardTier: string; grants: ResourceWallet } {
	const entries = Object.entries(boss.contributors)
		.map(([id, value]) => ({ id, value: clampInt(value, 0, Number.MAX_SAFE_INTEGER) }))
		.filter((entry) => entry.value > 0)
		.sort((a, b) => b.value - a.value);
	const total = entries.length;
	if (total == 0) {
		return { rewardTier: "none", grants: {} };
	}
	let rankIndex = -1;
	for (let i = 0; i < entries.length; i++) {
		if (entries[i].id == playerId) {
			rankIndex = i;
			break;
		}
	}
	if (rankIndex < 0) {
		return { rewardTier: "none", grants: {} };
	}
	const percentile = (rankIndex + 1) / total;
	let tier = "t4";
	if (percentile <= 0.1) {
		tier = "t1";
	} else if (percentile <= 0.25) {
		tier = "t2";
	} else if (percentile <= 0.5) {
		tier = "t3";
	}
	const base = getBossRewardTable(tier);
	const phaseBonus = getBalanceNumber("boss_reward_phase_bonus", 0.1);
	const phaseMult = Math.max(0, 1 + (boss.phase - 1) * phaseBonus);
	const grants: ResourceWallet = {};
	for (const [resId, amountRaw] of Object.entries(base)) {
		if (!isValidResourceId(resId)) {
			continue;
		}
		const amount = clampInt(amountRaw, 0, 1_000_000);
		const finalAmount = Math.floor(amount * phaseMult);
		if (finalAmount > 0) {
			grants[resId] = finalAmount;
		}
	}
	return { rewardTier: tier, grants };
}

function getBossRewardTable(tier: string): Record<string, number> {
	const table = staticData.balance.boss_rewards;
	if (table && typeof table == "object") {
		const entry = (table as any)[tier];
		if (entry && typeof entry == "object") {
			return entry as Record<string, number>;
		}
	}
	if (tier == "t1") {
		return { arcane_shard: 5, time_crystal: 5 };
	}
	if (tier == "t2") {
		return { arcane_shard: 3, time_crystal: 1 };
	}
	if (tier == "t3") {
		return { arcane_shard: 2 };
	}
	return { arcane_shard: 1 };
}

function getZoneRotation(world: WorldStateData, zoneId: string): ZoneRotation | null {
	for (const entry of world.zones) {
		if (entry.zone_id == zoneId) {
			return entry;
		}
	}
	return null;
}

function computeZoneDrops(zone: ZoneDef, heat: number, seedBase: string): ResourceWallet {
	const loot: ResourceWallet = {};
	const minAmount = clampInt(getBalanceNumber("world_drop_min", 1), 0, 1_000_000);
	const maxAmount = clampInt(getBalanceNumber("world_drop_max", 3), minAmount, 1_000_000);
	const amountRoll = seededRandom01(`${seedBase}:amount`);
	const baseAmount = Math.floor(minAmount + (maxAmount - minAmount) * amountRoll);
	const hazardChance = clampChance(
		getBalanceNumber("world_hazard_base_chance", 0.02) +
			heat * getBalanceNumber("world_heat_hazard_bonus", 0.003)
	);
	let finalAmount = baseAmount;
	if (seededRandom01(`${seedBase}:hazard`) < hazardChance) {
		finalAmount = Math.floor(finalAmount * getBalanceNumber("world_hazard_loss_mult", 0.6));
	}
	if (finalAmount > 0) {
		const resourceId = pickWeightedResource(zone.drops, `${seedBase}:drop`);
		if (resourceId) {
			loot[resourceId] = (loot[resourceId] ?? 0) + finalAmount;
		}
	}
	const rareChance = clampChance(
		getBalanceNumber("world_rare_base_chance", 0.05) +
			heat * getBalanceNumber("world_heat_rare_bonus", 0.002)
	);
	if (seededRandom01(`${seedBase}:rare`) < rareChance) {
		const rareTable =
			zone.rare_drops && Object.keys(zone.rare_drops).length > 0 ? zone.rare_drops : zone.drops;
		const rareId = pickWeightedResource(rareTable, `${seedBase}:rare_drop`);
		const rareAmount = clampInt(getBalanceNumber("world_rare_amount", 1), 0, 1_000_000);
		if (rareId && rareAmount > 0) {
			loot[rareId] = (loot[rareId] ?? 0) + rareAmount;
		}
	}
	return loot;
}

function pickWeightedResource(table: ZoneDropTable, seed: string): string {
	const entries = Object.entries(table).filter(([id, weight]) => {
		if (!id || !isValidResourceId(id)) {
			return false;
		}
		return Number.isFinite(weight) && weight > 0;
	});
	if (entries.length == 0) {
		return isValidResourceId("essence") ? "essence" : "";
	}
	let total = 0;
	for (const [, weight] of entries) {
		total += Number(weight);
	}
	if (total <= 0) {
		return entries[0][0];
	}
	const roll = seededRandom01(seed) * total;
	let acc = 0;
	for (const [id, weight] of entries) {
		acc += Number(weight);
		if (roll <= acc) {
			return id;
		}
	}
	return entries[entries.length - 1][0];
}

function makeWorldSessionId(playerId: string, clientActionId: string, zoneId: string): string {
	const seed = `${WORLD_SECRET}:${playerId}:${clientActionId}:${zoneId}:world_session`;
	return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}

function makeOrderId(playerId: string, clientActionId: string): string {
	const seed = `${playerId}:${clientActionId}:order`;
	return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}

function makeTradeJobId(providerId: string, clientActionId: string): string {
	const seed = `${providerId}:${clientActionId}:trade_job`;
	return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}

function makeTradeRunId(customerId: string, clientActionId: string, jobId: string): string {
	const seed = `${customerId}:${clientActionId}:${jobId}:trade_run`;
	return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}

function computeTradeOutput(minValue: number, maxValue: number, seed: string): number {
	const min = clampInt(minValue, 0, TRADE_MAX_AMOUNT);
	const max = clampInt(maxValue, 0, TRADE_MAX_AMOUNT);
	if (max <= 0 && min <= 0) {
		return 0;
	}
	const low = Math.min(min, max);
	const high = Math.max(min, max);
	if (high <= 0) {
		return 0;
	}
	const range = high - low + 1;
	const roll = seededRandom01(seed);
	return low + Math.floor(roll * range);
}

function normalizeTradeJobInput(body: any): { ok: true; data: Record<string, any> } | { ok: false; error: string } {
	const inputResourceId =
		typeof body?.input_resource_id == "string" ? body.input_resource_id.trim() : "";
	const outputResourceId =
		typeof body?.output_resource_id == "string" ? body.output_resource_id.trim() : "";
	if (!inputResourceId || !isValidResourceId(inputResourceId)) {
		return { ok: false, error: "Unknown input_resource_id." };
	}
	if (!outputResourceId || !isValidResourceId(outputResourceId)) {
		return { ok: false, error: "Unknown output_resource_id." };
	}
	const inputAmount = clampInt(body?.input_amount ?? 0, 0, TRADE_MAX_AMOUNT);
	if (inputAmount <= 0) {
		return { ok: false, error: "Invalid input_amount." };
	}
	const outputMin = clampInt(body?.output_min ?? 0, 0, TRADE_MAX_AMOUNT);
	const outputMax = clampInt(body?.output_max ?? 0, 0, TRADE_MAX_AMOUNT);
	if (outputMin <= 0 || outputMax <= 0 || outputMin > outputMax) {
		return { ok: false, error: "Invalid output range." };
	}
	const durationSec = clampInt(body?.duration_sec ?? 0, 0, TRADE_MAX_DURATION_SEC);
	let commissionResourceId =
		typeof body?.commission_resource_id == "string" ? body.commission_resource_id.trim() : "";
	if (!commissionResourceId) {
		commissionResourceId = "essence";
	}
	if (!isValidResourceId(commissionResourceId)) {
		return { ok: false, error: "Unknown commission_resource_id." };
	}
	const commissionAmount = clampInt(body?.commission_amount ?? 0, 0, TRADE_MAX_AMOUNT);
	const queueLimit = clampInt(body?.queue_limit ?? 1, 1, TRADE_MAX_QUEUE);
	return {
		ok: true,
		data: {
			inputResourceId,
			inputAmount,
			outputResourceId,
			outputMin,
			outputMax,
			durationSec,
			commissionResourceId,
			commissionAmount,
			queueLimit
		}
	};
}

function createTradeJob(
	providerId: string,
	clientActionId: string,
	body: any
): { state?: PlayerState; jobId?: string; error?: string } {
	const normalized = normalizeTradeJobInput(body);
	if (!normalized.ok) {
		return { error: normalized.error };
	}
	const {
		inputResourceId,
		inputAmount,
		outputResourceId,
		outputMin,
		outputMax,
		durationSec,
		commissionResourceId,
		commissionAmount,
		queueLimit
	} = normalized.data;
	const jobId = makeTradeJobId(providerId, clientActionId);
	const now = Date.now();
	let state: PlayerState | null = null;
	db.transaction(() => {
		state = ensurePlayerState(providerId);
		const existing = getTradeJobStmt.get(jobId) as Record<string, any> | undefined;
		if (!existing) {
			insertTradeJobStmt.run(
				jobId,
				providerId,
				inputResourceId,
				inputAmount,
				outputResourceId,
				outputMin,
				outputMax,
				durationSec,
				commissionResourceId,
				commissionAmount,
				queueLimit,
				TRADE_JOB_STATUS_OPEN,
				now
			);
		}
		state.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(state), now, providerId);
		insertActionStmt.run(
			providerId,
			clientActionId,
			"TRADE_JOB_CREATE",
			JSON.stringify(body ?? {}),
			JSON.stringify(state),
			now
		);
	})();
	if (!state) {
		return { error: "Failed to resolve provider state." };
	}
	return { state, jobId };
}

function submitTradeRun(
	customerId: string,
	clientActionId: string,
	body: any
): { state?: PlayerState; runId?: string; completesAt?: number; error?: string } {
	const jobId = typeof body?.job_id == "string" ? body.job_id.trim() : "";
	if (!jobId) {
		return { error: "Missing job_id." };
	}
	const stored = getIdempotentState(customerId, clientActionId, "TRADE_SUBMIT", body);
	const runId = makeTradeRunId(customerId, clientActionId, jobId);
	if (stored) {
		const existingRun = getTradeRunStmt.get(runId) as Record<string, any> | undefined;
		return {
			state: stored,
			runId,
			completesAt: existingRun ? Number(existingRun.completes_at ?? 0) : undefined
		};
	}
	const job = getTradeJobStmt.get(jobId) as Record<string, any> | undefined;
	if (!job) {
		return { error: "Trade job not found." };
	}
	const existingRun = getTradeRunStmt.get(runId) as Record<string, any> | undefined;
	if (existingRun) {
		const current = ensurePlayerState(customerId);
		return { state: current, runId, completesAt: Number(existingRun.completes_at ?? 0) };
	}
	if (String(job.status).toUpperCase() != TRADE_JOB_STATUS_OPEN) {
		return { error: "Trade job not open." };
	}
	if (job.provider_id == customerId) {
		return { error: "Cannot submit to your own trade job." };
	}
	const pendingRow = countTradeRunsStmt.get(jobId, TRADE_RUN_STATUS_PENDING) as
		| { count: number }
		| undefined;
	const pending = pendingRow ? clampInt(pendingRow.count, 0, TRADE_MAX_QUEUE) : 0;
	const queueLimit = clampInt(job.queue_limit, 1, TRADE_MAX_QUEUE);
	if (pending >= queueLimit) {
		return { error: "Trade job queue is full." };
	}
	const inputResourceId = String(job.input_resource_id || "");
	const outputResourceId = String(job.output_resource_id || "");
	const commissionResourceId = String(job.commission_resource_id || "essence");
	if (!isValidResourceId(inputResourceId) || !isValidResourceId(outputResourceId)) {
		return { error: "Invalid trade job resources." };
	}
	if (!isValidResourceId(commissionResourceId)) {
		return { error: "Invalid commission resource." };
	}
	const inputAmount = clampInt(job.input_amount, 0, TRADE_MAX_AMOUNT);
	const commissionAmount = clampInt(job.commission_amount, 0, TRADE_MAX_AMOUNT);
	if (inputAmount <= 0) {
		return { error: "Invalid trade job input amount." };
	}
	const customerState = ensurePlayerState(customerId);
	const required: Record<string, number> = {};
	required[inputResourceId] = (required[inputResourceId] ?? 0) + inputAmount;
	if (commissionAmount > 0) {
		required[commissionResourceId] = (required[commissionResourceId] ?? 0) + commissionAmount;
	}
	for (const [resId, amount] of Object.entries(required)) {
		if (isSuspiciousAmount(amount)) {
			logSuspiciousAction(customerId, { [resId]: -amount }, "TRADE_SUBMIT", runId);
			return { error: "Suspicious trade submit amount." };
		}
	}
	for (const [resId, amount] of Object.entries(required)) {
		if ((customerState.wallet[resId] ?? 0) < amount) {
			return { error: "Insufficient resources." };
		}
	}
	const now = Date.now();
	const completesAt = now + clampInt(job.duration_sec, 0, TRADE_MAX_DURATION_SEC) * 1000;
	const rngSeed = createHash("sha256").update(`${TRADE_SECRET}:${runId}`).digest("hex");
	db.transaction(() => {
		const beforeWallet = cloneWallet(customerState.wallet);
		for (const [resId, amount] of Object.entries(required)) {
			customerState.wallet[resId] = (customerState.wallet[resId] ?? 0) - amount;
			if (customerState.wallet[resId] < 0) {
				customerState.wallet[resId] = 0;
			}
			addEscrow(customerId, resId, amount);
		}
		assertWalletInvariant(customerState.wallet);
		insertTradeRunStmt.run(
			runId,
			jobId,
			customerId,
			now,
			completesAt,
			inputAmount,
			TRADE_RUN_STATUS_PENDING,
			0,
			rngSeed
		);
		customerState.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(customerState), now, customerId);
		insertActionStmt.run(
			customerId,
			clientActionId,
			"TRADE_SUBMIT",
			JSON.stringify(body ?? {}),
			JSON.stringify(customerState),
			now
		);
		const delta = computeWalletDelta(beforeWallet, customerState.wallet);
		auditWalletMutation(customerId, delta, "TRADE_SUBMIT", runId, now);
	})();
	return { state: customerState, runId, completesAt };
}

function claimTradeRun(
	customerId: string,
	clientActionId: string,
	body: any
): { state?: PlayerState; outputAmount?: number; error?: string } {
	const runId = typeof body?.run_id == "string" ? body.run_id.trim() : "";
	if (!runId) {
		return { error: "Missing run_id." };
	}
	const stored = getIdempotentState(customerId, clientActionId, "TRADE_CLAIM", body);
	if (stored) {
		return { state: stored };
	}
	const run = getTradeRunStmt.get(runId) as Record<string, any> | undefined;
	if (!run) {
		return { error: "Trade run not found." };
	}
	if (run.customer_id != customerId) {
		return { error: "Trade run does not belong to player." };
	}
	if (String(run.status).toUpperCase() == TRADE_RUN_STATUS_CLAIMED) {
		return { error: "Trade run already claimed." };
	}
	const now = Date.now();
	const completesAt = clampInt(run.completes_at, 0, Number.MAX_SAFE_INTEGER);
	if (completesAt > now) {
		return { error: "Trade run not complete." };
	}
	const job = getTradeJobStmt.get(run.job_id) as Record<string, any> | undefined;
	if (!job) {
		return { error: "Trade job missing." };
	}
	const inputResourceId = String(job.input_resource_id || "");
	const outputResourceId = String(job.output_resource_id || "");
	const commissionResourceId = String(job.commission_resource_id || "essence");
	if (!isValidResourceId(inputResourceId) || !isValidResourceId(outputResourceId)) {
		return { error: "Invalid trade job resources." };
	}
	if (!isValidResourceId(commissionResourceId)) {
		return { error: "Invalid commission resource." };
	}
	const inputAmount = clampInt(job.input_amount, 0, TRADE_MAX_AMOUNT);
	const commissionAmount = clampInt(job.commission_amount, 0, TRADE_MAX_AMOUNT);
	const outputMin = clampInt(job.output_min, 0, TRADE_MAX_AMOUNT);
	const outputMax = clampInt(job.output_max, 0, TRADE_MAX_AMOUNT);
	let outputAmount = clampInt(run.output_amount, 0, TRADE_MAX_AMOUNT);
	const seed = run.rng_seed && String(run.rng_seed) != ""
		? String(run.rng_seed)
		: createHash("sha256").update(`${TRADE_SECRET}:${runId}`).digest("hex");
	if (outputAmount <= 0) {
		outputAmount = computeTradeOutput(outputMin, outputMax, seed);
	}
	const customerState = ensurePlayerState(customerId);
	const providerState = ensurePlayerState(job.provider_id);
	const required: Record<string, number> = {};
	required[inputResourceId] = (required[inputResourceId] ?? 0) + inputAmount;
	if (commissionAmount > 0) {
		required[commissionResourceId] = (required[commissionResourceId] ?? 0) + commissionAmount;
	}
	if (isSuspiciousAmount(outputAmount) || isSuspiciousAmount(commissionAmount)) {
		if (outputAmount > 0) {
			logSuspiciousAction(customerId, { [outputResourceId]: outputAmount }, "TRADE_CLAIM", runId);
		}
		if (commissionAmount > 0) {
			logSuspiciousAction(job.provider_id, { [commissionResourceId]: commissionAmount }, "TRADE_CLAIM", runId);
		}
		return { error: "Suspicious trade claim amount." };
	}
	db.transaction(() => {
		const beforeCustomer = cloneWallet(customerState.wallet);
		const beforeProvider = cloneWallet(providerState.wallet);
		for (const [resId, amount] of Object.entries(required)) {
			if (!subtractEscrow(customerId, resId, amount)) {
				throw new HttpError(400, "Escrow mismatch.");
			}
		}
		updateTradeRunStmt.run(TRADE_RUN_STATUS_CLAIMED, outputAmount, runId);
		if (outputAmount > 0) {
			applyWalletGrant(customerState.wallet, { [outputResourceId]: outputAmount });
		}
		if (commissionAmount > 0) {
			providerState.wallet[commissionResourceId] =
				clampAmount(providerState.wallet[commissionResourceId] ?? 0) + commissionAmount;
		}
		assertWalletInvariant(customerState.wallet);
		assertWalletInvariant(providerState.wallet);
		customerState.updated_at = now;
		providerState.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(customerState), now, customerId);
		updatePlayerStmt.run(JSON.stringify(providerState), now, job.provider_id);
		insertActionStmt.run(
			customerId,
			clientActionId,
			"TRADE_CLAIM",
			JSON.stringify(body ?? {}),
			JSON.stringify(customerState),
			now
		);
		const customerDelta = computeWalletDelta(beforeCustomer, customerState.wallet);
		const providerDelta = computeWalletDelta(beforeProvider, providerState.wallet);
		auditWalletMutation(customerId, customerDelta, "TRADE_CLAIM_CUSTOMER", runId, now);
		auditWalletMutation(job.provider_id, providerDelta, "TRADE_CLAIM_PROVIDER", runId, now);
	})();
	return { state: customerState, outputAmount };
}

function enterWorldSession(
	playerId: string,
	clientActionId: string,
	body: any,
	debugBypass = false
): { state?: PlayerState; sessionId?: string; zoneId?: string; modifiers?: string[]; error?: string } {
	const zoneId = typeof body?.zone_id == "string" ? body.zone_id.trim() : "";
	if (!zoneId) {
		return { error: "Missing zone_id." };
	}
	if (!isValidZoneId(zoneId)) {
		return { error: "Unknown zone_id." };
	}
	const stored = getIdempotentState(playerId, clientActionId, "WORLD_ENTER", body);
	const sessionId = makeWorldSessionId(playerId, clientActionId, zoneId);
	if (stored) {
		return { state: stored, sessionId, zoneId, modifiers: stored.world.sessions[sessionId]?.modifiers ?? [] };
	}
	const now = Date.now();
	const entryFee = getWorldEntryFee();
	if (entryFee > 0 && isSuspiciousAmount(entryFee)) {
		logSuspiciousAction(playerId, { essence: -entryFee }, "WORLD_ENTER", zoneId);
		return { error: "Suspicious entry fee." };
	}
	let state: PlayerState | null = null;
	let modifiers: string[] = [];
	db.transaction(() => {
		state = ensurePlayerState(playerId);
		const beforeWallet = cloneWallet(state.wallet);
		const world = ensurePlayerWorld(state, now);
		const cooldownMs = Math.max(0, Math.floor(getBalanceNumber("world_gate_cooldown_seconds", 3600) * 1000));
		const remainingMs = world.last_gate_entry_at > 0 ? Math.max(0, world.last_gate_entry_at + cooldownMs - now) : 0;
		if (remainingMs > 0) throw new HttpError(400, `World Gate cooldown: ${Math.ceil(remainingMs / 1000)} seconds remaining.`);
		const zoneRotation = getZoneRotation(ensureWorldState(now), zoneId);
		if (!zoneRotation) throw new HttpError(400, "Zone is not available.");
		modifiers = zoneRotation.modifier_ids.slice();
		refreshWorldPlayer(world, now);
		if (!debugBypass) {
			const gate = ensureBuildingState(state, "world_gate");
			if (gate.level <= 0) {
				throw new HttpError(400, "World Gate locked.");
			}
			const dailyLimit = getWorldDailyEntryLimit();
			if (world.daily_entries >= dailyLimit) {
				throw new HttpError(400, "Daily entry limit reached.");
			}
			if (entryFee > 0) {
				const essence = clampAmount(state.wallet.essence ?? 0);
				if (essence < entryFee) {
					throw new HttpError(400, "Insufficient Essence for entry fee.");
				}
				state.wallet.essence = essence - entryFee;
			}
		}
		if (!world.sessions[sessionId]) {
			world.sessions[sessionId] = {
				session_id: sessionId,
				zone_id: zoneId,
				started_at: now,
				last_farm_at: 0,
				pending_loot: {},
				blocks_farmed: 0,
				modifiers: zoneRotation.modifier_ids.slice()
			};
		}
		world.daily_entries += 1;
		world.last_gate_entry_at = now;
		assertWalletInvariant(state.wallet);
		state.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(state), now, playerId);
		insertActionStmt.run(
			playerId,
			clientActionId,
			"WORLD_ENTER",
			JSON.stringify(body ?? {}),
			JSON.stringify(state),
			now
		);
		const delta = computeWalletDelta(beforeWallet, state.wallet);
		auditWalletMutation(playerId, delta, "WORLD_ENTER", sessionId, now);
	})();
	if (!state) {
		return { error: "Failed to resolve player state." };
	}
	return {
		state,
		sessionId,
		zoneId,
		modifiers
	};
}

function farmWorldSession(
	playerId: string,
	clientActionId: string,
	body: any
): { state?: PlayerState; sessionId?: string; drops?: ResourceWallet; heat?: number; stamina?: number; error?: string } {
	const sessionId = typeof body?.session_id == "string" ? body.session_id.trim() : "";
	if (!sessionId) {
		return { error: "Missing session_id." };
	}
	const stored = getIdempotentState(playerId, clientActionId, "WORLD_FARM", body);
	if (stored) {
		const world = stored.world;
		const session = world.sessions[sessionId];
		const zoneId = session ? session.zone_id : "";
		const heat = zoneId && world.zone_progress[zoneId] ? world.zone_progress[zoneId].heat : 0;
		return {
			state: stored,
			sessionId,
			drops: {},
			heat,
			stamina: world.stamina
		};
	}
	let state: PlayerState | null = null;
	let drops: ResourceWallet = {};
	let heat = 0;
	let stamina = 0;
	const now = Date.now();
	db.transaction(() => {
		state = ensurePlayerState(playerId);
		const world = ensurePlayerWorld(state, now);
		refreshWorldPlayer(world, now);
		const session = world.sessions[sessionId];
		if (!session) {
			throw new HttpError(400, "Session not found.");
		}
		const zoneId = session.zone_id;
		if (!isValidZoneId(zoneId)) {
			throw new HttpError(400, "Invalid zone.");
		}
		const zoneDef = staticData.zones[zoneId];
		if (!zoneDef) {
			throw new HttpError(400, "Zone data missing.");
		}
		const blocks = clampInt(body?.blocks ?? 1, 1, getWorldMaxBlocksPerAction());
		if (world.stamina < blocks) {
			throw new HttpError(400, "Not enough stamina.");
		}
		const progress = ensureZoneProgress(world, zoneId, now);
		let currentHeat = progress.heat;
		const heatGain = getWorldHeatGain();
		const heatMax = getWorldHeatMax();
		for (let i = 0; i < blocks; i++) {
			const seed = `${WORLD_SECRET}:${playerId}:${clientActionId}:${i}`;
			const blockDrops = computeZoneDrops(zoneDef, currentHeat, seed);
			applyWalletGrant(drops, blockDrops);
			currentHeat = Math.min(heatMax, currentHeat + heatGain);
			progress.reputation = clampInt(progress.reputation + 1, 0, Number.MAX_SAFE_INTEGER);
		}
		progress.heat = currentHeat;
		progress.last_heat_at = now;
		session.last_farm_at = now;
		session.blocks_farmed = clampInt(session.blocks_farmed + blocks, 0, Number.MAX_SAFE_INTEGER);
		applyWalletGrant(session.pending_loot, drops);
		world.stamina = Math.max(0, world.stamina - blocks);
		world.last_stamina_at = now;
		heat = progress.heat;
		stamina = world.stamina;
		state.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(state), now, playerId);
		insertActionStmt.run(
			playerId,
			clientActionId,
			"WORLD_FARM",
			JSON.stringify(body ?? {}),
			JSON.stringify(state),
			now
		);
	})();
	if (!state) {
		return { error: "Failed to resolve player state." };
	}
	return { state, sessionId, drops, heat, stamina };
}

function claimWorldSession(
	playerId: string,
	clientActionId: string,
	body: any
): { state?: PlayerState; sessionId?: string; claimed?: ResourceWallet; error?: string } {
	const sessionId = typeof body?.session_id == "string" ? body.session_id.trim() : "";
	if (!sessionId) {
		return { error: "Missing session_id." };
	}
	const stored = getIdempotentState(playerId, clientActionId, "WORLD_CLAIM", body);
	if (stored) {
		return { state: stored, sessionId, claimed: {} };
	}
	const previewState = ensurePlayerState(playerId);
	const previewWorld = ensurePlayerWorld(previewState, Date.now());
	const previewSession = previewWorld.sessions[sessionId];
	if (!previewSession) {
		return { error: "Session not found." };
	}
	const previewClaimed = normalizeLoot(previewSession.pending_loot);
	for (const amount of Object.values(previewClaimed)) {
		if (isSuspiciousAmount(amount)) {
			logSuspiciousAction(playerId, previewClaimed, "WORLD_CLAIM", sessionId);
			return { error: "Suspicious claim amount." };
		}
	}
	let state: PlayerState | null = null;
	let claimed: ResourceWallet = {};
	const now = Date.now();
	db.transaction(() => {
		state = ensurePlayerState(playerId);
		const beforeWallet = cloneWallet(state.wallet);
		const world = ensurePlayerWorld(state, now);
		refreshWorldPlayer(world, now);
		const session = world.sessions[sessionId];
		if (!session) {
			throw new HttpError(400, "Session not found.");
		}
		claimed = normalizeLoot(session.pending_loot);
		if (Object.keys(claimed).length > 0) {
			applyWalletGrant(state.wallet, claimed);
		}
		session.pending_loot = {};
		assertWalletInvariant(state.wallet);
		state.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(state), now, playerId);
		insertActionStmt.run(
			playerId,
			clientActionId,
			"WORLD_CLAIM",
			JSON.stringify(body ?? {}),
			JSON.stringify(state),
			now
		);
		const delta = computeWalletDelta(beforeWallet, state.wallet);
		auditWalletMutation(playerId, delta, "WORLD_CLAIM", sessionId, now);
	})();
	if (!state) {
		return { error: "Failed to resolve player state." };
	}
	return { state, sessionId, claimed };
}

function attackBoss(
	playerId: string,
	clientActionId: string,
	body: any,
	ip: string
): {
	state?: PlayerState;
	boss?: BossState;
	damage?: number;
	contributorScore?: number;
	tokens?: number;
	error?: string;
} {
	const bossId = typeof body?.boss_id == "string" ? body.boss_id.trim() : "";
	if (!bossId) {
		return { error: "Missing boss_id." };
	}
	if (!isValidBossId(bossId)) {
		return { error: "Unknown boss_id." };
	}
	const now = Date.now();
	const worldState = ensureWorldState(now);
	const bossState = getBossFromWorld(worldState, bossId);
	if (!bossState) {
		return { error: "Boss not available." };
	}
	if (now < bossState.window_starts_at || now > bossState.window_ends_at) {
		return { error: "Boss window closed." };
	}
	const attackFee = getBossAttackFee();
	if (attackFee > 0 && isSuspiciousAmount(attackFee)) {
		logSuspiciousAction(playerId, { essence: -attackFee }, "BOSS_ATTACK", bossId);
		return { error: "Suspicious boss fee." };
	}
	if (!allowBossIp(ip, bossState.window_ends_at)) {
		return { error: "Boss attack rate limit reached." };
	}
	const stored = getIdempotentState(playerId, clientActionId, "BOSS_ATTACK", body);
	if (stored) {
		const existingBoss = getBossFromWorld(ensureWorldState(now), bossId);
		const score = existingBoss?.contributors[playerId] ?? 0;
		return {
			state: stored,
			boss: existingBoss ?? bossState,
			damage: 0,
			contributorScore: score,
			tokens: 0
		};
	}
	let state: PlayerState | null = null;
	let damage = 0;
	let tokens = 0;
	let contributorScore = 0;
	db.transaction(() => {
		state = ensurePlayerState(playerId);
		const beforeWallet = cloneWallet(state.wallet);
		const world = ensurePlayerWorld(state, now);
		refreshWorldPlayer(world, now);
		if (world.boss_tickets <= 0) {
			throw new HttpError(400, "No boss tickets available.");
		}
		if (attackFee > 0) {
			const essence = clampAmount(state.wallet.essence ?? 0);
			if (essence < attackFee) {
				throw new HttpError(400, "Insufficient Essence for boss fee.");
			}
			state.wallet.essence = essence - attackFee;
		}
		const freshWorldState = ensureWorldState(now);
		const bossEntry = getBossFromWorld(freshWorldState, bossId);
		if (!bossEntry) {
			throw new HttpError(400, "Boss not available.");
		}
		if (now < bossEntry.window_starts_at || now > bossEntry.window_ends_at) {
			throw new HttpError(400, "Boss window closed.");
		}
		const power = getPlayerPowerScore(state);
		const variance = clampChance(getBalanceNumber("boss_damage_variance", 0.15));
		const roll = seededRandom01(`${WORLD_SECRET}:boss:${playerId}:${clientActionId}:${bossId}`);
		const mult = 1 - variance + roll * variance * 2;
		damage = Math.max(1, Math.floor(power * mult));
		const cap = clampInt(getBalanceNumber("boss_damage_cap", 100000), 1, 1000000000);
		damage = Math.min(damage, cap);
		damage = Math.min(damage, bossEntry.hp);
		bossEntry.hp = Math.max(0, bossEntry.hp - damage);
		bossEntry.phase = computeBossPhase(bossEntry.hp, bossEntry.max_hp);
		const existing = clampInt(bossEntry.contributors[playerId] ?? 0, 0, Number.MAX_SAFE_INTEGER);
		contributorScore = existing + damage;
		bossEntry.contributors[playerId] = contributorScore;
		world.boss_tickets = Math.max(0, world.boss_tickets - 1);
		world.last_boss_ticket_at = now;
		tokens = computeBossTokens(damage);
		if (tokens > 0) {
			world.boss_tokens = clampInt(world.boss_tokens + tokens, 0, Number.MAX_SAFE_INTEGER);
		}
		assertWalletInvariant(state.wallet);
		state.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(state), now, playerId);
		updateWorldStmt.run(JSON.stringify(freshWorldState), now);
		insertActionStmt.run(
			playerId,
			clientActionId,
			"BOSS_ATTACK",
			JSON.stringify(body ?? {}),
			JSON.stringify(state),
			now
		);
		const delta = computeWalletDelta(beforeWallet, state.wallet);
		auditWalletMutation(playerId, delta, "BOSS_ATTACK", bossId, now);
	})();
	if (!state) {
		return { error: "Failed to resolve player state." };
	}
	const latestWorld = ensureWorldState(now);
	const latestBoss = getBossFromWorld(latestWorld, bossId) ?? bossState;
	return { state, boss: latestBoss, damage, contributorScore, tokens };
}

function claimBossRewards(
	playerId: string,
	clientActionId: string,
	body: any
): { state?: PlayerState; claimed?: ResourceWallet; tier?: string; error?: string } {
	const bossId = typeof body?.boss_id == "string" ? body.boss_id.trim() : "";
	if (!bossId) {
		return { error: "Missing boss_id." };
	}
	if (!isValidBossId(bossId)) {
		return { error: "Unknown boss_id." };
	}
	const now = Date.now();
	const worldState = ensureWorldState(now);
	const bossState = getBossFromWorld(worldState, bossId);
	if (!bossState) {
		return { error: "Boss not available." };
	}
	if (now <= bossState.window_ends_at) {
		return { error: "Boss window still active." };
	}
	const stored = getIdempotentState(playerId, clientActionId, "BOSS_CLAIM", body);
	if (stored) {
		return { state: stored, claimed: {} };
	}
	const previewScore = clampInt(bossState.contributors[playerId] ?? 0, 0, Number.MAX_SAFE_INTEGER);
	if (previewScore <= 0) {
		return { error: "No contribution recorded." };
	}
	const previewRewards = computeBossRewards(bossState, playerId);
	for (const amount of Object.values(previewRewards.grants)) {
		if (isSuspiciousAmount(amount)) {
			logSuspiciousAction(playerId, previewRewards.grants, "BOSS_CLAIM", bossId);
			return { error: "Suspicious boss reward amount." };
		}
	}
	let state: PlayerState | null = null;
	let claimed: ResourceWallet = {};
	let tier = previewRewards.rewardTier;
	db.transaction(() => {
		state = ensurePlayerState(playerId);
		const beforeWallet = cloneWallet(state.wallet);
		const world = ensurePlayerWorld(state, now);
		refreshWorldPlayer(world, now);
		const lastClaim = clampInt(world.boss_claims[bossId] ?? 0, 0, Number.MAX_SAFE_INTEGER);
		if (lastClaim >= bossState.window_ends_at) {
			throw new HttpError(400, "Rewards already claimed.");
		}
		claimed = previewRewards.grants;
		if (Object.keys(claimed).length > 0) {
			applyWalletGrant(state.wallet, claimed);
		}
		world.boss_claims[bossId] = bossState.window_ends_at;
		assertWalletInvariant(state.wallet);
		state.updated_at = now;
		updatePlayerStmt.run(JSON.stringify(state), now, playerId);
		insertActionStmt.run(
			playerId,
			clientActionId,
			"BOSS_CLAIM",
			JSON.stringify(body ?? {}),
			JSON.stringify(state),
			now
		);
		const delta = computeWalletDelta(beforeWallet, state.wallet);
		auditWalletMutation(playerId, delta, "BOSS_CLAIM", bossId, now);
	})();
	if (!state) {
		return { error: "Failed to resolve player state." };
	}
	return { state, claimed, tier };
}

function getEscrowAmount(playerId: string, resourceId: string): number {
	const row = getEscrowStmt.get(playerId, resourceId) as { amount: number } | undefined;
	if (!row) {
		return 0;
	}
	return clampAmount(row.amount);
}

function addEscrow(playerId: string, resourceId: string, amount: number): void {
	const delta = clampAmount(amount);
	if (delta <= 0) {
		return;
	}
	addEscrowStmt.run(playerId, resourceId, delta);
}

function subtractEscrow(playerId: string, resourceId: string, amount: number): boolean {
	const delta = clampAmount(amount);
	if (delta <= 0) {
		return true;
	}
	const current = getEscrowAmount(playerId, resourceId);
	if (current < delta) {
		return false;
	}
	setEscrowStmt.run(playerId, resourceId, current - delta);
	return true;
}

function getOrderRemaining(orderId: string, totalAmount: number): number {
	const filledRow = getOrderFillsSumStmt.get(orderId) as { filled: number } | undefined;
	const filled = filledRow ? clampAmount(filledRow.filled) : 0;
	return Math.max(0, totalAmount - filled);
}

function isValidResourceId(resourceId: string): boolean {
	if (staticData.resources.size == 0) {
		return true;
	}
	return staticData.resources.has(resourceId);
}

function isValidZoneId(zoneId: string): boolean {
	if (Object.keys(staticData.zones).length == 0) {
		return true;
	}
	return !!staticData.zones[zoneId];
}

function isValidBossId(bossId: string): boolean {
	if (Object.keys(staticData.bosses).length == 0) {
		return true;
	}
	return !!staticData.bosses[bossId];
}

function runBackendTests(): void {
	console.log("Running backend action tests...");
	const idStore = new Set<string>();
	const playerId = "test_player";
	const state = createDefaultState(playerId, "Tester", Date.now());
	state.wallet.essence = 1000;
	state.wallet.core = 20;
	const actionId = "action-1";
	const first = applyWithIdempotency(
		state,
		actionId,
		"UPGRADE_BUILDING",
		{ building_id: "essence_reactor" },
		idStore
	);
	const second = applyWithIdempotency(
		state,
		actionId,
		"UPGRADE_BUILDING",
		{ building_id: "essence_reactor" },
		idStore
	);
	if (first.applied && !second.applied) {
		console.log("PASS: idempotency prevents double apply");
	} else {
		console.error("FAIL: idempotency test");
	}
	const invalid = applyAction(state, "SET_BUILDING_ROUTE", {
		building_id: "essence_reactor",
		route: "invalid_route"
	});
	if (invalid.error) {
		console.log("PASS: invalid route rejected");
	} else {
		console.error("FAIL: invalid route test");
	}

	const expState = createDefaultState("exp_player", "Tester", Date.now());
	expState.lab.hqLevel = 3;
	const hq = ensureBuildingState(expState, "lab_th");
	hq.level = 3;
	hq.route = "Scientific";
	const chamber = ensureBuildingState(expState, "experiment_chamber");
	chamber.level = 1;
	expState.wallet.essence = 500;
	expState.wallet.core = 10;
	const expActionId = "exp-action-1";
	const beforeEssence = expState.wallet.essence;
	const expFirst = applyWithIdempotency(
		expState,
		expActionId,
		"START_EXPERIMENT",
		{ experiment_id: "refine_core" },
		idStore
	);
	const afterEssence = expFirst.state?.wallet.essence ?? expState.wallet.essence;
	const expSecond = applyWithIdempotency(
		expState,
		expActionId,
		"START_EXPERIMENT",
		{ experiment_id: "refine_core" },
		idStore
	);
	if (expFirst.applied && !expSecond.applied && afterEssence < beforeEssence) {
		console.log("PASS: experiment idempotency prevents double spend");
	} else {
		if (expFirst.error) {
			console.error("FAIL: experiment idempotency test - first error:", expFirst.error);
		} else if (expSecond.error) {
			console.error("FAIL: experiment idempotency test - second error:", expSecond.error);
		} else {
			console.error(
				"FAIL: experiment idempotency test",
				{ firstApplied: expFirst.applied, secondApplied: expSecond.applied, beforeEssence, afterEssence }
			);
		}
	}

	const boostState = createDefaultState("boost_player", "Tester", Date.now());
	boostState.lab.hqLevel = 3;
	const boostHq = ensureBuildingState(boostState, "lab_th");
	boostHq.level = 3;
	boostHq.route = "Scientific";
	const boostChamber = ensureBuildingState(boostState, "experiment_chamber");
	boostChamber.level = 1;
	boostState.wallet.essence = 500;
	boostState.wallet.arcane_shard = 5;
	const boostResult = applyAction(
		boostState,
		"START_EXPERIMENT",
		{ experiment_id: "volatile_overclock" },
		"exp-boost-1"
	);
	if (boostResult.error) {
		console.error("FAIL: boost experiment failed to start");
	} else {
		const runtime = ensureLabRuntime(boostState);
		const expiresAt = runtime.boosts["volatile_overclock"]?.expires_at ?? 0;
		cleanupLabRuntime(runtime, expiresAt + 1);
		if (!runtime.boosts["volatile_overclock"]) {
			console.log("PASS: boost expires after duration");
		} else {
			console.error("FAIL: boost expiry test");
		}
	}

	const researchState = createDefaultState("research_player", "Tester", Date.now());
	researchState.lab.hqLevel = 3;
	const researchHq = ensureBuildingState(researchState, "lab_th");
	researchHq.level = 3;
	researchHq.route = "Scientific";
	const archives = ensureBuildingState(researchState, "arcane_archives");
	archives.level = 1;
	researchState.wallet.essence = 500;
	const startResearch = applyStartResearch(
		researchState,
		{ research_id: "archive_basics" },
		1000
	);
	if (startResearch.error) {
		console.error("FAIL: research start failed");
	} else {
		const claimResearch = applyClaimResearch(
			researchState,
			{ research_id: "archive_basics" },
			1000 + 60 * 1000 + 1
		);
		if (!claimResearch.error && researchState.research_flags["archive_basics"]) {
			console.log("PASS: research completion unlocks flag");
		} else {
			console.error("FAIL: research completion test");
		}
	}

	// Market module tests (DB-backed)
	const marketSellerId = `market_seller_${crypto.randomUUID()}`;
	const marketBuyerId = `market_buyer_${crypto.randomUUID()}`;
	const marketNow = Date.now();
	const sellerState = createDefaultState(marketSellerId, "Market Seller", marketNow);
	const buyerState = createDefaultState(marketBuyerId, "Market Buyer", marketNow);
	sellerState.wallet.core = 50;
	buyerState.wallet.essence = 1000;
	try {
		insertPlayerStmt.run(marketSellerId, sellerState.display_name ?? "Market Seller", JSON.stringify(sellerState), marketNow);
	} catch {
		updatePlayerStmt.run(JSON.stringify(sellerState), marketNow, marketSellerId);
	}
	try {
		insertPlayerStmt.run(marketBuyerId, buyerState.display_name ?? "Market Buyer", JSON.stringify(buyerState), marketNow);
	} catch {
		updatePlayerStmt.run(JSON.stringify(buyerState), marketNow, marketBuyerId);
	}
	const feeBps = getMarketFeeBps();
	const orderActionId = "market-order-1";
	const orderId = makeOrderId(marketSellerId, orderActionId);
	const orderAmount = 20;
	const priceAmount = 5;
	db.transaction(() => {
		sellerState.wallet.core = clampAmount(sellerState.wallet.core ?? 0) - orderAmount;
		addEscrow(marketSellerId, "core", orderAmount);
		insertOrderStmt.run(
			orderId,
			marketSellerId,
			MARKET_TYPE_SELL,
			"core",
			orderAmount,
			"essence",
			priceAmount,
			feeBps,
			MARKET_STATUS_OPEN,
			marketNow
		);
		sellerState.updated_at = marketNow;
		updatePlayerStmt.run(JSON.stringify(sellerState), marketNow, marketSellerId);
		insertActionStmt.run(
			marketSellerId,
			orderActionId,
			"MARKET_ORDER",
			JSON.stringify({ resource_id: "core", amount: orderAmount, price_amount: priceAmount }),
			JSON.stringify(sellerState),
			marketNow
		);
	})();
	const escrowAfterOrder = getEscrowAmount(marketSellerId, "core");
	if (escrowAfterOrder == orderAmount) {
		console.log("PASS: market order locks escrow");
	} else {
		console.error("FAIL: market order escrow mismatch");
	}
	const storedOrderState = getIdempotentState(marketSellerId, orderActionId);
	if (storedOrderState) {
		console.log("PASS: market order idempotency detected");
	} else {
		console.error("FAIL: market order idempotency missing");
	}
	const cancelActionId = "market-cancel-1";
	const remaining = getOrderRemaining(orderId, orderAmount);
	db.transaction(() => {
		updateOrderStatusStmt.run(MARKET_STATUS_CANCELED, orderId);
		if (remaining > 0) {
			subtractEscrow(marketSellerId, "core", remaining);
			sellerState.wallet.core = clampAmount(sellerState.wallet.core ?? 0) + remaining;
		}
		sellerState.updated_at = Date.now();
		updatePlayerStmt.run(JSON.stringify(sellerState), sellerState.updated_at, marketSellerId);
		insertActionStmt.run(
			marketSellerId,
			cancelActionId,
			"MARKET_CANCEL",
			JSON.stringify({ order_id: orderId }),
			JSON.stringify(sellerState),
			sellerState.updated_at
		);
	})();
	const escrowAfterCancel = getEscrowAmount(marketSellerId, "core");
	if (escrowAfterCancel == 0) {
		console.log("PASS: market cancel releases escrow");
	} else {
		console.error("FAIL: market cancel escrow not released");
	}

	const order2ActionId = "market-order-2";
	const order2Id = makeOrderId(marketSellerId, order2ActionId);
	const order2Amount = 30;
	db.transaction(() => {
		sellerState.wallet.core = clampAmount(sellerState.wallet.core ?? 0) - order2Amount;
		addEscrow(marketSellerId, "core", order2Amount);
		insertOrderStmt.run(
			order2Id,
			marketSellerId,
			MARKET_TYPE_SELL,
			"core",
			order2Amount,
			"essence",
			priceAmount,
			feeBps,
			MARKET_STATUS_OPEN,
			Date.now()
		);
		sellerState.updated_at = Date.now();
		updatePlayerStmt.run(JSON.stringify(sellerState), sellerState.updated_at, marketSellerId);
		insertActionStmt.run(
			marketSellerId,
			order2ActionId,
			"MARKET_ORDER",
			JSON.stringify({ resource_id: "core", amount: order2Amount, price_amount: priceAmount }),
			JSON.stringify(sellerState),
			sellerState.updated_at
		);
	})();
	const buyActionId = "market-buy-1";
	const buyAmount = 10;
	const totalPrice = buyAmount * priceAmount;
	const fee = Math.floor((totalPrice * feeBps) / 10_000);
	const buyerEssenceBefore = clampAmount(buyerState.wallet.essence ?? 0);
	const buyerCoreBefore = clampAmount(buyerState.wallet.core ?? 0);
	const sellerEssenceBefore = clampAmount(sellerState.wallet.essence ?? 0);
	const escrowBeforeBuy = getEscrowAmount(marketSellerId, "core");
	db.transaction(() => {
		buyerState.wallet.essence = clampAmount(buyerState.wallet.essence ?? 0) - totalPrice;
		applyWalletGrant(buyerState.wallet, { core: buyAmount });
		sellerState.wallet.essence = clampAmount(sellerState.wallet.essence ?? 0) + Math.max(0, totalPrice - fee);
		subtractEscrow(marketSellerId, "core", buyAmount);
		insertFillStmt.run(crypto.randomUUID(), order2Id, marketBuyerId, buyAmount, totalPrice, fee, Date.now());
		buyerState.updated_at = Date.now();
		sellerState.updated_at = buyerState.updated_at;
		updatePlayerStmt.run(JSON.stringify(buyerState), buyerState.updated_at, marketBuyerId);
		updatePlayerStmt.run(JSON.stringify(sellerState), sellerState.updated_at, marketSellerId);
		insertActionStmt.run(
			marketBuyerId,
			buyActionId,
			"MARKET_BUY",
			JSON.stringify({ order_id: order2Id, amount: buyAmount }),
			JSON.stringify(buyerState),
			buyerState.updated_at
		);
	})();
	const remainingAfterBuy = getOrderRemaining(order2Id, order2Amount);
	if (remainingAfterBuy == order2Amount - buyAmount) {
		console.log("PASS: market partial fill reduces remaining");
	} else {
		console.error("FAIL: market remaining mismatch after buy");
	}
	const escrowAfterBuy = getEscrowAmount(marketSellerId, "core");
	if (
		buyerState.wallet.essence == buyerEssenceBefore - totalPrice &&
		buyerState.wallet.core == buyerCoreBefore + buyAmount
	) {
		console.log("PASS: market buy transfers buyer resources");
	} else {
		console.error("FAIL: market buyer wallet mismatch");
	}
	if (sellerState.wallet.essence == sellerEssenceBefore + Math.max(0, totalPrice - fee)) {
		console.log("PASS: market buy transfers seller resources");
	} else {
		console.error("FAIL: market seller wallet mismatch");
	}
	if (escrowAfterBuy == escrowBeforeBuy - buyAmount) {
		console.log("PASS: market buy releases escrow");
	} else {
		console.error("FAIL: market escrow mismatch after buy");
	}
	const storedBuyState = getIdempotentState(marketBuyerId, buyActionId);
	if (storedBuyState) {
		console.log("PASS: market buy idempotency detected");
	} else {
		console.error("FAIL: market buy idempotency missing");
	}
	const invariantBuyer = getWalletInvariantError(buyerState.wallet);
	const invariantSeller = getWalletInvariantError(sellerState.wallet);
	if (!invariantBuyer && !invariantSeller) {
		console.log("PASS: wallet invariants hold after market buy");
	} else {
		console.error("FAIL: wallet invariants violated after market buy");
	}
	const auditBefore = (countAuditStmt.get(marketBuyerId) as { count: number } | undefined)?.count ?? 0;
	try {
		rejectSuspiciousMarketBuy(
			marketBuyerId,
			"order_suspicious",
			"core",
			"essence",
			getSuspiciousAmountThreshold() + 1,
			1
		);
		console.error("FAIL: huge buy was not rejected");
	} catch {
		const auditAfter = (countAuditStmt.get(marketBuyerId) as { count: number } | undefined)?.count ?? 0;
		if (auditAfter > auditBefore) {
			console.log("PASS: huge buy rejected and logged");
		} else {
			console.error("FAIL: huge buy not logged");
		}
	}

	// Trade jobs tests
	const tradeProviderId = `trade_provider_${crypto.randomUUID()}`;
	const tradeCustomerId = `trade_customer_${crypto.randomUUID()}`;
	const tradeNow = Date.now();
	const tradeProviderState = createDefaultState(tradeProviderId, "Trade Provider", tradeNow);
	const tradeCustomerState = createDefaultState(tradeCustomerId, "Trade Customer", tradeNow);
	tradeCustomerState.wallet.core = 50;
	tradeCustomerState.wallet.essence = 200;
	try {
		insertPlayerStmt.run(
			tradeProviderId,
			tradeProviderState.display_name ?? "Trade Provider",
			JSON.stringify(tradeProviderState),
			tradeNow
		);
	} catch {
		updatePlayerStmt.run(JSON.stringify(tradeProviderState), tradeNow, tradeProviderId);
	}
	try {
		insertPlayerStmt.run(
			tradeCustomerId,
			tradeCustomerState.display_name ?? "Trade Customer",
			JSON.stringify(tradeCustomerState),
			tradeNow
		);
	} catch {
		updatePlayerStmt.run(JSON.stringify(tradeCustomerState), tradeNow, tradeCustomerId);
	}

	const tradeJobActionId = "trade-job-1";
	const tradeJobBody = {
		input_resource_id: "core",
		input_amount: 10,
		output_resource_id: "arcane_shard",
		output_min: 1,
		output_max: 3,
		duration_sec: 0,
		commission_resource_id: "essence",
		commission_amount: 20,
		queue_limit: 2
	};
	const tradeJobResult = createTradeJob(tradeProviderId, tradeJobActionId, tradeJobBody);
	if (!tradeJobResult.jobId || !tradeJobResult.state) {
		console.error("FAIL: trade job creation failed");
	} else {
		console.log("PASS: trade job created");
	}
	const tradeJobId = tradeJobResult.jobId ?? makeTradeJobId(tradeProviderId, tradeJobActionId);
	const tradeSubmitActionId = "trade-submit-1";
	const tradeSubmitResult = submitTradeRun(tradeCustomerId, tradeSubmitActionId, {
		job_id: tradeJobId
	});
	if (!tradeSubmitResult.runId || !tradeSubmitResult.state) {
		console.error("FAIL: trade submit failed");
	} else {
		const escrowCore = getEscrowAmount(tradeCustomerId, "core");
		const escrowEssence = getEscrowAmount(tradeCustomerId, "essence");
		if (escrowCore == 10 && escrowEssence == 20) {
			console.log("PASS: trade submit locks escrow");
		} else {
			console.error("FAIL: trade escrow lock mismatch");
		}
	}
	const tradeRunId = tradeSubmitResult.runId ?? makeTradeRunId(tradeCustomerId, tradeSubmitActionId, tradeJobId);
	const customerBeforeClaim = ensurePlayerState(tradeCustomerId);
	const providerBeforeClaim = ensurePlayerState(tradeProviderId);
	const tradeClaimActionId = "trade-claim-1";
	const tradeClaimResult = claimTradeRun(tradeCustomerId, tradeClaimActionId, {
		run_id: tradeRunId
	});
	if (!tradeClaimResult.state) {
		console.error("FAIL: trade claim failed");
	} else {
		const customerAfterClaim = tradeClaimResult.state;
		const providerAfterClaim = ensurePlayerState(tradeProviderId);
		const outputAmount = tradeClaimResult.outputAmount ?? 0;
		const escrowCoreAfter = getEscrowAmount(tradeCustomerId, "core");
		const escrowEssenceAfter = getEscrowAmount(tradeCustomerId, "essence");
		if (escrowCoreAfter == 0 && escrowEssenceAfter == 0) {
			console.log("PASS: trade claim releases escrow");
		} else {
			console.error("FAIL: trade claim escrow not released");
		}
		if ((customerAfterClaim.wallet.arcane_shard ?? 0) >= (customerBeforeClaim.wallet.arcane_shard ?? 0) + outputAmount) {
			console.log("PASS: trade claim awards output");
		} else {
			console.error("FAIL: trade claim output mismatch");
		}
		if ((providerAfterClaim.wallet.essence ?? 0) >= (providerBeforeClaim.wallet.essence ?? 0) + 20) {
			console.log("PASS: trade claim pays commission");
		} else {
			console.error("FAIL: trade commission not paid");
		}
	}
	const tradeClaimRepeat = claimTradeRun(tradeCustomerId, tradeClaimActionId, {
		run_id: tradeRunId
	});
	if (tradeClaimRepeat.state) {
		console.log("PASS: trade claim idempotency detected");
	} else {
		console.error("FAIL: trade claim idempotency missing");
	}

	// World module tests
	const worldPlayerId = `world_player_${crypto.randomUUID()}`;
	const worldNow = Date.now();
	const worldPlayerState = createDefaultState(worldPlayerId, "World Tester", worldNow);
	worldPlayerState.research_flags["unlock_world_zones"] = true;
	worldPlayerState.wallet.essence = 100;
	try {
		insertPlayerStmt.run(
			worldPlayerId,
			worldPlayerState.display_name ?? "World Tester",
			JSON.stringify(worldPlayerState),
			worldNow
		);
	} catch {
		updatePlayerStmt.run(JSON.stringify(worldPlayerState), worldNow, worldPlayerId);
	}
	const zoneIds = Object.keys(staticData.zones);
	const testZoneId = zoneIds.length > 0 ? zoneIds[0] : "zone_corrupted";
	const enterActionId = "world-enter-1";
	const enterResult = enterWorldSession(worldPlayerId, enterActionId, { zone_id: testZoneId });
	if (!enterResult.state || !enterResult.sessionId) {
		console.error("FAIL: world enter failed");
	} else {
		console.log("PASS: world enter created session");
	}
	const sessionId = enterResult.sessionId ?? makeWorldSessionId(worldPlayerId, enterActionId, testZoneId);
	const farmActionId = "world-farm-1";
	const farmResult = farmWorldSession(worldPlayerId, farmActionId, { session_id: sessionId });
	if (!farmResult.state) {
		console.error("FAIL: world farm failed");
	} else {
		const progress = farmResult.state.world.zone_progress[testZoneId];
		if (progress && progress.heat > 0) {
			console.log("PASS: world heat increases on farm");
		} else {
			console.error("FAIL: world heat did not increase");
		}
		const pending = farmResult.state.world.sessions[sessionId]?.pending_loot ?? {};
		const pendingTotal = Object.values(pending).reduce((sum, value) => sum + clampAmount(value), 0);
		if (pendingTotal > 0) {
			console.log("PASS: world farm produced loot");
		} else {
			console.error("FAIL: world farm loot missing");
		}
	}
	const farmRepeat = farmWorldSession(worldPlayerId, farmActionId, { session_id: sessionId });
	if (farmRepeat.state) {
		console.log("PASS: world farm idempotency detected");
	} else {
		console.error("FAIL: world farm idempotency missing");
	}
	const beforeClaimState = ensurePlayerState(worldPlayerId);
	const claimActionId = "world-claim-1";
	const claimResult = claimWorldSession(worldPlayerId, claimActionId, { session_id: sessionId });
	if (!claimResult.state) {
		console.error("FAIL: world claim failed");
	} else {
		const afterClaimState = claimResult.state;
		const beforeEssence = clampAmount(beforeClaimState.wallet.essence ?? 0);
		const afterEssence = clampAmount(afterClaimState.wallet.essence ?? 0);
		if (afterEssence >= beforeEssence) {
			console.log("PASS: world claim increased wallet");
		} else {
			console.error("FAIL: world claim did not increase wallet");
		}
	}
	const claimRepeat = claimWorldSession(worldPlayerId, claimActionId, { session_id: sessionId });
	if (claimRepeat.state) {
		console.log("PASS: world claim idempotency detected");
	} else {
		console.error("FAIL: world claim idempotency missing");
	}

	// Boss module tests
	const bossPlayerId = `boss_player_${crypto.randomUUID()}`;
	const bossNow = Date.now();
	const bossPlayerState = createDefaultState(bossPlayerId, "Boss Tester", bossNow);
	bossPlayerState.research_flags["archive_basics"] = true;
	bossPlayerState.wallet.essence = 100;
	bossPlayerState.wallet.essence = 100;
	try {
		insertPlayerStmt.run(
			bossPlayerId,
			bossPlayerState.display_name ?? "Boss Tester",
			JSON.stringify(bossPlayerState),
			bossNow
		);
	} catch {
		updatePlayerStmt.run(JSON.stringify(bossPlayerState), bossNow, bossPlayerId);
	}
	const bossIds = Object.keys(staticData.bosses);
	const testBossId = bossIds.length > 0 ? bossIds[0] : "boss_common";
	const originalWindow = staticData.balance.boss_window_minutes;
	const originalInterval = staticData.balance.boss_interval_minutes;

	// Prefer open window for ticket/idempotency tests.
	staticData.balance.boss_window_minutes = 120;
	staticData.balance.boss_interval_minutes = 120;
	const attackActionId = "boss-attack-1";
	const beforeAttack = ensurePlayerState(bossPlayerId);
	const beforeTickets = beforeAttack.world.boss_tickets;
	const attackResult = attackBoss(bossPlayerId, attackActionId, { boss_id: testBossId }, "127.0.0.1");
	if (attackResult.error || !attackResult.state) {
		console.error("FAIL: boss attack failed", attackResult.error);
	} else {
		const afterAttack = ensurePlayerState(bossPlayerId);
		if (afterAttack.world.boss_tickets == beforeTickets - 1) {
			console.log("PASS: boss attack consumes ticket");
		} else {
			console.error("FAIL: boss ticket not consumed");
		}
		const attackRepeat = attackBoss(bossPlayerId, attackActionId, { boss_id: testBossId }, "127.0.0.1");
		const worldState = ensureWorldState(Date.now());
		const bossState = getBossFromWorld(worldState, testBossId);
		if (attackRepeat.state && bossState && bossState.contributors[bossPlayerId] == attackResult.contributorScore) {
			console.log("PASS: boss attack idempotency detected");
		} else {
			console.error("FAIL: boss attack idempotency missing");
		}
	}

	// Prefer closed window for rejection test.
	staticData.balance.boss_window_minutes = 1;
	staticData.balance.boss_interval_minutes = 120;
	const window = getBossWindowTimes(testBossId, Date.now());
	if (Date.now() > window.end) {
		const closedAttack = attackBoss(bossPlayerId, "boss-attack-closed", { boss_id: testBossId }, "127.0.0.1");
		if (closedAttack.error) {
			console.log("PASS: boss attack rejected outside window");
		} else {
			console.error("FAIL: boss attack should be rejected outside window");
		}
	} else {
		console.log("SKIP: boss outside-window test (window currently open)");
	}

	staticData.balance.boss_window_minutes = originalWindow;
	staticData.balance.boss_interval_minutes = originalInterval;
}

function applyWithIdempotency(
	state: PlayerState,
	clientActionId: string,
	actionType: string,
	payload: any,
	store: Set<string>
): { applied: boolean; error?: string; state?: PlayerState } {
	const key = `${state.player_id}:${clientActionId}`;
	if (store.has(key)) {
		return { applied: false };
	}
	const result = applyAction(state, actionType, payload, clientActionId);
	if (result.error) {
		return { applied: false, error: result.error };
	}
	store.add(key);
	return { applied: true, state: result.state };
}

if (Bun.env.RUN_BACKEND_TESTS == "1") {
	runBackendTests();
	process.exit(0);
} else {
	void startServer();
}





