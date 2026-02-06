import { claimJobs, describeJob, markJobDone, markJobFailed } from "./jobs/queue";
import { logError, logInfo, logWarn } from "./observability/logger";

const pollMs = Number(Bun.env.JOB_POLL_MS || 2000);
const maxAttempts = Number(Bun.env.JOB_MAX_ATTEMPTS || 5);
const baseBackoffMs = Number(Bun.env.JOB_BACKOFF_MS || 1000);
const batchSize = Number(Bun.env.JOB_BATCH_SIZE || 5);

async function handleJob(job: { id: string; type: string; payload: any; attempts: number }): Promise<void> {
	switch (job.type) {
		case "audit_snapshot": {
			logInfo("job audit_snapshot", { job_id: job.id, payload: job.payload });
			return;
		}
		case "recompute_cache": {
			logInfo("job recompute_cache", { job_id: job.id });
			return;
		}
		default:
			logWarn("unknown job type", { job_id: job.id, type: job.type });
			return;
	}
}

async function processLoop(): Promise<void> {
	for (;;) {
		try {
			const jobs = await claimJobs(batchSize);
			if (jobs.length == 0) {
				await new Promise((resolve) => setTimeout(resolve, pollMs));
				continue;
			}
			for (const job of jobs) {
				try {
					await handleJob(job);
					await markJobDone(job.id);
					logInfo("job done", { job: describeJob(job) });
				} catch (err) {
					const attempt = job.attempts ?? 0;
					const backoffMs = baseBackoffMs * Math.pow(2, attempt);
					const nextRun = new Date(Date.now() + backoffMs);
					await markJobFailed(job.id, attempt, maxAttempts, String(err), nextRun);
					logError("job failed", { job: describeJob(job), error: String(err) });
				}
			}
		} catch (err) {
			logError("job loop error", { error: String(err) });
			await new Promise((resolve) => setTimeout(resolve, pollMs));
		}
	}
}

logInfo("worker started", { poll_ms: pollMs, batch_size: batchSize });
void processLoop();
