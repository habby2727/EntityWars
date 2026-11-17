// Disabled by default. Enabled dispatch also requires the dedicated PvP RNG secret.
export function rankedAvailability(env: Record<string, string | undefined>): { status: number; data: { error: string } } {
  if (env.PVP_ENABLED !== "1") return { status: 503, data: { error: "PVP_DISABLED" } };
  return { status: 503, data: { error: "PVP_SECRET_REQUIRED" } };
}

export function isRankedRoute(method: string, path: string): boolean {
  return (method === "GET" && ["/pvp/queue/state", "/pvp/match/state", "/pvp/leaderboard"].includes(path)) ||
    (method === "POST" && ["/pvp/queue/join", "/pvp/queue/cancel", "/pvp/match/decision", "/pvp/match/forfeit", "/pvp/match/chat"].includes(path));
}
