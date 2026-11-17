// Ranked PvP must stay unavailable until the authoritative two-human BO3
// resolver and its parity suite have been completed and reviewed.
export function rankedAvailability(env: Record<string, string | undefined>): { status: number; data: { error: string } } {
  if (env.PVP_ENABLED !== "1") return { status: 503, data: { error: "PVP_DISABLED" } };
  return { status: 503, data: { error: "PVP_COMBAT_PARITY_UNAVAILABLE" } };
}

export function isRankedRoute(method: string, path: string): boolean {
  return (method === "GET" && ["/pvp/queue/state", "/pvp/match/state"].includes(path)) ||
    (method === "POST" && ["/pvp/queue/join", "/pvp/queue/cancel", "/pvp/match/decision", "/pvp/match/forfeit", "/pvp/match/chat"].includes(path));
}
