const baseUrl = Bun.env.BASE_URL || "http://127.0.0.1:8787";

async function request(path: string, options: RequestInit = {}) {
	const res = await fetch(`${baseUrl}${path}`, options);
	const text = await res.text();
	let data: any = null;
	try {
		data = text ? JSON.parse(text) : null;
	} catch {
		data = text;
	}
	if (!res.ok) {
		throw new Error(`HTTP ${res.status}: ${JSON.stringify(data)}`);
	}
	return data;
}

async function run() {
	const login = await request("/v1/auth/login", {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ name: "SmokeUser" })
	});
	const accessToken = login.access_token;
	const refreshToken = login.refresh_token;
	if (!accessToken || !refreshToken) {
		throw new Error("Missing access/refresh tokens");
	}

	const state = await request("/player/state", {
		headers: { Authorization: `Bearer ${accessToken}` }
	});
	if (!state.updated_player_state?.player_id) {
		throw new Error("Missing player state");
	}

	const refreshed = await request("/v1/auth/refresh", {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ refresh_token: refreshToken })
	});
	if (!refreshed.access_token || !refreshed.refresh_token) {
		throw new Error("Refresh failed");
	}

	await request("/v1/auth/logout", {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			Authorization: `Bearer ${refreshed.access_token}`
		},
		body: JSON.stringify({ refresh_token: refreshed.refresh_token })
	});

	console.log("SMOKE PASS");
}

run().catch((err) => {
	console.error("SMOKE FAIL", err);
	process.exit(1);
});
