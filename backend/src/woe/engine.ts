import { arena, cards, cardById, cardCost, potions, potionById, elementalMultiplier, attackDamage, ATTACK_INTERVAL_MS } from "./catalog";
import {castPotion,processPotionStatuses,advanceUnitCooldown,paralyzed,poisoned,empowered,potionSnapshot} from './potions';

export type Team = "blue" | "red";
export type Lane = "left" | "right";
export type Mode = "1v1" | "2v2";
export interface Point { x: number; y: number }
export interface Controller { id: string; team: Team; zealTenths: number; zealRegenTicks?: number; slots: string[]; queue: string[]; actionIds: string[] }
export interface Laboratory { id: string; team: Team; lane: Lane; hp: number; maxHp: number; position: Point; defenseCooldown?: number }
export interface Unit { id: number; controllerId: string; team: Team; lane: Lane; cardId: string; hp: number; position: Point; route: Point[]; waypoint: number; targetLane: Lane; cooldown: number; cooldownFraction?:number; paralyzedUntil?:number; poisonUntil?:number; poisonNextTick?:number; poisonTeam?:Team; bloodUntil?:number; bloodNextTick?:number; aetherUntil?:number; formation?: boolean }
export type CombatEvent = { type: "attack" | "death" | "lab_attack" | "potion_cast" | "potion_damage" | "potion_heal"; attacker?: number; labId?: string; attackerKind?: "laboratory" | "potion"; target: number | string; damage?: number; healing?:number; radius?:number; tick: number; team: Team; cardId: string; position: Point; targetPosition: Point; victimCardId?: string | null; victimTeam?: Team; victimPosition?: Point; targetKind?: "unit" | "laboratory" };
export interface MatchState { mode: Mode; kind: "woe"; tick: number; controllers: Controller[]; laboratories: Laboratory[]; units: Unit[]; nextUnitId: number; events: CombatEvent[]; result: { winner: Team | null; reason: "laboratories" | "timeout" | "forfeit" | "abandoned" } | null }
export interface DeploymentCommand { actionId: string; controllerId: string; slot: number; cardId: string; lane?: Lane; target_x?:number; target_y?:number }
export type DeploymentResult = { accepted: true; state: MatchState } | { accepted: false; state: MatchState; reason: string };
const teams: Team[] = ["blue", "red"];
const lanes: Lane[] = ["left", "right"];
// WOE units move more slowly without changing the shared Core Defense catalog.
export const WOE_MOVEMENT_MULTIPLIER = 0.85;
export const ZEAL_REGEN_TICKS = 30;
// Legacy saves stored fractional zeal in tenths; retain it as progress.
export function zealProgress(p: Controller): number {
  if (p.zealTenths >= 100) return 0;
  return p.zealRegenTicks === undefined ? Math.min(29, Math.max(0, Math.round((p.zealTenths % 10) * 3))) : Math.min(29, Math.max(0, Math.floor(p.zealRegenTicks)));
}
export function regenerateZeal(p: Controller, allowed: boolean): void {
  let progress = zealProgress(p);
  p.zealTenths = Math.max(0, Math.min(100, Math.floor(p.zealTenths / 10) * 10));
  if (p.zealTenths >= 100) { p.zealRegenTicks = 0; return; }
  if (allowed && ++progress >= ZEAL_REGEN_TICKS) { p.zealTenths += 10; progress = 0; }
  p.zealRegenTicks = progress;
}
const enemy = (team: Team): Team => team === "blue" ? "red" : "blue";
const labId = (team: Team, lane: Lane) => `${team}:${lane}`;
const copy = <T>(value: T): T => structuredClone(value);
const dist2 = (a: Point, b: Point) => (a.x-b.x)**2 + (a.y-b.y)**2;
/** Stable nearest opposing living unit in attack range. */
export function nearestTarget<T extends { id:number; team:Team; hp:number; position:Point }>(unit:T, units:T[], range:number):T | undefined {
  return units.filter(other => other.team !== unit.team && other.hp > 0 && dist2(unit.position,other.position) <= range ** 2).sort((a,b) => dist2(unit.position,a.position)-dist2(unit.position,b.position) || a.id-b.id)[0];
}

