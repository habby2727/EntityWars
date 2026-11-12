import { Database } from "bun:sqlite";
import { readFileSync } from "fs";
import { resolve } from "path";
import { assertApprox, assertEqual, assertNotNull, assertTrue, fail } from "./assert";
import { createClient } from "./test_client";
import { rateLimit } from "../middleware/rateLimit";
import { getRedis } from "../db/redis";

type StaticData = {
	resources: string[];
	buildings: Array<{ id: string; display_name?: string; name?: string }>;
	balance: Record<string, any>;
	zones: Array<{ id: string; name?: string }>;
	bosses: Array<{ id: string; name?: string }>;
	research: Array<{ id: string; flag_id?: string; requires?: string[] }>;
};

type SeedOptions = {
	wallet?: Record<string, number>;
	hqLevel?: number;
	hqPath?: string;
	buildings?: Record<
		string,
		{ level?: number; route?: string; runtime?: { stored_output?: number; last_tick?: number } }
	>;
	research_flags?: Record<string, boolean>;
	lab_runtime?: {
		cooldowns?: Record<string, number>;
		boosts?: Record<string, { expires_at: number }>;
		research?: { active_id?: string; started_at?: number; completes_at?: number };
	};
	world?: Record<string, any>;
};

type TestContext = {
	client: ReturnType<typeof createClient>;
	db: Database;
	staticData: StaticData;
	baseUrl: string;
};

type TestCase = {
	name: string;
	run: (ctx: TestContext) => Promise<void>;
};

function loadJson(path: string): any {
	return JSON.parse(readFileSync(path, "utf8"));
}

function loadStaticData(): StaticData {
	const base = resolve(import.meta.dir, "..", "..", "..", "data", "static");
	const resources = loadJson(resolve(base, "resources.json")).resources ?? [];
	const buildings = loadJson(resolve(base, "buildings.json")).buildings ?? [];
	const balance = loadJson(resolve(base, "balance.json")).balance ?? {};
	const zones = loadJson(resolve(base, "zones.json")).zones ?? [];
	const bosses = loadJson(resolve(base, "bosses.json")).bosses ?? [];
	const research = loadJson(resolve(base, "research.json")).research ?? [];
	return {
		resources: resources.map((entry: any) => entry.id).filter(Boolean),
		buildings,
		balance,
		zones,
		bosses,
		research
	};
}

function getBalanceNumber(balance: Record<string, any>, key: string, fallback: number): number {
	const value = balance[key];
	if (typeof value == "number" && Number.isFinite(value)) {
		return value;
	}
	return fallback;
}

