import { createHash } from "node:crypto";

const ZONE_ART: Record<string, readonly string[]> = {
  zone_chaos: ["chaos_astral_alchemist", "chaos_astral_alchemist_variant", "chaos_astral_eagle", "chaos_cyber_warrior", "chaos_lion_warrior"],
  zone_corrupted: ["corrupted_cocodragon", "corrupted_cybermantis", "corrupted_doctor", "corrupted_hipovenom", "corrupted_medusa", "corrupted_sphinx"],
  zone_crystal: ["crystal_bear", "crystal_golem", "crystal_hydra", "crystal_mage", "crystal_sentinel", "crystal_wolf"],
};

export function commonAppearance(zoneId: unknown, appearanceId: unknown): { name: string; texture_id: string; appearance_id: string } | null {
  if (typeof zoneId !== "string" || typeof appearanceId !== "string" || !Object.hasOwn(ZONE_ART, zoneId) || !ZONE_ART[zoneId].includes(appearanceId)) return null;
  const name = appearanceId === "chaos_astral_alchemist_variant" ? "Astral Alchemist Ascendant" : appearanceId.slice(zoneId.length - 4).split("_").map(part => part.charAt(0).toUpperCase() + part.slice(1)).join(" ");
  return { appearance_id: appearanceId, name, texture_id: `res://assets/lab/bosses/${zoneId.slice(5)}_zone_common/${appearanceId}.png` };
}

export function commonAppearances(zoneId: string) {
  return Object.hasOwn(ZONE_ART, zoneId) ? ZONE_ART[zoneId].map(id => commonAppearance(zoneId, id)!) : null;
}

const GROUPS: Record<string, readonly string[]> = {
  hunt_common: [],
  hunt_mythic: ["common", "common"],
  hunt_rare: ["mythic", "common", "common"],
  hunt_epic: ["rare", "common", "common", "common"],
  hunt_legendary: ["epic", "common", "common", "common", "common"],
};

export type GuardianDefinition = {
  guardian_id: string;
  tier: string;
  name: string;
  template_id: string;
  texture_id: string;
};

export function guardiansFor(zoneId: string, parentId: string, bosses: readonly any[], _rotation = 0, seed?: number): GuardianDefinition[] | null {
  if (!Object.hasOwn(ZONE_ART, zoneId) || !Object.hasOwn(GROUPS, parentId) || !Array.isArray(bosses)) return null;
  const source = ZONE_ART[zoneId];
  const art = seed === undefined ? source : [...source].sort((a, b) => {
    const score = (id: string) => createHash("sha256").update(`${seed}:${zoneId}:${id}`).digest("hex");
    return score(a).localeCompare(score(b));
  });
  const offset = 0;
  const groups = GROUPS[parentId];
  const result: GuardianDefinition[] = [];
  let commonIndex = 0;
  for (let index = 0; index < groups.length; index++) {
    const tier = groups[index];
    const templateId = `hunt_${tier}`;
    const template = bosses.find(boss => boss?.id === templateId && boss?.tier === tier);
    if (!template || typeof template.name !== "string" || typeof template.texture_id !== "string") return null;
    const textureId = tier === "common"
      ? `res://assets/lab/bosses/${zoneId.slice(5)}_zone_common/${art[(offset + commonIndex++) % art.length]}.png`
      : template.texture_id;
    const artId = tier === "common" ? art[(offset + commonIndex - 1) % art.length] : "";
    const name = tier === "common" ? artId.replace(/^(chaos|corrupted|crystal)_/, "").split("_").map(part => part.charAt(0).toUpperCase() + part.slice(1)).join(" ") : `${template.name} Guardian ${index + 1}`;
    result.push({ guardian_id: `${zoneId}:${parentId}:${index}`, tier, name, template_id: templateId, texture_id: textureId });
  }
  return result;
}
