import postgres, { type Sql } from "postgres";

const DEFAULT_DATABASE_URL = "postgres://postgres:postgres@127.0.0.1:5432/entity_wars";
const databaseUrl = Bun.env.DATABASE_URL || DEFAULT_DATABASE_URL;
export class AccountStatusUnavailableError extends Error {}

const poolSize = Number(Bun.env.PG_POOL_SIZE || 10);
const idleTimeoutSeconds = Number(Bun.env.PG_IDLE_TIMEOUT_SECONDS || 30);
const connectTimeoutSeconds = Number(Bun.env.PG_CONNECT_TIMEOUT_SECONDS || 10);
const maxLifetimeSeconds = Number(Bun.env.PG_MAX_LIFETIME_SECONDS || 0);

const sql = postgres(databaseUrl, {
	max: Number.isFinite(poolSize) && poolSize > 0 ? poolSize : 10,
	idle_timeout: Number.isFinite(idleTimeoutSeconds) && idleTimeoutSeconds > 0 ? idleTimeoutSeconds : 30,
	connect_timeout:
		Number.isFinite(connectTimeoutSeconds) && connectTimeoutSeconds > 0
			? connectTimeoutSeconds
			: 10,
	max_lifetime: Number.isFinite(maxLifetimeSeconds) && maxLifetimeSeconds > 0 ? maxLifetimeSeconds : undefined,
	prepare: true
});

export function getPostgres(): Sql {
	return sql;
}

export async function upsertUser(user: { id: string; email: string; displayName?: string | null }): Promise<void> {
	try {
		await sql`
			INSERT INTO users (id, email, display_name)
			VALUES (${user.id}, ${user.email}, ${user.displayName ?? null})
			ON CONFLICT (email)
			DO UPDATE SET display_name = EXCLUDED.display_name;
		`;
	} catch (err) {
		console.warn("[postgres] upsert user failed", err);
	}
}

export async function isUserDisabled(userId: string): Promise<boolean> {
	try {
		const rows = await sql`SELECT disabled FROM users WHERE id = ${userId}`;
		const row = rows[0] as { disabled?: boolean } | undefined;
		return row?.disabled === true;
	} catch (err) {
		console.warn("[postgres] user disabled check failed", err);
		if ([Bun.env.NODE_ENV, Bun.env.BUN_ENV].some((v) => ["production", "prod"].includes((v ?? "").toLowerCase()))) {
			throw new AccountStatusUnavailableError("Account status temporarily unavailable");
		}
		return false;
	}
}

export async function pingPostgres(): Promise<boolean> {
	try {
		await sql`SELECT 1`;
		return true;
	} catch {
		return false;
	}
}

export async function postgresExample(): Promise<void> {
	try {
		await sql`
			CREATE TABLE IF NOT EXISTS __example_kv (
				key text PRIMARY KEY,
				value text NOT NULL,
				updated_at timestamptz NOT NULL DEFAULT now()
			);
		`;
		await sql`
			INSERT INTO __example_kv (key, value)
			VALUES ('hello', 'world')
			ON CONFLICT (key)
			DO UPDATE SET value = excluded.value, updated_at = now();
		`;
		const rows = await sql`SELECT key, value FROM __example_kv WHERE key = 'hello'`;
		const first = rows[0] as { key?: string; value?: string } | undefined;
		console.log("[postgres] example row", first ?? null);
	} catch (err) {
		console.warn("[postgres] example skipped", err);
	}
}

export async function closePostgres(): Promise<void> {
	try {
		await sql.end({ timeout: 5 });
	} catch (err) {
		console.warn("[postgres] close failed", err);
	}
}
