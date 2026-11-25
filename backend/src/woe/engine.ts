import { arena, cards, cardById, elementalMultiplier, attackDamage, ATTACK_INTERVAL_MS } from "./catalog";

export type Team = "blue" | "red";
export type Lane = "left" | "right";
export type Mode = "1v1" | "2v2";
export interface Point { x: number; y: number }
export interface Controller { id: string; team: Team; zealTenths: number; slots: string[]; queue: string[]; actionIds: string[] }
export interface Laboratory { id: string; team: Team; lane: Lane; hp: number; maxHp: number; position: Point }
export interface Unit { id: number; controllerId: string; team: Team; lane: Lane; cardId: string; hp: number; position: Point; route: Point[]; waypoint: number; targetLane: Lane; cooldown: number }
export type CombatEvent = { type: "attack" | "death"; attacker?: number; target: number | string; damage?: number; tick: number; team: Team; cardId: string; position: Point; targetPosition: Point; victimCardId?: string | null; victimTeam?: Team; victimPosition?: Point; targetKind?: "unit" | "laboratory" };
export interface MatchState { mode: Mode; kind: "woe"; tick: number; controllers: Controller[]; laboratories: Laboratory[]; units: Unit[]; nextUnitId: number; events: CombatEvent[]; result: { winner: Team | null; reason: "laboratories" | "timeout" | "forfeit" | "abandoned" } | null }
export interface DeploymentCommand { actionId: string; controllerId: string; slot: number; cardId: string; lane: Lane }
export type DeploymentResult = { accepted: true; state: MatchState } | { accepted: false; state: MatchState; reason: string };
const teams: Team[] = ["blue", "red"];
const lanes: Lane[] = ["left", "right"];
const enemy = (team: Team): Team => team === "blue" ? "red" : "blue";
const labId = (team: Team, lane: Lane) => `${team}:${lane}`;
const copy = <T>(value: T): T => structuredClone(value);
const dist2 = (a: Point, b: Point) => (a.x-b.x)**2 + (a.y-b.y)**2;

