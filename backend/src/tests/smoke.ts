const baseUrl = Bun.env.BACKEND_URL || "http://127.0.0.1:8787";

function logPass(msg) {
  console.log(`PASS: ${msg}`);
}

function logFail(msg) {
  console.error(`FAIL: ${msg}`);
}

async function postJson(path, body, token) {
  const headers = { "Content-Type": "application/json" };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(`${baseUrl}${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body)
  });
  const data = await res.json().catch(() => ({}));
  return { res, data };
}

async function getJson(path, token) {
  const headers = {};
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(`${baseUrl}${path}`, { method: "GET", headers });
  const data = await res.json().catch(() => ({}));
  return { res, data };
}

async function run() {
  const name = `smoke_${Math.floor(Math.random() * 100000)}`;
  const login = await postJson("/auth/dev_login", { name });
  if (!login.data.ok || !login.data.token) {
    logFail("dev_login failed");
    return;
  }
  logPass("dev_login");
  const token = login.data.token;

  const stateResp = await getJson("/player/state", token);
  if (!stateResp.data.ok || !stateResp.data.updated_player_state) {
    logFail("fetch player state failed");
    return;
  }
  logPass("player state fetch");

  const actionId = crypto.randomUUID();
  const actionBody = {
    client_action_id: actionId,
    action_type: "SET_BUILDING_ROUTE",
    client_time_unix_ms: Date.now(),
    payload: { building_id: "lab_th", route: "Scientific" }
  };

  const first = await postJson("/player/action", actionBody, token);
  if (!first.data.ok || !first.data.updated_player_state) {
    logFail("action apply failed");
    return;
  }
  logPass("action apply");

  const second = await postJson("/player/action", actionBody, token);
  if (!second.data.ok || !second.data.updated_player_state) {
    logFail("idempotent action apply failed");
    return;
  }

  const firstWallet = first.data.updated_player_state.wallet || {};
  const secondWallet = second.data.updated_player_state.wallet || {};
  const walletSame = JSON.stringify(firstWallet) === JSON.stringify(secondWallet);
  if (walletSame) {
    logPass("idempotency does not double spend");
  } else {
    logFail("wallet changed between repeated actions");
  }
}

run().catch((err) => {
  console.error("Smoke test error:", err);
});
