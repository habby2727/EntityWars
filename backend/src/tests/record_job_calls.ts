import { mock } from "bun:test";
import { appendFileSync } from "node:fs";

mock.module("../jobs/queue", () => ({
  enqueueJob: async (type: string) => {
    appendFileSync(Bun.env.TEST_JOB_CALLS_PATH!, `${type}\n`);
    return null;
  },
  getJobQueueSize: async () => 0
}));