// FNV-1a and xorshift32 provide a portable, deterministic per-controller shuffle.
function shuffle(seed: string): string[] {
  let n = 2166136261;
  for (let i=0; i<seed.length; i++) n = Math.imul(n ^ seed.charCodeAt(i), 16777619) >>> 0;
  if (!n) n = 0x9e3779b9;
  const deck = cards.map(c => c.id);
  for (let i=deck.length-1; i>0; i--) {
    n ^= n << 13; n ^= n >>> 17; n ^= n << 5; n >>>= 0;
    const j = n % (i+1); [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  if (!deck.slice(0,3).some(id => cardById[id].cost <= 3)) {
    const j = deck.findIndex(id => cardById[id].cost <= 3); [deck[0], deck[j]] = [deck[j], deck[0]];
  }
  return deck;
}
/** Controller IDs are ordered blue first, then red. IDs must be unique. */
export function initializeMatch(mode: Mode, seed: string, controllerIds: string[]): MatchState {
  if ((mode !== "1v1" && mode !== "2v2") || typeof seed !== "string" || !Array.isArray(controllerIds) || controllerIds.length !== (mode === "1v1" ? 2 : 4) || controllerIds.some(id => typeof id !== "string" || !id || id.length > 128) || new Set(controllerIds).size !== controllerIds.length) throw new Error("INVALID_WOE_MATCH");
  const perTeam = controllerIds.length / 2;
  return { kind: "woe", mode, tick: 0, controllers: controllerIds.map((id,i) => { const deck = shuffle(`${seed.length}:${seed}:${id.length}:${id}`); return { id, team: i < perTeam ? "blue" : "red", zealTenths: 50, slots: deck.slice(0,3), queue: deck.slice(3), actionIds: [] }; }), laboratories: teams.flatMap(team => lanes.map(lane => ({ id: labId(team,lane), team, lane, hp: arena.laboratory_hp, maxHp: arena.laboratory_hp, position: copy(arena.laboratories[team][lane]) }))), units: [], nextUnitId: 1, events: [], result: null };
}
function route(team: Team, from: Lane, target: Lane): Point[] {
  return [...copy(arena.approaches[team][from]), copy(arena.plaza), ...copy(arena.approaches[enemy(team)][target]).reverse(), copy(arena.spawns[enemy(team)][target])];
}
// Before the plaza, keep following the current approach. Beyond it, cross to the
// other approach at the same depth, then continue toward the surviving lab.
function redirectRoute(unit: Unit, target: Lane): Point[] {
  const approach = [copy(arena.plaza), ...copy(arena.approaches[enemy(unit.team)][target]).reverse(), copy(arena.spawns[enemy(unit.team)][target])];
  const plazaIndex = arena.approaches[unit.team][unit.lane].length;
  if (unit.waypoint <= plazaIndex) return [...copy(unit.route.slice(unit.waypoint, plazaIndex + 1)), ...approach.slice(1)];
  const y = unit.position.y;
  const direction = enemy(unit.team) === "red" ? -1 : 1;
  for (let i = 1; i < approach.length; i++) {
    const a = approach[i-1], b = approach[i];
    if ((y-a.y)*direction >= 0 && (b.y-y)*direction >= 0) {
      const t = (y-a.y)/(b.y-a.y);
      const crossing = { x: a.x+(b.x-a.x)*t, y };
      return [crossing, ...approach.slice(i)];
    }
  }
  return [copy(approach[approach.length-1])];
}
export function validateDeployment(state: MatchState, command: DeploymentCommand): string | null {
  if (state.result) return "MATCH_FINISHED";
  if (!command || typeof command.actionId !== "string" || !command.actionId.trim() || command.actionId.length > 128) return "INVALID_ACTION_ID";
  const player = state.controllers.find(p => p.id === command.controllerId);
  if (!player) return "INVALID_CONTROLLER";
  if (player.actionIds.includes(command.actionId)) return "DUPLICATE_ACTION_ID";
  if (!lanes.includes(command.lane)) return "INVALID_LANE";
  if (!Number.isInteger(command.slot) || command.slot < 0 || command.slot >= 3 || player.slots[command.slot] !== command.cardId || !cardById[command.cardId]) return "INVALID_CARD";
  if (!state.laboratories.find(l => l.team === player.team && l.lane === command.lane && l.hp > 0)) return "LANE_DESTROYED";
  if (player.zealTenths < cardById[command.cardId].cost * 10) return "INSUFFICIENT_ZEAL";
  if (state.units.length >= arena.unit_cap) return "UNIT_CAP";
  return null;
}
export function applyDeployment(state: MatchState, command: DeploymentCommand): DeploymentResult {
  const reason = validateDeployment(state,command);
  if (reason) return { accepted: false, state, reason };
  const next = copy(state); const player = next.controllers.find(p => p.id === command.controllerId)!;
  player.zealTenths -= cardById[command.cardId].cost * 10;
  player.actionIds.push(command.actionId);
  player.slots[command.slot] = player.queue.shift()!; player.queue.push(command.cardId);
  let targetLane = command.lane;
  if (!next.laboratories.find(l => l.team === enemy(player.team) && l.lane === targetLane && l.hp > 0)) targetLane = targetLane === "left" ? "right" : "left";
  next.units.push({ id: next.nextUnitId++, controllerId: player.id, team: player.team, lane: command.lane, cardId: command.cardId, hp: cardById[command.cardId].hp, position: copy(arena.spawns[player.team][command.lane]), route: route(player.team,command.lane,targetLane), waypoint: 0, targetLane, cooldown: 0 });
  return { accepted: true, state: next };
}
function move(unit: Unit, amount: number) {
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
  for (const player of next.controllers) player.zealTenths = Math.min(100, player.zealTenths + 1);
  for (const unit of next.units) {
    if (unit.hp <= 0 || next.result) continue;
    if (unit.cooldown > 0) unit.cooldown--;
    const card = cardById[unit.cardId];
    let lab = next.laboratories.find(l => l.team === enemy(unit.team) && l.lane === unit.targetLane)!;
    if (lab.hp <= 0) {
      unit.targetLane = unit.targetLane === "left" ? "right" : "left";
      lab = next.laboratories.find(l => l.team === enemy(unit.team) && l.lane === unit.targetLane)!;
      unit.route = redirectRoute(unit, unit.targetLane); unit.waypoint = 0;
    }
    const targets = next.units.filter(other => other.team !== unit.team && other.hp > 0 && dist2(unit.position,other.position) <= card.range ** 2).sort((a,b) => dist2(unit.position,a.position)-dist2(unit.position,b.position) || a.id-b.id);
    const target = targets[0];
    if (target || (lab.hp > 0 && dist2(unit.position,lab.position) <= card.range ** 2)) {
      if (unit.cooldown === 0) {
        const damage = target ? attackDamage(card.damage,cardById[target.cardId].defense,elementalMultiplier(card.element,cardById[target.cardId].element)) : attackDamage(card.damage,0);
        const victim = target ?? lab; const dealt = Math.min(victim.hp,damage); victim.hp -= dealt;
        next.events.push({ type: "attack", attacker: unit.id, target: victim.id, damage: dealt, tick: next.tick, team: unit.team, cardId: unit.cardId, position: copy(unit.position), targetPosition: copy(victim.position) });
        unit.cooldown = ATTACK_INTERVAL_MS / arena.tick_ms;
        if (victim.hp === 0) {
          next.events.push({ type: "death", attacker: unit.id, target: victim.id, tick: next.tick, team: unit.team, cardId: unit.cardId, position: copy(unit.position), targetPosition: copy(victim.position), victimCardId: target?.cardId ?? null, victimTeam: victim.team, victimPosition: copy(victim.position), targetKind: target ? "unit" : "laboratory" });
          if (!target && next.laboratories.every(l => l.team !== lab.team || l.hp === 0)) finish(next,unit.team);
        }
      }
    } else move(unit,card.speed * arena.tick_ms / 1000);
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
  return copy({ kind: state.kind, mode: state.mode, tick: state.tick, units: state.units.map(u => ({ id:u.id, controllerId:u.controllerId, team:u.team, lane:u.lane, cardId:u.cardId, hp:u.hp, maxHp:cardById[u.cardId].hp, x:Math.round(u.position.x * 100)/100, y:Math.round(u.position.y * 100)/100 })), laboratories: state.laboratories, players: state.controllers.map(p => ({ id:p.id, team:p.team, ...(viewerId === p.id ? { zeal:p.zealTenths / 10, slots:p.slots } : {}) })), events:state.events, result:state.result });
}
