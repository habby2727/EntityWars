export type LogLevel = "info" | "warn" | "error";

type LogFields = Record<string, unknown>;

function log(level: LogLevel, message: string, fields: LogFields = {}): void {
	const payload = {
		ts: new Date().toISOString(),
		level,
		msg: message,
		...fields
	};
	const line = JSON.stringify(payload);
	if (level == "error") {
		console.error(line);
	} else if (level == "warn") {
		console.warn(line);
	} else {
		console.log(line);
	}
}

export function logInfo(message: string, fields?: LogFields): void {
	log("info", message, fields);
}

export function logWarn(message: string, fields?: LogFields): void {
	log("warn", message, fields);
}

export function logError(message: string, fields?: LogFields): void {
	log("error", message, fields);
}
