import { expeditionDraw } from "./expeditions_rules";

/** Keys are relative to res://assets/entities/expeditions/backgrounds/. */
export const EXPEDITION_BACKGROUNDS = Object.freeze([
  "Ashen_Monastery_12s_1080p_Godot.ogv",
  "Astral_Throne_15s_1080p_Godot.ogv",
  "Eclipsed_Ziggurat_15s_1080p_Godot.ogv",
  "Hollow_Carnival_12s_1080p_Godot.ogv",
  "Hollow_Necropolis_12s_1080p_Godot.ogv",
  "Ironroot_Forest_12s_1080p.ogv",
  "Leviathan_Ossuary_12s_1080p_Godot.ogv",
  "Mirror_Tribunal_12s_1080p_Godot.ogv",
  "Quicksilver_Docks_12s_1080p.ogv",
  "Salt_Cathedral_12s_1080p_Godot.ogv",
  "Sunken_Archive_15s_1080p_Godot.ogv",
  "The_Bismuth_Badlands_12s_Godot.ogv",
  "The_Blackwater_Baths_12s_Godot.ogv",
  "The_Celestial_Loom_12s_Godot.ogv",
  "The_Crimson_Pagoda_12s.ogv",
  "The_Forgotten_Menagerie_12s_Godot.ogv",
  "The_Frozen_Clocktower_12s_Godot.ogv",
  "The_Gilded_Apiary_12s_Godot.ogv",
  "The_Golden_Basilica_12s.ogv",
  "The_Lunar_Salt_Flats_12s_Godot.ogv",
  "The_Mycelial_Underworks_15s_Godot.ogv",
  "The_Neon_Reliquary_12s_Godot.ogv",
  "The_Obsidian_Rail_Terminus_12s_Godot.ogv",
  "The_Skyborne_Aether_Gardens_15s_Godot.ogv",
  "The_Transmutation_Foundry_12s_Godot.ogv",
  "Vitriol_Marshes_12s_1080p_Godot.ogv",
] as const);

if (EXPEDITION_BACKGROUNDS.length !== 26 || new Set(EXPEDITION_BACKGROUNDS).size !== 26 || EXPEDITION_BACKGROUNDS.some(key => !/^[A-Za-z0-9_]+\.ogv$/.test(key))) throw new Error("INVALID_EXPEDITION_BACKGROUNDS");

/** Stable shuffled permutation for a run and rotation cycle; persist the next index. */
export function expeditionBackgroundAt(seed: Uint8Array, runId: string, index: number): string {
  if (!runId || !Number.isSafeInteger(index) || index < 0) throw new Error("INVALID_EXPEDITION_BACKGROUND_INDEX");
  const cycle = Math.floor(index / EXPEDITION_BACKGROUNDS.length);
  const permutation: string[] = [...EXPEDITION_BACKGROUNDS];
  for (let i = permutation.length - 1; i > 0; i--) {
    const j = Math.floor(expeditionDraw(seed, JSON.stringify(["background", runId, cycle]), i) * (i + 1));
    [permutation[i], permutation[j]] = [permutation[j], permutation[i]];
  }
  return permutation[index % permutation.length];
}
