export default {
	env: "default",
	host: "0.0.0.0",
	port: 8787,
	apiVersion: "v1",
	dbPath: "data/dev.sqlite",
	maxBodyBytes: 256 * 1024,
	rateLimit: {
		windowMs: 60_000,
		maxPostsPerWindow: 60
	},
	tokenTtlMs: 24 * 60 * 60 * 1000
};
