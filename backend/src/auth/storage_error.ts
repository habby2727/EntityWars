export class AuthStorageUnavailableError extends Error {
	constructor() {
		super("Authentication storage temporarily unavailable.");
	}
}