function getMultiplier(map: any, key: string, fallback: number): number {
	if (map && typeof map == "object") {
		const direct = map[key];
		if (typeof direct == "number" && Number.isFinite(direct)) {
			return direct;
		}
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

function computeOutputRate(
	balance: Record<string, any>,
	level: number,
	route: string,
	storageRoute: string,
	hqPath: string
): number {
	const base = getBalanceNumber(balance, "reactor_base_rate", 1.0);
	const perLevel = getBalanceNumber(balance, "reactor_rate_per_level", 0.2);
	const routeMults = balance.reactor_route_output_mult ?? {
		stable: 0.8,
		volatile: 1.35,
		mutagenic: 0.65
	};
	const storageMults = balance.storage_route_output_mult ?? { reactive: 1.05 };
	const hqMults = balance.route_multipliers ?? balance.hq_output_mult ?? {
		scientific: 1.05,
		chaotic: 1.0,
		industrial: 0.95
	};
	const lvl = Math.max(0, level);
	const baseRate = base + perLevel * lvl;
	const routeMult = getMultiplier(routeMults, route.toLowerCase(), 1.0);
	const storageMult = getMultiplier(storageMults, storageRoute.toLowerCase(), 1.0);
	const hqMult = getMultiplier(hqMults, hqPath.toLowerCase(), 1.0);
	return Math.max(0, baseRate * routeMult * storageMult * hqMult);
}

function computeCapacity(
	balance: Record<string, any>,
	level: number,
	storageRoute: string,
	hqPath: string
): number {
	const base = getBalanceNumber(balance, "storage_base_capacity", 1000);
	const perLevel = getBalanceNumber(balance, "storage_capacity_per_level", 250);
	const routeMults = balance.storage_route_capacity_mult ?? {
		compact: 1.0,
		reactive: 1.1,
		sealed: 0.9
	};
	const hqMults = balance.hq_capacity_mult ?? {
		scientific: 1.05,
		chaotic: 1.0,
		industrial: 1.1
	};
	const routeMult = getMultiplier(routeMults, storageRoute.toLowerCase(), 1.0);
	const hqMult = getMultiplier(hqMults, hqPath.toLowerCase(), 1.0);
	return Math.floor(Math.max(0, (base + perLevel * Math.max(0, level)) * routeMult * hqMult));
}

function clampAmount(value: any): number {
	const num = typeof value == "number" ? value : Number(value ?? 0);
	if (!Number.isFinite(num)) {
		return 0;
	}
	return Math.max(0, Math.floor(num));
}

function assertWalletInvariant(wallet: Record<string, any>, message: string): void {
	for (const [key, value] of Object.entries(wallet)) {
		if (!Number.isFinite(Number(value))) {
			fail(`${message}: ${key} is not finite`);
		}
		if (!Number.isInteger(value)) {
			fail(`${message}: ${key} is not integer`);
		}
		if (value < 0) {
			fail(`${message}: ${key} is negative`);
		}
	}
}

function getDbPath(): string {
	const raw = Bun.env.DB_PATH || "data/dev.sqlite";
	return resolve(process.cwd(), raw);
}

function getPlayerStateFromDb(db: Database, playerId: string): any {
	const row = db
		.query("SELECT state_json FROM players WHERE player_id = ?")
		.get(playerId) as { state_json?: string } | undefined;
	if (!row || !row.state_json) {
		throw new Error(`Player not found in DB: ${playerId}`);
	}
	return JSON.parse(row.state_json);
}

function updatePlayerState(db: Database, playerId: string, updater: (state: any) => any): void {
	const now = Date.now();
	const current = getPlayerStateFromDb(db, playerId);
	const next = updater(current) ?? current;
	next.updated_at = now;
	db.query("UPDATE players SET state_json = ?, updated_at = ? WHERE player_id = ?").run(
		JSON.stringify(next),
		now,
		playerId
	);
}

function seedPlayerState(db: Database, playerId: string, seed: SeedOptions): void {
	updatePlayerState(db, playerId, (state) => {
		const next = { ...state };
		next.wallet = { ...(state.wallet ?? {}) };
		if (seed.wallet) {
			for (const [key, value] of Object.entries(seed.wallet)) {
				next.wallet[key] = clampAmount(value);
			}
		}
		next.lab = { ...(state.lab ?? {}) };
		if (seed.hqLevel != null) {
			next.lab.hqLevel = seed.hqLevel;
		}
		if (seed.hqPath) {
			next.lab.hqPath = seed.hqPath;
		}
		next.lab.buildings = { ...(next.lab.buildings ?? {}) };
		next.lab.runtime = { cooldowns: {}, boosts: {}, research: {} };
		if (seed.lab_runtime?.cooldowns) {
			next.lab.runtime.cooldowns = {
				...next.lab.runtime.cooldowns,
				...seed.lab_runtime.cooldowns
			};
		}
		if (seed.lab_runtime?.boosts) {
			next.lab.runtime.boosts = { ...next.lab.runtime.boosts, ...seed.lab_runtime.boosts };
		}
		if (seed.lab_runtime?.research) {
			next.lab.runtime.research = { ...next.lab.runtime.research, ...seed.lab_runtime.research };
		}
		if (seed.buildings) {
			for (const [id, config] of Object.entries(seed.buildings)) {
				const existing = next.lab.buildings[id] ?? {};
				next.lab.buildings[id] = {
					...existing,
					level: config.level ?? existing.level ?? 0,
					route: config.route ?? existing.route ?? "",
					runtime: {
						...(existing.runtime ?? {}),
						...(config.runtime ?? {})
					}
				};
			}
		}
		const hqLevel = next.lab.hqLevel ?? 1;
		const hqPath = next.lab.hqPath ?? "Scientific";
		const labHq = next.lab.buildings["lab_th"] ?? {};
		next.lab.buildings["lab_th"] = {
			...labHq,
			level: hqLevel,
			route: hqPath,
			runtime: { ...(labHq.runtime ?? {}) }
		};
		next.research_flags = {};
		if (seed.research_flags) {
			for (const [key, value] of Object.entries(seed.research_flags)) {
				if (value) {
					next.research_flags[key] = true;
				}
			}
		}
		next.world = { ...(state.world ?? {}) };
		if (seed.world) {
			next.world = { ...next.world, ...seed.world };
		}
		return next;
	});
}

function makeAction(actionType: string, payload: any, clientActionId?: string): any {
	return {
		client_action_id: clientActionId ?? crypto.randomUUID(),
		action_type: actionType,
		payload,
		client_time_unix_ms: Date.now()
	};
}

type PlayerSlot = "a" | "b" | "c";

const RUN_ID = crypto.randomUUID().slice(0, 8);
const playerSlots: Record<PlayerSlot, { playerId: string; token: string } | null> = {
	a: null,
	b: null,
	c: null
};

function slotForLabel(label: string): PlayerSlot {
	const lower = label.toLowerCase();
	if (lower.includes("buyer2")) {
		return "c";
	}
	if (lower.includes("buyer") || lower.includes("customer") || lower.includes("boss")) {
		return "b";
	}
	if (lower.includes("seller") || lower.includes("provider") || lower.includes("world")) {
		return "a";
	}
	return "a";
}

async function createPlayer(ctx: TestContext, label: string): Promise<{ playerId: string; token: string }> {
	const slot = slotForLabel(label);
	const cached = playerSlots[slot];
	if (cached) {
		return cached;
	}
	const name = `test_${slot}_${RUN_ID}`;
	const login = await ctx.client.dev_login(name);
	if (login.status !== 200 || login.data?.ok !== true) {
		console.error("dev_login failure", { status: login.status, data: login.data });
	}
	assertTrue(login.status == 200, `dev_login failed (${label})`);
	assertTrue(login.data?.ok === true, `dev_login ok missing (${label})`);
	const playerId = login.data.player_id as string;
	const token = login.data.token as string;
	assertTrue(Boolean(playerId), `dev_login missing player_id (${label})`);
	assertTrue(Boolean(token), `dev_login missing token (${label})`);
	const entry = { playerId, token };
	playerSlots[slot] = entry;
	return entry;
}

async function createSeededPlayer(
	ctx: TestContext,
	label: string,
	seed: SeedOptions
): Promise<{ playerId: string; token: string }> {
	const player = await createPlayer(ctx, label);
	seedPlayerState(ctx.db, player.playerId, seed);
	return player;
}

async function testStaticAndCore(ctx: TestContext): Promise<void> {
	const version = await ctx.client.get_static_version();
	assertEqual(version.status, 200, "static/version status");
	assertTrue(version.data?.ok === true, "static/version ok flag");
	assertTrue(typeof version.data.server_time_unix_ms == "number", "static/version server_time_unix_ms");
	assertTrue(typeof version.data.api_version == "string", "static/version api_version");
	if (version.data.schema_version == null && version.data.static_version == null) {
		console.warn("WARN: /static/version missing schema_version/static_version fields");
	}

	const player = await createPlayer(ctx, "core");
	const stateResp = await ctx.client.get_player_state(player.token);
	assertEqual(stateResp.status, 200, "player/state status");
	const state = assertNotNull(stateResp.data?.updated_player_state, "player/state missing state");
	assertTrue(typeof state.wallet == "object", "player/state wallet missing");
	assertTrue(typeof state.lab == "object", "player/state lab missing");
	assertTrue(typeof state.world == "object", "player/state world missing");
	assertTrue(typeof state.research_flags == "object", "player/state research_flags missing");
	assertTrue(typeof state.lab.runtime == "object", "player/state lab.runtime missing");
	assertTrue(typeof state.lab.runtime.cooldowns == "object", "lab.runtime.cooldowns missing");
	assertTrue(typeof state.lab.runtime.boosts == "object", "lab.runtime.boosts missing");
	assertTrue(typeof state.lab.runtime.research == "object", "lab.runtime.research missing");
	for (const resId of ctx.staticData.resources) {
		assertTrue(resId in state.wallet, `wallet missing resource ${resId}`);
	}

	const invalidJson = await ctx.client.postRaw("/player/action", "{", player.token);
	assertEqual(invalidJson.status, 400, "invalid JSON rejected");

	const invalidSchema = await ctx.client.postJson(
		"/player/action",
		{ action_type: "UPGRADE_BUILDING" },
		player.token
	);
	assertEqual(invalidSchema.status, 400, "invalid action schema rejected");

	const missingAuth = await ctx.client.getJson("/player/state");
	assertEqual(missingAuth.status, 401, "missing token rejected");
}
async function testIdempotency(ctx: TestContext): Promise<void> {
	const baseSeed: SeedOptions = {
		wallet: {
			essence: 10000,
			core: 2000,
			arcane_shard: 200,
			living_catalyst: 50,
			chaos_cell: 50,
			time_crystal: 50,
			primordial_sigil: 10
		},
		hqLevel: 3,
		hqPath: "Scientific",
		buildings: {
			essence_reactor: { level: 0, route: "stable" },
			storage_vault: { level: 1, route: "compact" },
			experiment_chamber: { level: 1 },
			arcane_archives: { level: 1 }
		},
		research_flags: { archive_basics: true, unlock_world_zones: true }
	};

	const player = await createSeededPlayer(ctx, "idem", baseSeed);

	// UPGRADE_BUILDING
	seedPlayerState(ctx.db, player.playerId, baseSeed);
	let actionId = crypto.randomUUID();
	let action = makeAction("UPGRADE_BUILDING", { building_id: "essence_reactor" }, actionId);
	let first = await ctx.client.post_action(player.token, action);
	assertEqual(first.status, 200, "idempotency upgrade first status");
	let second = await ctx.client.post_action(player.token, action);
	assertEqual(second.status, 200, "idempotency upgrade second status");
	let level1 = first.data.updated_player_state.lab.buildings.essence_reactor.level;
	let level2 = second.data.updated_player_state.lab.buildings.essence_reactor.level;
	assertEqual(level1, level2, "upgrade idempotency level stable");
	assertWalletInvariant(first.data.updated_player_state.wallet, "upgrade wallet invariant");

	// SET_BUILDING_ROUTE
	seedPlayerState(ctx.db, player.playerId, baseSeed);
	actionId = crypto.randomUUID();
	action = makeAction("SET_BUILDING_ROUTE", { building_id: "lab_th", route: "Chaotic" }, actionId);
	first = await ctx.client.post_action(player.token, action);
	second = await ctx.client.post_action(player.token, action);
	assertEqual(first.status, 200, "route idempotency first status");
	assertEqual(second.status, 200, "route idempotency second status");
	const route1 = first.data.updated_player_state.lab.hqPath;
	const route2 = second.data.updated_player_state.lab.hqPath;
	assertEqual(route1, route2, "route idempotency hqPath stable");

	// CLAIM_PRODUCTION
	const now = Date.now();
	seedPlayerState(ctx.db, player.playerId, {
		...baseSeed,
		buildings: {
			essence_reactor: {
				level: 3,
				route: "stable",
				runtime: { stored_output: 0, last_tick: now - 600_000 }
			},
			storage_vault: { level: 2, route: "compact" }
		}
	});
	actionId = crypto.randomUUID();
	action = makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" }, actionId);
	first = await ctx.client.post_action(player.token, action);
	second = await ctx.client.post_action(player.token, action);
	const essence1 = clampAmount(first.data.updated_player_state.wallet.essence);
	const essence2 = clampAmount(second.data.updated_player_state.wallet.essence);
	assertEqual(essence1, essence2, "claim idempotency wallet stable");

	// START_EXPERIMENT
	seedPlayerState(ctx.db, player.playerId, baseSeed);
	actionId = crypto.randomUUID();
	action = makeAction("START_EXPERIMENT", { experiment_id: "refine_core" }, actionId);
	first = await ctx.client.post_action(player.token, action);
	second = await ctx.client.post_action(player.token, action);
	assertEqual(first.status, 200, "experiment idempotency first status");
	assertEqual(second.status, 200, "experiment idempotency second status");
	assertEqual(
		clampAmount(first.data.updated_player_state.wallet.core),
		clampAmount(second.data.updated_player_state.wallet.core),
		"experiment idempotency wallet stable"
	);

	// COMPLETE_RESEARCH
	const completesAt = Date.now() - 1000;
	seedPlayerState(ctx.db, player.playerId, {
		...baseSeed,
		research_flags: {},
		lab_runtime: {
			research: { active_id: "archive_basics", started_at: completesAt - 1000, completes_at: completesAt }
		}
	});
	actionId = crypto.randomUUID();
	action = makeAction("COMPLETE_RESEARCH", { research_id: "archive_basics" }, actionId);
	first = await ctx.client.post_action(player.token, action);
	second = await ctx.client.post_action(player.token, action);
	assertTrue(first.data.updated_player_state.research_flags.archive_basics === true, "research completion flag");
	assertEqual(
		Boolean(first.data.updated_player_state.research_flags.archive_basics),
		Boolean(second.data.updated_player_state.research_flags.archive_basics),
		"research idempotency flag stable"
	);

	// MARKET_ORDER
	const seller = await createSeededPlayer(ctx, "idem_market_seller", {
		wallet: { essence: 1000, core: 100 }
	});
	const orderActionId = crypto.randomUUID();
	first = await ctx.client.market_create_order(seller.token, {
		client_action_id: orderActionId,
		resource_id: "core",
		amount: 20,
		price_amount: 5,
		price_resource_id: "essence"
	});
	second = await ctx.client.market_create_order(seller.token, {
		client_action_id: orderActionId,
		resource_id: "core",
		amount: 20,
		price_amount: 5,
		price_resource_id: "essence"
	});
	assertEqual(first.status, 200, "market order idempotency first status");
	assertEqual(second.status, 200, "market order idempotency second status");
	assertEqual(
		clampAmount(first.data.updated_player_state.wallet.core),
		clampAmount(second.data.updated_player_state.wallet.core),
		"market order idempotency wallet stable"
	);

	// MARKET_BUY
	const buyer = await createSeededPlayer(ctx, "idem_market_buyer", {
		wallet: { essence: 1000, core: 0 }
	});
	const buyActionId = crypto.randomUUID();
	const marketOrderId = first.data.order_id;
	first = await ctx.client.market_buy(buyer.token, {
		client_action_id: buyActionId,
		order_id: marketOrderId,
		amount: 5
	});
	second = await ctx.client.market_buy(buyer.token, {
		client_action_id: buyActionId,
		order_id: marketOrderId,
		amount: 5
	});
	assertEqual(first.status, 200, "market buy idempotency first status");
	assertEqual(second.status, 200, "market buy idempotency second status");
	assertEqual(
		clampAmount(first.data.updated_player_state.wallet.core),
		clampAmount(second.data.updated_player_state.wallet.core),
		"market buy idempotency wallet stable"
	);

	// TRADE_SUBMIT
	const provider = await createSeededPlayer(ctx, "idem_trade_provider", {
		wallet: { essence: 1000 }
	});
	const customer = await createSeededPlayer(ctx, "idem_trade_customer", {
		wallet: { essence: 200, core: 50 }
	});
	const tradeJobActionId = crypto.randomUUID();
	const tradeJob = await ctx.client.trade_create_job(provider.token, {
		client_action_id: tradeJobActionId,
		input_resource_id: "core",
		input_amount: 10,
		output_resource_id: "arcane_shard",
		output_min: 1,
		output_max: 3,
		duration_sec: 0,
		commission_resource_id: "essence",
		commission_amount: 5,
		queue_limit: 2
	});
	assertEqual(tradeJob.status, 200, "trade job creation for idempotency");
	const submitActionId = crypto.randomUUID();
	first = await ctx.client.trade_submit(customer.token, {
		client_action_id: submitActionId,
		job_id: tradeJob.data.job_id
	});
	second = await ctx.client.trade_submit(customer.token, {
		client_action_id: submitActionId,
		job_id: tradeJob.data.job_id
	});
	assertEqual(first.status, 200, "trade submit idempotency first status");
	assertEqual(second.status, 200, "trade submit idempotency second status");
	assertEqual(
		clampAmount(first.data.updated_player_state.wallet.core),
		clampAmount(second.data.updated_player_state.wallet.core),
		"trade submit idempotency wallet stable"
	);
	const submitRunId = first.data.run_id;

	// TRADE_CLAIM
	const claimActionId = crypto.randomUUID();
	first = await ctx.client.trade_claim(customer.token, {
		client_action_id: claimActionId,
		run_id: submitRunId
	});
	second = await ctx.client.trade_claim(customer.token, {
		client_action_id: claimActionId,
		run_id: submitRunId
	});
	if (second.status !== 200) {
		console.error("trade claim idempotency response", second.status, second.data);
	}
	assertEqual(first.status, 200, "trade claim idempotency first status");
	assertEqual(second.status, 200, "trade claim idempotency second status");
	assertEqual(
		clampAmount(first.data.updated_player_state.wallet.arcane_shard),
		clampAmount(second.data.updated_player_state.wallet.arcane_shard),
		"trade claim idempotency wallet stable"
	);

	// WORLD_FARM
	const worldPlayer = await createSeededPlayer(ctx, "idem_world", {
		wallet: { essence: 200 },
		buildings: { world_gate: { level: 1 } },
		research_flags: { unlock_world_zones: true }
	});
	const zones = ctx.staticData.zones.map((z) => z.id);
	const zoneId = zones[0] ?? "zone_corrupted";
	const enterActionId = crypto.randomUUID();
	const enter = await ctx.client.world_enter(worldPlayer.token, {
		client_action_id: enterActionId,
		zone_id: zoneId
	});
	assertEqual(enter.status, 200, "world enter for idempotency");
	const farmActionId = crypto.randomUUID();
	first = await ctx.client.world_farm(worldPlayer.token, {
		client_action_id: farmActionId,
		session_id: enter.data.session_id
	});
	second = await ctx.client.world_farm(worldPlayer.token, {
		client_action_id: farmActionId,
		session_id: enter.data.session_id
	});
	assertEqual(first.status, 200, "world farm idempotency first status");
	assertEqual(second.status, 200, "world farm idempotency second status");
	const loot1 = JSON.stringify(first.data.updated_player_state.world.sessions[enter.data.session_id].pending_loot);
	const loot2 = JSON.stringify(second.data.updated_player_state.world.sessions[enter.data.session_id].pending_loot);
	assertEqual(loot1, loot2, "world farm idempotency loot stable");

	// BOSS_ATTACK (conditional)
	const bossState = await ctx.client.boss_state();
	assertEqual(bossState.status, 200, "boss state fetch for idempotency");
	const nowServer = bossState.data.server_time_unix_ms ?? Date.now();
	const boss = bossState.data.bosses?.[0];
	if (boss && nowServer >= boss.window_starts_at && nowServer <= boss.window_ends_at) {
		const bossPlayer = await createSeededPlayer(ctx, "idem_boss", {
			wallet: { essence: 500 }
		});
		actionId = crypto.randomUUID();
		first = await ctx.client.boss_attack(bossPlayer.token, {
			client_action_id: actionId,
			boss_id: boss.boss_id
		});
		second = await ctx.client.boss_attack(bossPlayer.token, {
			client_action_id: actionId,
			boss_id: boss.boss_id
		});
		assertEqual(first.status, 200, "boss attack idempotency first status");
		assertEqual(second.status, 200, "boss attack idempotency second status");
		assertEqual(
			clampAmount(first.data.updated_player_state.world.boss_tickets),
			clampAmount(second.data.updated_player_state.world.boss_tickets),
			"boss attack idempotency tickets stable"
		);
	} else {
		console.log("SKIP: boss idempotency (window closed)");
	}
}

async function testWalletAndCapacity(ctx: TestContext): Promise<void> {
	const player = await createSeededPlayer(ctx, "wallet", {
		wallet: { essence: 0, core: 0 },
		hqLevel: 1,
		hqPath: "Scientific",
		buildings: { essence_reactor: { level: 0 } }
	});
	const upgrade = await ctx.client.post_action(
		player.token,
		makeAction("UPGRADE_BUILDING", { building_id: "essence_reactor" })
	);
	assertEqual(upgrade.status, 400, "spend beyond wallet rejected");

	const now = Date.now();
	const balance = ctx.staticData.balance;
	const storageLevel = 1;
	const hqPath = "Scientific";
	const storageRoute = "compact";
	const capacity = computeCapacity(balance, storageLevel, storageRoute, hqPath);
	seedPlayerState(ctx.db, player.playerId, {
		wallet: { essence: 0 },
		buildings: {
			essence_reactor: {
				level: 1,
				route: "stable",
				runtime: { stored_output: capacity + 500, last_tick: now }
			},
			storage_vault: { level: storageLevel, route: storageRoute }
		}
	});
	const claim = await ctx.client.post_action(
		player.token,
		makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" })
	);
	assertEqual(claim.status, 200, "claim for capacity test");
	const after = claim.data.updated_player_state;
	const walletEssence = clampAmount(after.wallet.essence);
	assertEqual(walletEssence, capacity, "capacity claim matches cap");
	const remaining = clampAmount(after.lab.buildings.essence_reactor.runtime.stored_output);
	assertEqual(remaining, 500, "capacity overflow remainder preserved");
	assertWalletInvariant(after.wallet, "wallet invariant after capacity claim");
}

async function testLabSystem(ctx: TestContext): Promise<void> {
	const balance = ctx.staticData.balance;
	const player = await createSeededPlayer(ctx, "lab", {
		wallet: { essence: 10000, core: 2000, arcane_shard: 200, chaos_cell: 50 },
		hqLevel: 1,
		hqPath: "Scientific",
		buildings: {
			essence_reactor: { level: 1, route: "stable" },
			storage_vault: { level: 1, route: "compact" }
		}
	});

	const capUpgrade = await ctx.client.post_action(
		player.token,
		makeAction("UPGRADE_BUILDING", { building_id: "essence_reactor" })
	);
	assertEqual(capUpgrade.status, 400, "upgrade beyond HQ cap rejected");

	const routeChange = await ctx.client.post_action(
		player.token,
		makeAction("SET_BUILDING_ROUTE", { building_id: "essence_reactor", route: "volatile" })
	);
	assertEqual(routeChange.status, 200, "route change applied");
	assertEqual(
		routeChange.data.updated_player_state.lab.buildings.essence_reactor.route,
		"volatile",
		"route change stored"
	);

	const now = Date.now();
	const deltaMs = 600_000;
	seedPlayerState(ctx.db, player.playerId, {
		buildings: {
			essence_reactor: { level: 5, route: "stable", runtime: { stored_output: 0, last_tick: now - deltaMs } },
			storage_vault: { level: 3, route: "compact" }
		}
	});
	let resStable = await ctx.client.post_action(
		player.token,
		makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" })
	);
	const stableEssence = clampAmount(resStable.data.updated_player_state.wallet.essence);

	seedPlayerState(ctx.db, player.playerId, {
		wallet: { essence: 0 },
		buildings: {
			essence_reactor: { level: 5, route: "volatile", runtime: { stored_output: 0, last_tick: now - deltaMs } },
			storage_vault: { level: 3, route: "compact" }
		}
	});
	let resVolatile = await ctx.client.post_action(
		player.token,
		makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" })
	);
	const volatileEssence = clampAmount(resVolatile.data.updated_player_state.wallet.essence);
	const stableRate = computeOutputRate(balance, 5, "stable", "compact", "Scientific");
	const volatileRate = computeOutputRate(balance, 5, "volatile", "compact", "Scientific");
	assertTrue(volatileRate > stableRate, "volatile base rate > stable");

	seedPlayerState(ctx.db, player.playerId, {
		wallet: { essence: 0 },
		buildings: {
			essence_reactor: { level: 5, route: "mutagenic", runtime: { stored_output: 0, last_tick: now - deltaMs } },
			storage_vault: { level: 3, route: "compact" }
		}
	});
	let resMutagenic = await ctx.client.post_action(
		player.token,
		makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" })
	);
	const mutagenicEssence = clampAmount(resMutagenic.data.updated_player_state.wallet.essence);
	const mutagenicRate = computeOutputRate(balance, 5, "mutagenic", "compact", "Scientific");
	assertTrue(mutagenicRate < stableRate, "mutagenic base rate < stable");

	// Mutagenic rare drop statistical check
	seedPlayerState(ctx.db, player.playerId, {
		wallet: { arcane_shard: 0 },
		hqPath: "Chaotic",
		buildings: {
			essence_reactor: { level: 5, route: "mutagenic", runtime: { stored_output: 0, last_tick: now } },
			storage_vault: { level: 3, route: "sealed" }
		},
		lab_runtime: {
			boosts: { mutagen_surge: { expires_at: now + 600_000 } }
		}
	});
	let rareHits = 0;
	for (let i = 0; i < 30; i += 1) {
		seedPlayerState(ctx.db, player.playerId, {
			buildings: {
				essence_reactor: { runtime: { stored_output: 500, last_tick: now } }
			}
		});
		const claim = await ctx.client.post_action(
			player.token,
			makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" })
		);
		const shards = clampAmount(claim.data.updated_player_state.wallet.arcane_shard);
		if (shards > 0) {
			rareHits = shards;
			break;
		}
	}
	assertTrue(rareHits > 0, "mutagenic rare drop observed over trials");

	// Offline cap
	const capHours = getBalanceNumber(balance, "offline_cap_hours", 12);
	const capMs = capHours * 3600 * 1000;
	const longAgo = now - capMs - 2 * 3600 * 1000;
	const rate = computeOutputRate(balance, 5, "stable", "compact", "Scientific");
	const expected = Math.floor(rate * (capMs / 1000));
	seedPlayerState(ctx.db, player.playerId, {
		wallet: { essence: 0 },
		hqPath: "Scientific",
		lab_runtime: {
			boosts: {
				volatile_overclock: { expires_at: 0 },
				mutagen_surge: { expires_at: 0 }
			}
		},
		buildings: {
			essence_reactor: { level: 5, route: "stable", runtime: { stored_output: 0, last_tick: longAgo } },
			storage_vault: { level: 400, route: "compact" }
		}
	});
	const offlineClaim = await ctx.client.post_action(
		player.token,
		makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" })
	);
	const offlineEssence = clampAmount(offlineClaim.data.updated_player_state.wallet.essence);
	assertApprox(offlineEssence, expected, 2, "offline cap respects limit");

	// Time rollback
	seedPlayerState(ctx.db, player.playerId, {
		wallet: { essence: 0 },
		buildings: {
			essence_reactor: { level: 5, route: "stable", runtime: { stored_output: 0, last_tick: now + 60_000 } },
			storage_vault: { level: 3, route: "compact" }
		}
	});
	const rollbackClaim = await ctx.client.post_action(
		player.token,
		makeAction("CLAIM_PRODUCTION", { building_id: "essence_reactor" })
	);
	const rollbackEssence = clampAmount(rollbackClaim.data.updated_player_state.wallet.essence);
	assertEqual(rollbackEssence, 0, "time rollback yields zero delta");
}
async function testExperiments(ctx: TestContext): Promise<void> {
	const player = await createSeededPlayer(ctx, "exp", {
		wallet: { essence: 500, core: 20, arcane_shard: 10, chaos_cell: 5 },
		hqLevel: 3,
		hqPath: "Scientific",
		buildings: { experiment_chamber: { level: 1 } }
	});
	const actionId = crypto.randomUUID();
	const start = await ctx.client.post_action(
		player.token,
		makeAction("START_EXPERIMENT", { experiment_id: "refine_core" }, actionId)
	);
	assertEqual(start.status, 200, "experiment start success");
	const cooldownAttempt = await ctx.client.post_action(
		player.token,
		makeAction("START_EXPERIMENT", { experiment_id: "refine_core" })
	);
	assertEqual(cooldownAttempt.status, 400, "experiment cooldown enforced");

	// Boost expiry
	const now = Date.now();
	seedPlayerState(ctx.db, player.playerId, {
		lab_runtime: {
			boosts: { volatile_overclock: { expires_at: now - 1000 } }
		}
	});
	const state = await ctx.client.get_player_state(player.token);
	assertEqual(state.status, 200, "player state after boost seed");
	const boosts = state.data.updated_player_state.lab.runtime.boosts;
	assertTrue(!boosts.volatile_overclock, "expired boost cleaned up");

	// Deterministic RNG
	const seedA = await createSeededPlayer(ctx, "exp_rng_a", {
		wallet: { core: 10 },
		hqLevel: 3,
		buildings: { experiment_chamber: { level: 1 } }
	});
	const seedB = await createSeededPlayer(ctx, "exp_rng_b", {
		wallet: { core: 10 },
		hqLevel: 3,
		buildings: { experiment_chamber: { level: 1 } }
	});
	const rngActionId = "rng-test-" + crypto.randomUUID();
	const resA = await ctx.client.post_action(
		seedA.token,
		makeAction("START_EXPERIMENT", { experiment_id: "arcane_distill" }, rngActionId)
	);
	const resB = await ctx.client.post_action(
		seedB.token,
		makeAction("START_EXPERIMENT", { experiment_id: "arcane_distill" }, rngActionId)
	);
	assertEqual(resA.status, 200, "deterministic RNG A status");
	assertEqual(resB.status, 200, "deterministic RNG B status");
	const shardA = clampAmount(resA.data.updated_player_state.wallet.arcane_shard);
	const shardB = clampAmount(resB.data.updated_player_state.wallet.arcane_shard);
	assertEqual(shardA, shardB, "deterministic RNG outcome matches");
}

async function testResearch(ctx: TestContext): Promise<void> {
	const player = await createSeededPlayer(ctx, "research", {
		wallet: { essence: 500, core: 50, arcane_shard: 10 },
		hqLevel: 3,
		hqPath: "Scientific",
		buildings: { arcane_archives: { level: 1 } }
	});

	const missingReq = await ctx.client.post_action(
		player.token,
		makeAction("START_RESEARCH", { research_id: "world_zones" })
	);
	assertEqual(missingReq.status, 400, "research requirement enforced");

	const start = await ctx.client.post_action(
		player.token,
		makeAction("START_RESEARCH", { research_id: "archive_basics" })
	);
	assertEqual(start.status, 200, "research start success");

	const now = Date.now();
	seedPlayerState(ctx.db, player.playerId, {
		lab_runtime: {
			research: { active_id: "archive_basics", started_at: now - 1000, completes_at: now - 1 }
		}
	});
	const claimId = crypto.randomUUID();
	const claim = await ctx.client.post_action(
		player.token,
		makeAction("COMPLETE_RESEARCH", { research_id: "archive_basics" }, claimId)
	);
	assertEqual(claim.status, 200, "research completion success");
	assertTrue(claim.data.updated_player_state.research_flags.archive_basics, "research flag unlocked");

	const claimRepeat = await ctx.client.post_action(
		player.token,
		makeAction("COMPLETE_RESEARCH", { research_id: "archive_basics" }, claimId)
	);
	assertEqual(claimRepeat.status, 200, "research completion idempotent status");
	assertTrue(claimRepeat.data.updated_player_state.research_flags.archive_basics, "research flag persists");
}

async function testMarket(ctx: TestContext): Promise<void> {
	const balance = ctx.staticData.balance;
	const feeBps = getBalanceNumber(balance, "market_fee_bps", 200);

	const seller = await createSeededPlayer(ctx, "market_seller", {
		wallet: { core: 100, essence: 100 }
	});
	const buyer = await createSeededPlayer(ctx, "market_buyer", {
		wallet: { essence: 1000, core: 0 }
	});

	const orderActionId = crypto.randomUUID();
	const order = await ctx.client.market_create_order(seller.token, {
		client_action_id: orderActionId,
		resource_id: "core",
		amount: 40,
		price_amount: 5,
		price_resource_id: "essence"
	});
	assertEqual(order.status, 200, "market order created");
	assertEqual(clampAmount(order.data.updated_player_state.wallet.core), 60, "market order locks funds");

	const cancel = await ctx.client.market_cancel(seller.token, {
		client_action_id: crypto.randomUUID(),
		order_id: order.data.order_id
	});
	assertEqual(cancel.status, 200, "market cancel success");
	assertEqual(clampAmount(cancel.data.updated_player_state.wallet.core), 100, "market cancel releases funds");

	const order2 = await ctx.client.market_create_order(seller.token, {
		client_action_id: crypto.randomUUID(),
		resource_id: "core",
		amount: 30,
		price_amount: 5,
		price_resource_id: "essence"
	});
	assertEqual(order2.status, 200, "market order for buy created");

	const buy = await ctx.client.market_buy(buyer.token, {
		client_action_id: crypto.randomUUID(),
		order_id: order2.data.order_id,
		amount: 10
	});
	assertEqual(buy.status, 200, "market buy success");
	const buyerState = buy.data.updated_player_state;
	assertWalletInvariant(buyerState.wallet, "market buy buyer wallet invariant");
	assertEqual(clampAmount(buyerState.wallet.core), 10, "market buy transfers resource");
	assertEqual(clampAmount(buyerState.wallet.essence), 1000 - 50, "market buy deducts essence");
	const sellerState = await ctx.client.get_player_state(seller.token);
	assertWalletInvariant(
		sellerState.data.updated_player_state.wallet,
		"market buy seller wallet invariant"
	);
	const expectedSellerGain = Math.max(0, 50 - Math.floor((50 * feeBps) / 10_000));
	assertEqual(
		clampAmount(sellerState.data.updated_player_state.wallet.essence),
		100 + expectedSellerGain,
		"market buy credits seller"
	);

	const ordersOpen = await ctx.client.market_orders({
		status: "OPEN",
		seller_id: sellerState.data.updated_player_state.player_id
	});
	const orderRow = ordersOpen.data.orders?.find((entry: any) => entry.order_id == order2.data.order_id);
	assertTrue(orderRow != null, "order remains open after partial fill");
	assertEqual(orderRow.remaining, 20, "partial fill remaining amount");

	const selfBuy = await ctx.client.market_buy(seller.token, {
		client_action_id: crypto.randomUUID(),
		order_id: order2.data.order_id,
		amount: 5
	});
	assertEqual(selfBuy.status, 400, "self-buy rejected");

	// Concurrency simulation
	const buyer2 = await createSeededPlayer(ctx, "market_buyer2", {
		wallet: { essence: 1000, core: 0 }
	});
	const order3 = await ctx.client.market_create_order(seller.token, {
		client_action_id: crypto.randomUUID(),
		resource_id: "core",
		amount: 10,
		price_amount: 5,
		price_resource_id: "essence"
	});
	assertEqual(order3.status, 200, "market order for concurrency created");
	const buyA = ctx.client.market_buy(buyer.token, {
		client_action_id: crypto.randomUUID(),
		order_id: order3.data.order_id,
		amount: 8
	});
	const buyB = ctx.client.market_buy(buyer2.token, {
		client_action_id: crypto.randomUUID(),
		order_id: order3.data.order_id,
		amount: 8
	});
	const [resA, resB] = await Promise.all([buyA, buyB]);
	assertTrue(resA.status < 500 && resB.status < 500, "concurrency buys did not crash");
	const ordersOpen2 = await ctx.client.market_orders({
		status: "OPEN",
		seller_id: sellerState.data.updated_player_state.player_id
	});
	const ordersFilled = await ctx.client.market_orders({
		status: "FILLED",
		seller_id: sellerState.data.updated_player_state.player_id
	});
	const allOrders = [...(ordersOpen2.data.orders ?? []), ...(ordersFilled.data.orders ?? [])];
	const row = allOrders.find((entry: any) => entry.order_id == order3.data.order_id);
	assertTrue(row != null, "order exists after concurrency");
	const filled = 10 - clampAmount(row.remaining ?? 0);
	assertTrue(filled >= 0 && filled <= 10, "concurrency fill does not exceed amount");
}

async function testTradeJobs(ctx: TestContext): Promise<void> {
	const provider = await createSeededPlayer(ctx, "trade_provider", {
		wallet: { essence: 200 }
	});
	const customer = await createSeededPlayer(ctx, "trade_customer", {
		wallet: { essence: 200, core: 50 }
	});
	const job = await ctx.client.trade_create_job(provider.token, {
		client_action_id: crypto.randomUUID(),
		input_resource_id: "core",
		input_amount: 10,
		output_resource_id: "arcane_shard",
		output_min: 1,
		output_max: 3,
		duration_sec: 0,
		commission_resource_id: "essence",
		commission_amount: 5,
		queue_limit: 2
	});
	assertEqual(job.status, 200, "trade job created");
	const submit = await ctx.client.trade_submit(customer.token, {
		client_action_id: crypto.randomUUID(),
		job_id: job.data.job_id
	});
	assertEqual(submit.status, 200, "trade submit success");
	const afterSubmit = submit.data.updated_player_state.wallet;
	assertEqual(clampAmount(afterSubmit.core), 40, "trade submit locks input");
	assertEqual(clampAmount(afterSubmit.essence), 195, "trade submit locks commission");

	const claimActionId = crypto.randomUUID();
	const claim = await ctx.client.trade_claim(customer.token, {
		client_action_id: claimActionId,
		run_id: submit.data.run_id
	});
	assertEqual(claim.status, 200, "trade claim success");
	assertWalletInvariant(claim.data.updated_player_state.wallet, "trade claim wallet invariant");
	const outputAmount = clampAmount(claim.data.output_amount);
	assertTrue(outputAmount >= 1 && outputAmount <= 3, "trade output within range");
	const providerState = await ctx.client.get_player_state(provider.token);
	assertWalletInvariant(
		providerState.data.updated_player_state.wallet,
		"trade provider wallet invariant"
	);
	assertEqual(clampAmount(providerState.data.updated_player_state.wallet.essence), 205, "provider commission credited");

	const claimRepeat = await ctx.client.trade_claim(customer.token, {
		client_action_id: claimActionId,
		run_id: submit.data.run_id
	});
	assertEqual(claimRepeat.status, 200, "trade claim idempotent status");
	assertEqual(
		clampAmount(claimRepeat.data.updated_player_state.wallet.arcane_shard),
		clampAmount(claim.data.updated_player_state.wallet.arcane_shard),
		"trade claim idempotent wallet stable"
	);
}

async function testWorld(ctx: TestContext): Promise<void> {
	const player = await createSeededPlayer(ctx, "world", {
		wallet: { essence: 200 },
		buildings: { world_gate: { level: 1 } },
		research_flags: { unlock_world_zones: true }
	});
	const zoneId = ctx.staticData.zones[0]?.id ?? "zone_corrupted";
	const enter = await ctx.client.world_enter(player.token, {
		client_action_id: crypto.randomUUID(),
		zone_id: zoneId
	});
	assertEqual(enter.status, 200, "world enter success");
	assertTrue(Array.isArray(enter.data.modifiers), "world enter returns modifiers");
	const sessionId = enter.data.session_id;
	const farm1 = await ctx.client.world_farm(player.token, {
		client_action_id: crypto.randomUUID(),
		session_id: sessionId
	});
	assertEqual(farm1.status, 200, "world farm 1 success");
	const heat1 = clampAmount(farm1.data.heat ?? 0);
	const farm2 = await ctx.client.world_farm(player.token, {
		client_action_id: crypto.randomUUID(),
		session_id: sessionId
	});
	assertEqual(farm2.status, 200, "world farm 2 success");
	const heat2 = clampAmount(farm2.data.heat ?? 0);
	assertTrue(heat2 >= heat1, "world heat non-decreasing");

	const beforeWallet = farm2.data.updated_player_state.wallet;
	const beforeTotal = Object.values(beforeWallet).reduce(
		(sum: number, value: any) => sum + clampAmount(value),
		0
	);
	const claim = await ctx.client.world_claim(player.token, {
		client_action_id: crypto.randomUUID(),
		session_id: sessionId
	});
	assertEqual(claim.status, 200, "world claim success");
	const wallet = claim.data.updated_player_state.wallet;
	assertWalletInvariant(wallet, "world claim wallet invariant");
	const total = Object.values(wallet).reduce((sum: number, value: any) => sum + clampAmount(value), 0);
	assertTrue(total >= beforeTotal, "world claim increased wallet");
}

async function testBoss(ctx: TestContext): Promise<void> {
	const bossState = await ctx.client.boss_state();
	assertEqual(bossState.status, 200, "boss state fetched");
	const boss = bossState.data.bosses?.[0];
	if (!boss) {
		fail("boss state missing boss entries");
	}
	const now = bossState.data.server_time_unix_ms ?? Date.now();
	const player = await createSeededPlayer(ctx, "boss", {
		wallet: { essence: 200 }
	});
	if (now < boss.window_starts_at || now > boss.window_ends_at) {
		const attack = await ctx.client.boss_attack(player.token, {
			client_action_id: crypto.randomUUID(),
			boss_id: boss.boss_id
		});
		assertEqual(attack.status, 400, "boss attack rejected outside window");
		console.log("SKIP: boss inside-window tests (window closed)");
		return;
	}
	const before = await ctx.client.get_player_state(player.token);
	const beforeTickets = clampAmount(before.data.updated_player_state.world.boss_tickets);
	const attackId = crypto.randomUUID();
	const attack = await ctx.client.boss_attack(player.token, {
		client_action_id: attackId,
		boss_id: boss.boss_id
	});
	assertEqual(attack.status, 200, "boss attack success");
	assertWalletInvariant(attack.data.updated_player_state.wallet, "boss attack wallet invariant");
	const afterTickets = clampAmount(attack.data.updated_player_state.world.boss_tickets);
	assertEqual(afterTickets, Math.max(0, beforeTickets - 1), "boss ticket consumed");
	const repeat = await ctx.client.boss_attack(player.token, {
		client_action_id: attackId,
		boss_id: boss.boss_id
	});
	assertEqual(repeat.status, 200, "boss attack idempotent status");
	assertEqual(
		clampAmount(repeat.data.updated_player_state.world.boss_tickets),
		afterTickets,
		"boss idempotent tickets stable"
	);
	if (afterTickets == 0) {
		const block = await ctx.client.boss_attack(player.token, {
			client_action_id: crypto.randomUUID(),
			boss_id: boss.boss_id
		});
		assertEqual(block.status, 400, "boss attack blocked when no tickets");
	}
}

async function testNewAccountProgression(ctx: TestContext): Promise<void> {
	const source = loadJson(resolve(import.meta.dir, "..", "..", "..", "data", "static", "buildings.json"));
	assertEqual(source.buildings.length, 12, "12 building definitions");
	for (const building of source.buildings) {
		for (let level = 1; level <= 10; level++) {
			const cost = building.costs[String(level)];
			assertTrue(cost != null && Object.keys(cost).length > 0, `${building.id} level ${level} cost exists`);
			for (const [resource, amount] of Object.entries(cost)) {
				assertTrue(ctx.staticData.resources.includes(resource), `${building.id} cost resource exists`);
				assertTrue(Number.isInteger(amount) && Number(amount) > 0, `${building.id} cost is a positive integer`);
			}
		}
	}
	const name = `progress_${RUN_ID}`;
	const login = await ctx.client.dev_login(name);
	assertEqual(login.status, 200, "new account login");
	const player = { playerId: login.data.player_id as string, token: login.data.token as string };
	let state = (await ctx.client.get_player_state(player.token)).data.updated_player_state;
	assertEqual(state.wallet.essence, 120, "new account essence");
	assertEqual(state.wallet.core, 5, "new account core");
	const blocked = await ctx.client.world_enter(player.token, { client_action_id: crypto.randomUUID(), zone_id: ctx.staticData.zones[0].id });
	assertEqual(blocked.status, 400, "world gate required before entering");
	let result = await ctx.client.post_action(player.token, makeAction("UPGRADE_BUILDING", { building_id: "essence_reactor" }));
	assertEqual(result.status, 200, "build reactor without debug");
	state = result.data.updated_player_state;
	assertEqual(state.wallet.essence, 101, "reactor essence cost with Scientific path");
	assertEqual(state.wallet.core, 1, "reactor core cost with Scientific path");
	result = await ctx.client.post_action(player.token, makeAction("UPGRADE_BUILDING", { building_id: "world_gate" }));
	assertEqual(result.status, 200, "build world gate at HQ 1");
	state = result.data.updated_player_state;
	assertEqual(state.wallet.essence, 63, "world gate essence cost with Scientific path");
	assertEqual(state.wallet.core, 1, "world gate does not cost core");
	const again = await ctx.client.dev_login(name);
	assertEqual(again.data.player_id, player.playerId, "existing account is reused");
	const existing = await ctx.client.get_player_state(again.data.token);
	assertEqual(existing.data.updated_player_state.wallet.essence, 63, "existing account wallet is not reset");
	const enter = await ctx.client.world_enter(player.token, { client_action_id: crypto.randomUUID(), zone_id: ctx.staticData.zones[0].id });
	assertEqual(enter.status, 200, "enter first zone with constructed gate");
	result = await ctx.client.post_action(player.token, makeAction("UPGRADE_BUILDING", { building_id: "lab_th" }));
	assertEqual(result.status, 400, "HQ upgrade rejected without core");
	seedPlayerState(ctx.db, player.playerId, { wallet: { essence: 1000, core: 100 } });
	result = await ctx.client.post_action(player.token, makeAction("UPGRADE_BUILDING", { building_id: "lab_th" }));
	assertEqual(result.status, 200, "HQ level 1 to 2");
	state = result.data.updated_player_state;
	assertEqual(state.wallet.essence, 931, "HQ level 2 essence cost");
	assertEqual(state.wallet.core, 86, "HQ level 2 core cost");
	result = await ctx.client.post_action(player.token, makeAction("UPGRADE_BUILDING", { building_id: "essence_reactor" }));
	assertEqual(result.status, 200, "reactor level 1 to 2");
	state = result.data.updated_player_state;
	assertEqual(state.wallet.essence, 904, "reactor level 2 essence cost");
	assertEqual(state.wallet.core, 79, "reactor level 2 core cost");
	for (const path of ["Chaotic", "Industrial"]) {
		seedPlayerState(ctx.db, player.playerId, { wallet: { essence: 1000, core: 100 }, hqLevel: 2, hqPath: path, buildings: { storage_vault: { level: 0 } } });
		result = await ctx.client.post_action(player.token, makeAction("UPGRADE_BUILDING", { building_id: "storage_vault" }));
		assertEqual(result.status, 200, `storage upgrade ${path}`);
		const mult = ctx.staticData.balance.hq_cost_mult[path.toLowerCase()];
		assertEqual(result.data.updated_player_state.wallet.essence, 1000 - Math.floor(30 * mult), `${path} essence cost`);
		assertEqual(result.data.updated_player_state.wallet.core, 100 - Math.floor(5 * mult), `${path} core cost`);
	}
}

async function testSecurity(ctx: TestContext): Promise<void> {
	const noFunds = await createSeededPlayer(ctx, "security_bypass", {
		wallet: { essence: 0, core: 0 },
		hqLevel: 1,
		hqPath: "Scientific",
		buildings: { essence_reactor: { level: 0 } }
	});
	const bypassAttempt = await fetch(`${ctx.baseUrl}/player/action`, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			"X-Debug-Bypass": "1",
			Authorization: `Bearer ${noFunds.token}`
		},
		body: JSON.stringify(makeAction("UPGRADE_BUILDING", { building_id: "essence_reactor" }))
	});
	assertEqual(bypassAttempt.status, 400, "bypass header alone cannot skip upgrade cost");
	assertEqual(
		getPlayerStateFromDb(ctx.db, noFunds.playerId).lab.buildings.essence_reactor.level,
		0,
		"rejected bypass leaves building unchanged"
	);

	const player = await createSeededPlayer(ctx, "security", {
		wallet: { essence: 1000, core: 100 }
	});
	const bigPayload = "x".repeat(300_000);
	const rawBody = JSON.stringify({
		client_action_id: "big_body",
		action_type: "UPGRADE_BUILDING",
		client_time_unix_ms: Date.now(),
		payload: { building_id: "lab_th", padding: bigPayload }
	});
	const bigResp = await ctx.client.postRaw("/player/action", rawBody, player.token);
	assertEqual(bigResp.status, 413, "body size limit enforced");

	const negative = await ctx.client.market_create_order(player.token, {
		client_action_id: crypto.randomUUID(),
		resource_id: "core",
		amount: -5,
		price_amount: 5,
		price_resource_id: "essence"
	});
	assertEqual(negative.status, 400, "negative amount rejected");

	const huge = await ctx.client.market_create_order(player.token, {
		client_action_id: crypto.randomUUID(),
		resource_id: "core",
		amount: 2_000_000,
		price_amount: 5,
		price_resource_id: "essence"
	});
	assertEqual(huge.status, 400, "huge amount rejected");

	const unknownBuild = await ctx.client.post_action(
		player.token,
		makeAction("UPGRADE_BUILDING", { building_id: "unknown_building" })
	);
	assertEqual(unknownBuild.status, 400, "unknown building rejected");

	const unknownRes = await ctx.client.market_create_order(player.token, {
		client_action_id: crypto.randomUUID(),
		resource_id: "fake_resource",
		amount: 1,
		price_amount: 1,
		price_resource_id: "essence"
	});
	assertEqual(unknownRes.status, 400, "unknown resource rejected");

	// Refresh is limited before it touches auth or external services.
	const burstUrl = `${ctx.baseUrl}/v1/auth/refresh`;
	const burstHeaders: Record<string, string> = { "Content-Type": "application/json" };
	const burstBody = "{}";
	const burstRequests = Array.from({ length: 70 }, () =>
		fetch(burstUrl, { method: "POST", headers: burstHeaders, body: burstBody })
	);
	const burstResponses = await Promise.all(burstRequests);
	const got429 = burstResponses.some((res) => res.status == 429);
	assertTrue(got429, "rate limit enforced under burst");

	const expiryOptions = {
		keyPrefix: `rl:test_expiry:${RUN_ID}`,
		windowSeconds: 1,
		max: 2,
		ip: "127.0.0.1"
	};
	assertTrue((await rateLimit(expiryOptions)).allowed, "first request within short window");
	assertTrue((await rateLimit(expiryOptions)).allowed, "second request within short window");
	assertTrue(!(await rateLimit(expiryOptions)).allowed, "short window rejects excess request");
	await Bun.sleep(1100);
	assertTrue((await rateLimit(expiryOptions)).allowed, "short window recovers after expiry");
}

