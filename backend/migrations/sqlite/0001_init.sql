CREATE TABLE IF NOT EXISTS players (
	player_id TEXT PRIMARY KEY,
	display_name TEXT NOT NULL,
	state_json TEXT NOT NULL,
	updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS action_log (
	player_id TEXT NOT NULL,
	client_action_id TEXT NOT NULL,
	action_type TEXT NOT NULL,
	payload_json TEXT NOT NULL,
	result_state_json TEXT,
	created_at INTEGER NOT NULL,
	UNIQUE(player_id, client_action_id)
);

CREATE TABLE IF NOT EXISTS market_orders (
	order_id TEXT PRIMARY KEY,
	seller_id TEXT NOT NULL,
	type TEXT NOT NULL,
	resource_id TEXT NOT NULL,
	amount INTEGER NOT NULL,
	price_resource_id TEXT NOT NULL,
	price_amount INTEGER NOT NULL,
	fee_bps INTEGER NOT NULL,
	status TEXT NOT NULL,
	created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS market_fills (
	fill_id TEXT PRIMARY KEY,
	order_id TEXT NOT NULL,
	buyer_id TEXT NOT NULL,
	amount INTEGER NOT NULL,
	total_price INTEGER NOT NULL,
	fee INTEGER NOT NULL,
	created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS escrow (
	player_id TEXT NOT NULL,
	resource_id TEXT NOT NULL,
	amount INTEGER NOT NULL,
	PRIMARY KEY(player_id, resource_id)
);

CREATE TABLE IF NOT EXISTS trade_jobs (
	job_id TEXT PRIMARY KEY,
	provider_id TEXT NOT NULL,
	input_resource_id TEXT NOT NULL,
	input_amount INTEGER NOT NULL,
	output_resource_id TEXT NOT NULL,
	output_min INTEGER NOT NULL,
	output_max INTEGER NOT NULL,
	duration_sec INTEGER NOT NULL,
	commission_resource_id TEXT NOT NULL,
	commission_amount INTEGER NOT NULL,
	queue_limit INTEGER NOT NULL,
	status TEXT NOT NULL,
	created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS trade_job_runs (
	run_id TEXT PRIMARY KEY,
	job_id TEXT NOT NULL,
	customer_id TEXT NOT NULL,
	submitted_at INTEGER NOT NULL,
	completes_at INTEGER NOT NULL,
	input_locked INTEGER NOT NULL,
	status TEXT NOT NULL,
	output_amount INTEGER NOT NULL,
	rng_seed TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_wallet (
	audit_id TEXT PRIMARY KEY,
	player_id TEXT NOT NULL,
	delta_wallet TEXT NOT NULL,
	reason TEXT NOT NULL,
	related_id TEXT,
	created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS world (
	state_json TEXT NOT NULL,
	updated_at INTEGER NOT NULL
);
