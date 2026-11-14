const ZONE_ART: Record<string, readonly string[]> = {
  zone_chaos: ["chaos_astral_alchemist", "chaos_astral_alchemist_variant", "chaos_astral_eagle", "chaos_cyber_warrior", "chaos_lion_warrior"],
  zone_corrupted: ["corrupted_cocodragon", "corrupted_cybermantis", "corrupted_doctor", "corrupted_hipovenom", "corrupted_medusa", "corrupted_sphinx"],
  zone_crystal: ["crystal_bear", "crystal_golem", "crystal_hydra", "crystal_mage", "crystal_sentinel", "crystal_wolf"],
};

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

export function guardiansFor(zoneId: string, parentId: string, bosses: readonly any[]): GuardianDefinition[] | null {
  if (!Object.hasOwn(ZONE_ART, zoneId) || !Object.hasOwn(GROUPS, parentId) || !Array.isArray(bosses)) return null;
  const art = ZONE_ART[zoneId];
  const groups = GROUPS[parentId];
  const result: GuardianDefinition[] = [];
  let commonIndex = 0;
  for (let index = 0; index < groups.length; index++) {
    const tier = groups[index];
    const templateId = `hunt_${tier}`;
    const template = bosses.find(boss => boss?.id === templateId && boss?.tier === tier);
    if (!template || typeof template.name !== "string" || typeof template.texture_id !== "string") return null;
    const textureId = tier === "common"
      ? `res://assets/lab/bosses/${zoneId.slice(5)}_zone_common/${art[commonIndex++]}.png`
      : template.texture_id;
    result.push({ guardian_id: `${zoneId}:${parentId}:${index}`, tier, name: `${template.name} Guardian ${index + 1}`, template_id: templateId, texture_id: textureId });
  }
  return result;
}
