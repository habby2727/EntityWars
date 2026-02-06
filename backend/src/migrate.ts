import { Database } from "bun:sqlite";
import { readdirSync, readFileSync } from "fs";
import { resolve } from "path";
import { closePostgres, getPostgres } from "./db/postgres";
import { logInfo, logWarn } from "./observability/logger";

function getEnvNumber(name: string, fallback: number): number {
	const raw = Bun.env[name];
	const parsed = raw ? Number(raw) : NaN;
	return Number.isFinite(parsed) ? parsed : fallback;
}

function listMigrations(dir: string): string[] {
	const entries = readdirSync(dir)
		.filter((name) => name.endsWith(".sql"))
		.sort();
	return entries.map((name) => resolve(dir, name));
}

function extractId(path: string): string {
	const name = path.split(/[\\/]/).pop() || path;
	return name.replace(/\.sql$/i, "");
}

async function migrateSqlite(dbPath: string, dir: string): Promise<void> {
	const db = new Database(dbPath);
	db.exec("PRAGMA journal_mode = WAL;");
	db.exec(
		"CREATE TABLE IF NOT EXISTS schema_migrations (id TEXT PRIMARY KEY, applied_at INTEGER NOT NULL)"
	);
	const appliedRows = db.query("SELECT id FROM schema_migrations").all() as { id: string }[];
	const applied = new Set(appliedRows.map((row) => row.id));
	const files = listMigrations(dir);
	for (const file of files) {
		const id = extractId(file);
		if (applied.has(id)) {
			continue;
		}
		const sql = readFileSync(file, "utf8");
		db.transaction(() => {
			db.exec(sql);
			db.query("INSERT INTO schema_migrations (id, applied_at) VALUES (?, ?)").run(id, Date.now());
		})();
		logInfo("sqlite migration applied", { id });
	}
	logInfo("sqlite migrations complete", { count: files.length });
	db.close();
}

async function migratePostgres(dir: string): Promise<void> {
	const sql = getPostgres();
	await sql`
		CREATE TABLE IF NOT EXISTS schema_migrations (
			id text PRIMARY KEY,
			applied_at timestamptz NOT NULL DEFAULT now()
		);
	`;
	const appliedRows = await sql`SELECT id FROM schema_migrations`;
	const applied = new Set(appliedRows.map((row: any) => String(row.id)));
	const files = listMigrations(dir);
	for (const file of files) {
		const id = extractId(file);
		if (applied.has(id)) {
			continue;
		}
		const sqlText = readFileSync(file, "utf8");
		await sql.begin(async (tx) => {
			await tx.unsafe(sqlText);
			await tx`INSERT INTO schema_migrations (id) VALUES (${id})`;
		});
		logInfo("postgres migration applied", { id });
	}
	logInfo("postgres migrations complete", { count: files.length });
}

async function run(): Promise<void> {
	const dbPath = Bun.env.DB_PATH || "data/dev.sqlite";
	const sqliteDir = resolve(import.meta.dir, "..", "migrations", "sqlite");
	const postgresDir = resolve(import.meta.dir, "..", "migrations", "postgres");
	try {
		await migrateSqlite(dbPath, sqliteDir);
	} catch (err) {
		logWarn("sqlite migrations failed", { error: String(err) });
		throw err;
	}
	try {
		await migratePostgres(postgresDir);
	} catch (err) {
		logWarn("postgres migrations failed", { error: String(err) });
		throw err;
	}
	await closePostgres();
}

void run();
