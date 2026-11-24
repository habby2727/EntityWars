import type { PvpSide } from "./combat";
import { publicCombatStatus, publicIncomingDrains } from "../public_combat_status";

export function sanitizePvpEvent(entry: any, viewer: PvpSide, seq: number) {
    const rel = (v: any) => v === viewer ? "player" : (v === "left" || v === "right") ? "enemy" : undefined;
    const out: any = { id: seq, kind: entry.kind, turn: entry.turn };
    for (const key of ["category","verb","suffix","spell_id","spell_name","show_spell_link","effectiveness","actor_kind","damage","actual_damage","amount","hp","status","value","previous","remaining","boosted","result"]) if (["string","number","boolean"].includes(typeof entry[key]) || entry[key] === null) out[key] = entry[key];
    if (entry.side) out.actor = rel(entry.side);
    if (entry.target_side) out.target = rel(entry.target_side);
    if (entry.kind === "poison") { out.source = rel(entry.source) ?? null; out.victim = rel(entry.victim); }
    if (entry.kind === "hom_passive") {
      out.actor = rel(entry.actor);
      out.target = rel(entry.target);
      for (const key of ["hom_id", "passive_id", "trigger"]) if (typeof entry[key] === "string") out[key] = entry[key];
      if (Array.isArray(entry.effects)) out.effects = entry.effects.filter((effect: any) => effect && ["left", "right"].includes(effect.target) && typeof effect.kind === "string" && typeof effect.amount === "number" && Number.isFinite(effect.amount)).map((effect: any) => ({kind: effect.kind, target: rel(effect.target), amount: effect.amount, unit: effect.unit, duration: effect.duration, remaining: effect.remaining}));
    }
    if (["left","right"].includes(entry.result)) out.result = rel(entry.result);
    return out;
}

export function projectPvpFighter(state: any, side: PvpSide, viewer: PvpSide, identity: {player_id:string; display_name:string}) {
      const f = state.fighters[side];
      const status: any = {}, statusView = publicCombatStatus(f, state.turn);
      for (const k of ["poison","stun","shield_pct","atk_boost","vuln_pct","atk_down","hom_stun","reflect_pct","tempo_bonus","focus_next","misalign_next","poison_on_reflect"]) if (typeof statusView.status[k] === "number") status[k] = statusView.status[k];
      if (f.status?.hybrid_mark) status.hybrid_mark = { owner: f.status.hybrid_mark.owner === viewer ? "player" : "enemy", remaining: f.status.hybrid_mark.remaining };
      const delayed_damage = (state.strategic_delayed ?? []).filter((entry: any) => entry.target === side).map((entry: any) => ({ amount: entry.amount, due_turn: entry.due_turn }));
      return { player_id: identity.player_id, display_name: identity.display_name, entity_id: f.id, name: f.name, type: f.type, hp: f.hp, max_hp: f.max_hp, atk: f.atk, def: f.def, status, defense_presentation: statusView.defense_presentation, persistent_statuses: statusView.persistent_statuses, passive_modifiers: statusView.passive_modifiers, pending_drain: publicIncomingDrains(state, side), spell_neutralize_active: f.spell_neutralize_active, spell_neutralize_pending: f.spell_neutralize_pending, delayed_damage, active_weapon_slot: f.active_weapon_slot, weapon_ids: f.weapons.map((weapon: any) => weapon?.id ?? null), hom_id: f.hom_id, hom_name: f.hom_name, hom_energy: f.hom_energy, hom_max_energy: f.hom_max_energy, hom_ready_at: f.hom_ready_at, hom_spent: f.hom_spent, ultra_used: f.ultra_used, inspiration: f.inspiration, inspiration_pending: !!f.inspiration_pending, inspiration_used_this_battle: !!f.inspiration_used_this_battle, ...(f.strategic_trap ? {trap: {value:f.strategic_trap.value, expires_turn:f.strategic_trap.expires_turn}} : {}), ...(f.strategic_heal_suppression ? {heal_suppression: {expires_turn:f.strategic_heal_suppression.expires_turn}} : {}), ...(side === viewer ? { spell_ids: [...f.spell_ids], spell_cooldowns: {...f.spell_cooldowns}, inspiration_offers: f.inspiration_pending ? [...f.inspiration_offers] : [] } : {}) };
}
