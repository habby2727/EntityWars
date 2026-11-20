export const PVE_VICTORY_XP = 20;
export const MAX_HOMUNCULUS_LEVEL = 10;

export type HomunculusProgress = { level: number; xp: number; owned: boolean; mutation_id?: string; mutation_changed_at?: number };

export function xpThreshold(level: number): number {
  if (!Number.isInteger(level) || level < 0 || level > MAX_HOMUNCULUS_LEVEL) throw new RangeError("Invalid homunculus level");
  if (level === 0) return 0;
  if (level === 1) return 100;
  if (level === 2) return 300;
  if (level === 3) return 550;
  return Math.round(800 * 1.25 ** (level - 1) - 700);
}

export function levelFromXp(xp: number): number {
  if (!Number.isSafeInteger(xp) || xp < 0) throw new RangeError("Invalid homunculus XP");
  let level = 0;
  while (level < MAX_HOMUNCULUS_LEVEL && xp >= xpThreshold(level + 1)) level++;
  return level;
}

export function owned(progress: HomunculusProgress | undefined): boolean {
  return progress?.owned === true;
}

export function grantXp<T extends HomunculusProgress>(progress: T, amount: number): T {
  if (!owned(progress)) throw new Error("Homunculus is not owned");
  if (!Number.isSafeInteger(amount) || amount < 0 || !Number.isSafeInteger(progress.xp) || progress.xp < 0 || !Number.isSafeInteger(progress.xp + amount)) throw new RangeError("Invalid homunculus XP");
  const xp = progress.xp + amount;
  return { ...progress, xp, level: levelFromXp(xp) };
}

export function normalizeHomunculusProgress(value: unknown, originals: Set<string>, expedition: Set<string>, mutations: Set<string>): Record<string, HomunculusProgress> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result: Record<string, HomunculusProgress> = {};
  for (const [id, raw] of Object.entries(value)) {
    if ((!originals.has(id) && !expedition.has(id)) || !raw || typeof raw !== "object" || Array.isArray(raw)) continue;
    const entry = raw as Record<string, unknown>;
    const oldLevel = typeof entry.level === "number" && Number.isInteger(entry.level) && entry.level >= 0 && entry.level <= 10 ? entry.level : 0;
    const validXp = typeof entry.xp === "number" && Number.isSafeInteger(entry.xp) && entry.xp >= 0;
    // Preserve levels earned before XP progression was introduced.
    const xp = Math.max(validXp ? entry.xp as number : 0, xpThreshold(oldLevel));
    const progress: HomunculusProgress = { level: levelFromXp(xp), xp, owned: originals.has(id) || entry.owned === true };
    if (typeof entry.mutation_id === "string" && mutations.has(entry.mutation_id)) {
      progress.mutation_id = entry.mutation_id;
      progress.mutation_changed_at = typeof entry.mutation_changed_at === "number" && Number.isSafeInteger(entry.mutation_changed_at) && entry.mutation_changed_at >= 0 ? entry.mutation_changed_at : 0;
    }
    result[id] = progress;
  }
  return result;
}