// FNV-1a and xorshift32 provide a portable, deterministic per-controller shuffle.
function shuffle(seed: string): string[] {
  let n = 2166136261;
  for (let i=0; i<seed.length; i++) n = Math.imul(n ^ seed.charCodeAt(i), 16777619) >>> 0;
  if (!n) n = 0x9e3779b9;
  const deck = [...cards.map(c => c.id),...potions.map(p=>p.id)];
  for (let i=deck.length-1; i>0; i--) {
    n ^= n << 13; n ^= n >>> 17; n ^= n << 5; n >>>= 0;
    const j = n % (i+1); [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  const opening:string[]=[], waiting:string[]=[];
  for(const id of deck) {
    if(opening.length<4 && (!potionById[id] || !opening.some(c=>!!potionById[c])))opening.push(id);
    else waiting.push(id);
  }
  deck.splice(0,deck.length,...opening,...waiting);
  if (!deck.slice(0,4).some(id => cardById[id] && cardCost(cardById[id], 'woe') <= 3)) {
    const j = deck.findIndex(id => cardById[id] && cardCost(cardById[id], 'woe') <= 3); [deck[0], deck[j]] = [deck[j], deck[0]];
  }
  return deck;
}
/** Skip waiting potions while another remains visible; preserve queue order. */
export function replaceCard(player:Controller,slot:number):void {
 const held=player.slots.some((id,i)=>i!==slot && !!potionById[id]);
 let index=held?player.queue.findIndex(id=>!!cardById[id]):0;
 if(index<0)index=0;
 const consumed=player.slots[slot];player.slots[slot]=player.queue.splice(index,1)[0];player.queue.push(consumed);
}
/** Controller IDs are ordered blue first, then red. IDs must be unique. */
export function initializeMatch(mode: Mode, seed: string, controllerIds: string[]): MatchState {
  if ((mode !== "1v1" && mode !== "2v2") || typeof seed !== "string" || !Array.isArray(controllerIds) || controllerIds.length !== (mode === "1v1" ? 2 : 4) || controllerIds.some(id => typeof id !== "string" || !id || id.length > 128) || new Set(controllerIds).size !== controllerIds.length) throw new Error("INVALID_WOE_MATCH");
  const perTeam = controllerIds.length / 2;
  return { kind: "woe", mode, tick: 0, controllers: controllerIds.map((id,i) => { const deck = shuffle(`${seed.length}:${seed}:${id.length}:${id}`); return { id, team: i < perTeam ? "blue" : "red", zealTenths: 50, zealRegenTicks: 0, slots: deck.slice(0,4), queue: deck.slice(4), actionIds: [] }; }), laboratories: teams.flatMap(team => lanes.map(lane => ({ id: labId(team,lane), team, lane, hp: arena.laboratory_hp, maxHp: arena.laboratory_hp, position: copy(arena.laboratories[team][lane]) }))), units: [], nextUnitId: 1, events: [], result: null };
}
// Fixed, bounded slots avoid collision solving and preserve forward progress. The
// final waypoint stays within the shortest laboratory attack range (65).
export function formationPoint(point: Point, id: number, endpoint=false): Point {
  const order=[0,-1,1,-2,2], n=(id-1)%100, group=Math.floor(n/25), slot=n%25;
  return {x:point.x+order[slot%5]*(endpoint?10:12)+(endpoint?[0,1,-1,2][group]:[0,3,-3,6][group]), y:point.y+(endpoint?0:order[Math.floor(slot/5)]*8+[0,2,-2,4][group])};
}
export function route(team: Team, from: Lane, target: Lane, formationId?: number): Point[] {
  const points=[...copy(arena.approaches[team][from]), copy(arena.plaza), ...copy(arena.approaches[enemy(team)][target]).reverse(), copy(arena.spawns[enemy(team)][target])];
  return formationId === undefined ? points : points.map((p,i)=>formationPoint(p,formationId,i===points.length-1));
}
// Retreat along the already-traversed outgoing lane before switching at the plaza.
export function redirectRoute(unit: Unit, target: Lane): Point[] {
  let approach = [copy(arena.plaza), ...copy(arena.approaches[enemy(unit.team)][target]).reverse(), copy(arena.spawns[enemy(unit.team)][target])];
  if(unit.formation) approach=approach.map((p,i)=>formationPoint(p,unit.id,i===approach.length-1));
  const plazaIndex = arena.approaches[unit.team][unit.lane].length;
  if (unit.waypoint <= plazaIndex) return [...copy(unit.route.slice(unit.waypoint, plazaIndex + 1)), ...approach.slice(1)];
  const original = route(unit.team, unit.lane, unit.targetLane, unit.formation ? unit.id : undefined);
  const plaza = original[plazaIndex];
  if (dist2(unit.position, plaza) < 0.000001) return approach.slice(1);
  let segment=plazaIndex, best=Infinity;
  for(let i=plazaIndex;i<original.length-1;i++) {
    const a=original[i],b=original[i+1],dx=b.x-a.x,dy=b.y-a.y;
    const t=Math.max(0,Math.min(1,((unit.position.x-a.x)*dx+(unit.position.y-a.y)*dy)/(dx*dx+dy*dy)));
    const d=dist2(unit.position,{x:a.x+t*dx,y:a.y+t*dy});
    if(d<best){best=d;segment=i;}
  }
  return [...copy(original.slice(plazaIndex,segment+1).reverse()), ...approach.slice(1)];
}
/** Controllers can deploy from either surviving laboratory belonging to their team. */
export function allowedDeploymentLanes(state: MatchState, controllerId: string): Lane[] {
  const player = state.controllers.find(p => p.id === controllerId);
  if (!player) return [];
  return lanes.filter(lane => state.laboratories.some(l => l.team === player.team && l.lane === lane && l.hp > 0));
}
export function validateDeployment(state: MatchState, command: DeploymentCommand): string | null {
  if (state.result) return "MATCH_FINISHED";
  if (!command || typeof command.actionId !== "string" || !command.actionId.trim() || command.actionId.length > 128) return "INVALID_ACTION_ID";
  const player = state.controllers.find(p => p.id === command.controllerId);
  if (!player) return "INVALID_CONTROLLER";
  if (player.actionIds.includes(command.actionId)) return "DUPLICATE_ACTION_ID";
  if (!Number.isInteger(command.slot) || command.slot < 0 || ![3,4].includes(player.slots.length) || command.slot >= player.slots.length || player.slots[command.slot] !== command.cardId || (!cardById[command.cardId] && !potionById[command.cardId])) return "INVALID_CARD";
  const potion=potionById[command.cardId];
  if(potion){
    if(command.lane!==undefined || typeof command.target_x!=='number' || typeof command.target_y!=='number' || !Number.isFinite(command.target_x) || !Number.isFinite(command.target_y) || command.target_x<0 || command.target_x>arena.width || command.target_y<0 || command.target_y>arena.height)return 'INVALID_TARGET';
  } else {
    if(command.target_x!==undefined || command.target_y!==undefined || !command.lane || !lanes.includes(command.lane))return 'INVALID_LANE';
    if (!state.laboratories.find(l => l.team === player.team && l.lane === command.lane && l.hp > 0)) return "LANE_DESTROYED";
    if (state.units.length >= arena.unit_cap) return "UNIT_CAP";
  }
  if (player.zealTenths < (potion ? potion.cost : cardCost(cardById[command.cardId], state.kind)) * 10) return "INSUFFICIENT_ZEAL";
  return null;
}
export function applyDeployment(state: MatchState, command: DeploymentCommand): DeploymentResult {
  const reason = validateDeployment(state,command);
  if (reason) return { accepted: false, state, reason };
  const next = copy(state); const player = next.controllers.find(p => p.id === command.controllerId)!;
  if (player.zealTenths >= 100) player.zealRegenTicks = 0;
  const potion=potionById[command.cardId];
  player.zealTenths -= (potion ? potion.cost : cardCost(cardById[command.cardId], state.kind)) * 10;
  player.actionIds.push(command.actionId);
  replaceCard(player,command.slot);
  if(potion){
    const position={x:command.target_x!,y:command.target_y!};castPotion(next.units,player.team,potion,position,next.tick);
    next.events.push({type:'potion_cast',tick:next.tick,team:player.team,cardId:potion.id,target:0,position:copy(position),targetPosition:copy(position),radius:potion.radius});
    return {accepted:true,state:next};
  }
  let targetLane = command.lane!;
  if (!next.laboratories.find(l => l.team === enemy(player.team) && l.lane === targetLane && l.hp > 0)) targetLane = targetLane === "left" ? "right" : "left";
  const id=next.nextUnitId++;
  next.units.push({ id, controllerId: player.id, team: player.team, lane: command.lane!, cardId: command.cardId, hp: cardById[command.cardId].hp, position: formationPoint(arena.spawns[player.team][command.lane!],id), route: route(player.team,command.lane!,targetLane,id), waypoint: 0, targetLane, cooldown: 0, formation:true });
  return { accepted: true, state: next };
}
export function move(unit: Unit, amount: number) {
  while (amount > 0 && unit.waypoint < unit.route.length) {
    const point = unit.route[unit.waypoint]; const dx = point.x-unit.position.x, dy = point.y-unit.position.y; const d = Math.hypot(dx,dy);
    if (d <= amount) { unit.position = { ...point }; unit.waypoint++; amount -= d; }
    else { unit.position.x += dx / d * amount; unit.position.y += dy / d * amount; break; }
  }
}
function finish(state: MatchState, team: Team) { state.result = { winner: team, reason: "laboratories" }; }
/** Advance one 100 ms tick. Units act in ascending ID order; dead units cannot act. */
export function advanceTick(state: MatchState): MatchState {
  if (state.result) return state;
  const next = copy(state); next.events = []; next.tick++;
  for (const player of next.controllers) regenerateZeal(player, true);
  processPotionStatuses(next.units,next.tick,u=>cardById[u.cardId].hp,(event,_u,died)=>{next.events.push(event);if(died)next.events.push({...event,type:'death'});});
  for (const unit of next.units) {
    if (unit.hp <= 0 || next.result) continue;
    if(paralyzed(unit,next.tick))continue;
    const slow=poisoned(unit,next.tick);
    advanceUnitCooldown(unit,slow);
    const card = cardById[unit.cardId];
    let lab = next.laboratories.find(l => l.team === enemy(unit.team) && l.lane === unit.targetLane)!;
    if (lab.hp <= 0) {
      const targetLane = unit.targetLane === "left" ? "right" : "left";
      unit.route = redirectRoute(unit, targetLane); unit.waypoint = 0;
      unit.targetLane = targetLane;
      lab = next.laboratories.find(l => l.team === enemy(unit.team) && l.lane === unit.targetLane)!;
    }
    const target = nearestTarget(unit, next.units, card.range);
    if (target || (lab.hp > 0 && dist2(unit.position,lab.position) <= card.range ** 2)) {
      if (unit.cooldown === 0) {
        const baseDamage = target ? attackDamage(card.damage,cardById[target.cardId].defense,elementalMultiplier(card.element,cardById[target.cardId].element)) : attackDamage(card.damage,0);
        const damage = empowered(unit,next.tick) ? Math.round(baseDamage*1.2) : baseDamage;
        const victim = target ?? lab; const dealt = Math.min(victim.hp,damage); victim.hp -= dealt;
        next.events.push({ type: "attack", attacker: unit.id, target: victim.id, damage: dealt, tick: next.tick, team: unit.team, cardId: unit.cardId, position: copy(unit.position), targetPosition: copy(victim.position) });
        unit.cooldown = ATTACK_INTERVAL_MS / arena.tick_ms;
        delete unit.cooldownFraction;
        if (victim.hp === 0) {
          next.events.push({ type: "death", attacker: unit.id, target: victim.id, tick: next.tick, team: unit.team, cardId: unit.cardId, position: copy(unit.position), targetPosition: copy(victim.position), victimCardId: target?.cardId ?? null, victimTeam: victim.team, victimPosition: copy(victim.position), targetKind: target ? "unit" : "laboratory" });
          if (!target && next.laboratories.every(l => l.team !== lab.team || l.hp === 0)) finish(next,unit.team);
        }
      }
    } else move(unit,card.speed * WOE_MOVEMENT_MULTIPLIER * (slow?0.6:1) * (empowered(unit,next.tick)?1.15:1) * arena.tick_ms / 1000);
  }
  // Laboratories act after units, so a destroyed laboratory cannot fire and
  // an enemy entering range this tick is targeted without an extra delay.
  if (!next.result) for (const lab of next.laboratories) {
    if (lab.hp <= 0) continue;
    lab.defenseCooldown = Math.max(0, (lab.defenseCooldown ?? 0) - 1);
    if (lab.defenseCooldown > 0) continue;
    const target = next.units.filter(u => u.team !== lab.team && u.hp > 0 && dist2(u.position, lab.position) <= arena.laboratory_defense.range ** 2)
      .sort((a,b) => dist2(a.position,lab.position)-dist2(b.position,lab.position) || a.id-b.id)[0];
    if (!target) continue;
    const dealt = Math.min(target.hp, attackDamage(arena.laboratory_defense.damage, cardById[target.cardId].defense));
    target.hp -= dealt;
    lab.defenseCooldown = arena.laboratory_defense.interval_ms / arena.tick_ms;
    const event = { labId:lab.id, attackerKind:"laboratory" as const, target:target.id, tick:next.tick, team:lab.team, cardId:"", position:copy(lab.position), targetPosition:copy(target.position) };
    next.events.push({type:"lab_attack", ...event, damage:dealt});
    if (target.hp === 0) next.events.push({type:"death", ...event, targetKind:"unit", victimCardId:target.cardId, victimTeam:target.team, victimPosition:copy(target.position)});
  }
  next.units = next.units.filter(u => u.hp > 0);
  if (!next.result && next.tick >= arena.duration_ticks) {
    const score = (team: Team) => { const labs = next.laboratories.filter(l => l.team === team); return [labs.filter(l => l.hp > 0).length, labs.reduce((sum,l) => sum + l.hp / l.maxHp,0)]; };
    const a = score("blue"), b = score("red"); const cmp = a[0]-b[0] || a[1]-b[1];
    next.result = { winner: cmp > 0 ? "blue" : cmp < 0 ? "red" : null, reason: "timeout" };
  }
  return next;
}
/** Pass only an authenticated controller ID; omit it for a public/spectator view. */
export function getPublicSnapshot(state: MatchState, viewerId?: string) {
  return copy({ kind: state.kind, mode: state.mode, tick: state.tick, units: state.units.map(u => ({ id:u.id, controllerId:u.controllerId, team:u.team, lane:u.lane, cardId:u.cardId, hp:u.hp, maxHp:cardById[u.cardId].hp, x:Math.round(u.position.x * 100)/100, y:Math.round(u.position.y * 100)/100,...potionSnapshot(u,state.tick) })), laboratories: state.laboratories, players: state.controllers.map(p => ({ id:p.id, team:p.team, ...(viewerId === p.id ? { zeal:Math.floor(p.zealTenths / 10), zeal_regen_ticks:zealProgress(p), slots:p.slots, allowedDeploymentLanes:allowedDeploymentLanes(state,p.id) } : {}) })), events:state.events, result:state.result });
}
