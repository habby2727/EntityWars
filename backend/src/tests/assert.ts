export function fail(message: string): never {
	throw new Error(message);
}

export function assertTrue(condition: unknown, message: string): void {
	if (!condition) {
		fail(message);
	}
}

export function assertEqual<T>(actual: T, expected: T, message: string): void {
	if (!Object.is(actual, expected)) {
		fail(`${message} (expected=${String(expected)} actual=${String(actual)})`);
	}
}

export function assertApprox(
	actual: number,
	expected: number,
	tolerance: number,
	message: string
): void {
	if (!Number.isFinite(actual) || !Number.isFinite(expected)) {
		fail(`${message} (non-finite values)`);
	}
	if (Math.abs(actual - expected) > tolerance) {
		fail(`${message} (expected=${expected} +/- ${tolerance}, actual=${actual})`);
	}
}

export function assertNotNull<T>(value: T | null | undefined, message: string): T {
	if (value === null || value === undefined) {
		fail(message);
	}
	return value;
}
