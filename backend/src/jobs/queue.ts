import { getPostgres } from "../db/postgres";
import { logError, logInfo, logWarn } from "../observability/logger";

export type JobStatus = "queued" | "running" | "done" | "failed";

export type JobRecord = {
	id: string;
	type: string;
	payload: unknown;
	run_at: Date;
	status: JobStatus;
	attempts: number;
	last_error: string | null;
	created_at: Date;
	updated_at: Date;
};

export async function enqueueJob(type: string, payload: unknown, runAt?: Date): Promise<string | null> {
	const sql = getPostgres();
	const id = crypto.randomUUID();
	const now = runAt ?? new Date();
	try {
		await sql`
			INSERT INTO jobs (id, type, payload, run_at, status, attempts)
			VALUES (${id}, ${type}, ${JSON.stringify(payload)}, ${now}, 'queued', 0)
		`;
		return id;
	} catch (err) {
		logWarn("job enqueue failed", { type, error: String(err) });
		return null;
	}
}

export async function claimJobs(limit: number): Promise<JobRecord[]> {
	const sql = getPostgres();
	try {
		return await sql.begin(async (tx) => {
			const rows = await tx<JobRecord[]>`
				SELECT id, type, payload, run_at, status, attempts, last_error, created_at, updated_at
				FROM jobs
				WHERE status = 'queued' AND run_at <= now()
				ORDER BY run_at ASC
				FOR UPDATE SKIP LOCKED
				LIMIT ${limit}
			`;
			if (rows.length > 0) {
				const ids = rows.map((row) => row.id);
				await tx`
					UPDATE jobs
					SET status = 'running', updated_at = now()
					WHERE id = ANY(${tx.array(ids)})
				`;
			}
			return rows;
		});
	} catch (err) {
		logWarn("job claim failed", { error: String(err) });
		return [];
	}
}

export async function markJobDone(id: string): Promise<void> {
	const sql = getPostgres();
	try {
		await sql`
			UPDATE jobs
			SET status = 'done', updated_at = now()
			WHERE id = ${id}
		`;
	} catch (err) {
		logError("job mark done failed", { id, error: String(err) });
	}
}

export async function markJobFailed(
	id: string,
	attempts: number,
	maxAttempts: number,
	error: string,
	nextRunAt?: Date
): Promise<void> {
	const sql = getPostgres();
	const status: JobStatus = attempts + 1 >= maxAttempts ? "failed" : "queued";
	const runAt = nextRunAt ?? new Date();
	try {
		await sql`
			UPDATE jobs
			SET status = ${status}, attempts = ${attempts + 1}, last_error = ${error}, run_at = ${runAt}, updated_at = now()
			WHERE id = ${id}
		`;
	} catch (err) {
		logError("job mark failed error", { id, error: String(err) });
	}
}

export async function getJobQueueSize(): Promise<number> {
	const sql = getPostgres();
	try {
		const rows = await sql`SELECT COUNT(*) as count FROM jobs WHERE status = 'queued'`;
		const row = rows[0] as { count?: number | string } | undefined;
		const raw = row?.count ?? 0;
		return typeof raw == "string" ? Number(raw) : Number(raw);
	} catch (err) {
		logWarn("job queue size failed", { error: String(err) });
		return 0;
	}
}

export function describeJob(job: JobRecord): string {
	return `${job.type}:${job.id}`;
}