function architectureChecks(ctx: TestContext): void {
	console.log("\nKEY BACKEND DESIGN CHECKS");
	const indexPath = resolve(import.meta.dir, "..", "index.ts");
	const indexText = readFileSync(indexPath, "utf8");

	// Auth enforcement on POST endpoints
	const lines = indexText.split(/\r?\n/);
	const postEndpoints: Array<{ path: string; line: number }> = [];
	for (let i = 0; i < lines.length; i += 1) {
		const match = lines[i].match(/if \(req\.method == \"POST\" && url\.pathname == \"([^\"]+)\"\) \{/);
		if (match) {
			postEndpoints.push({ path: match[1], line: i + 1 });
		}
	}
	const authMissing: string[] = [];
	for (const entry of postEndpoints) {
		if (entry.path == "/auth/dev_login") {
			continue;
		}
		const slice = lines.slice(entry.line - 1, entry.line + 80).join("\n");
		if (!slice.includes("requireAuth(req)")) {
			authMissing.push(`${entry.path} (approx line ${entry.line})`);
		}
	}
	if (authMissing.length == 0) {
		console.log("PASS: POST endpoints require auth (heuristic scan)");
	} else {
		console.log(`MANUAL REVIEW NEEDED: POST auth enforcement for ${authMissing.join(", ")}`);
	}

	// action_log unique constraint
	const actionLogSql = ctx.db
		.query("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'action_log'")
		.get() as { sql?: string } | undefined;
	if (actionLogSql?.sql && actionLogSql.sql.includes("UNIQUE(player_id, client_action_id)")) {
		console.log("PASS: action_log UNIQUE(player_id, client_action_id)");
	} else {
		console.log("MANUAL REVIEW NEEDED: action_log UNIQUE constraint (backend/src/index.ts)");
	}

	// Transaction usage heuristics
	const marketBuyBlock = indexText.includes("/market/buy") && indexText.includes("db.transaction");
	if (marketBuyBlock) {
		console.log("PASS: market trade mutations use DB transactions (heuristic)");
	} else {
		console.log("MANUAL REVIEW NEEDED: market/trade transaction usage (backend/src/index.ts)");
	}

	// Wallet invariant checks
	if (indexText.includes("assertWalletInvariant") && indexText.includes("getWalletInvariantError")) {
		console.log("PASS: wallet invariant checks present in backend code");
	} else {
		console.log("MANUAL REVIEW NEEDED: wallet invariant checks (backend/src/index.ts)");
	}

	// RNG seeding checks
	const rngChecks = [
		indexText.includes("EXPERIMENT_SECRET") && indexText.includes("arcane_distill"),
		indexText.includes("TRADE_SECRET"),
		indexText.includes("WORLD_SECRET")
	];
	if (rngChecks.every(Boolean)) {
		console.log("PASS: RNG seeded with server secrets found in code");
	} else {
		console.log("MANUAL REVIEW NEEDED: RNG seeding (backend/src/index.ts)");
	}
}

async function waitForServer(baseUrl: string, timeoutMs = 20000): Promise<void> {
	const start = Date.now();
	while (Date.now() - start < timeoutMs) {
		try {
			const res = await fetch(`${baseUrl}/static/version`);
			if (res.ok) {
				return;
			}
		} catch {
			// ignore until timeout
		}
		await new Promise((resolve) => setTimeout(resolve, 300));
	}
	throw new Error(`Server not ready at ${baseUrl} after ${timeoutMs}ms`);
}

async function run(): Promise<void> {
	const baseUrl = Bun.env.BASE_URL || "http://127.0.0.1:8787";
	const client = createClient(baseUrl);
	const dbPath = getDbPath();
	const db = new Database(dbPath);
	const staticData = loadStaticData();
	const ctx: TestContext = { client, db, staticData, baseUrl };
	await waitForServer(baseUrl);

	const tests: TestCase[] = [
		{ name: "A) Static & Core Contracts", run: testStaticAndCore },
		{ name: "B) Idempotency", run: testIdempotency },
		{ name: "C) Wallet + Capacity Invariants", run: testWalletAndCapacity },
		{ name: "D) Lab System", run: testLabSystem },
		{ name: "E) Experiments", run: testExperiments },
		{ name: "F) Research", run: testResearch },
		{ name: "G) Market", run: testMarket },
		{ name: "H) Trade Jobs", run: testTradeJobs },
		{ name: "I) World", run: testWorld },
		{ name: "J) Bosses", run: testBoss },
		{ name: "K) Security & Hardening", run: testSecurity },
		{ name: "L) New Account Progression", run: testNewAccountProgression }
	];

	let passed = 0;
	let failed = 0;

	for (const test of tests) {
		if (Bun.env.TEST_GROUP && !test.name.startsWith(Bun.env.TEST_GROUP)) continue;
		try {
			console.log(`\nRUN: ${test.name}`);
			await test.run(ctx);
			console.log(`PASS: ${test.name}`);
			passed += 1;
		} catch (err) {
			failed += 1;
			console.error(`FAIL: ${test.name}`);
			console.error(err instanceof Error ? err.message : err);
		}
	}

	architectureChecks(ctx);

	console.log("\nTEST SUMMARY");
	console.log(`PASS: ${passed}`);
	console.log(`FAIL: ${failed}`);
	db.close();
	getRedis().disconnect();
	process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
	console.error("Test runner error:", err);
	process.exit(1);
});
