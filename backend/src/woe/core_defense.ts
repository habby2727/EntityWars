import enemyData from '../../../data/static/core_defense_enemies.json';
import waveRules from '../../../data/static/core_defense_waves.json';
import { arena, cardById, attackDamage, elementalMultiplier, ATTACK_INTERVAL_MS, type Element } from './catalog';
import { initializeMatch, applyDeployment, validateDeployment, route, redirectRoute, move, nearestTarget, type Unit, type MatchState, type Controller, type Laboratory, type Lane, type DeploymentCommand } from './engine';
import { chooseBotDeployment } from './bot_ai';

export type CoreDefenseMode = 'solo' | 'solo_bot' | 'coop';
type EnemyDefinition = { id:string; role:string; element:Element; hp:number; damage:number; defense:number; speed:number; range:number; unlock_wave:number };
export const coreDefenseEnemies: readonly Readonly<EnemyDefinition>[] = Object.freeze(enemyData.enemies.map(e => Object.freeze(e as EnemyDefinition)));
export const coreDefenseRules = Object.freeze(waveRules);
const enemyById: Readonly<Record<string, Readonly<EnemyDefinition>>> = Object.freeze(Object.fromEntries(coreDefenseEnemies.map(e => [e.id,e])));
if (coreDefenseEnemies.length !== 5 || new Set(coreDefenseEnemies.map(e=>e.id)).size !== 5 || coreDefenseEnemies.some(e => !e.role || !Number.isSafeInteger(e.unlock_wave) || e.unlock_wave < 1 || [e.hp,e.damage,e.speed,e.range].some(n=>!Number.isSafeInteger(n)||n<=0) || !Number.isSafeInteger(e.defense) || e.defense<0 || (()=>{try { elementalMultiplier(e.element,e.element); return false; } catch { return true; }})())) throw new Error('INVALID_CORE_DEFENSE_CATALOG');

export interface DefenseUnit extends Unit { kind:'homunculus'|'enemy'; maxHp:number; damage:number; defense:number; speed:number; range:number; element:Element }
type DefenseEvent = { type:'spawn'|'attack'|'death'; tick:number; team:'blue'|'red'; cardId:string; position:{x:number;y:number}; [key:string]:unknown };
export interface CoreDefenseState {
 kind:'core_defense'; mode:CoreDefenseMode; tick:number; controllers:Controller[]; laboratories:Laboratory[]; units:DefenseUnit[]; nextUnitId:number; events:DefenseEvent[];
 wave:number; completedWaves:number; enemiesSpawned:number; enemiesKilled:number; waveSpawned:number; pendingSpawns:number; phase:'wave'|'intermission'|'defeat'; intermissionTicks:number; spawnCooldown:number;
 result:{winner:'red';reason:'laboratories'}|null;
}
const clone = <T>(x:T):T => structuredClone(x);
const other = (lane:Lane):Lane => lane === 'left' ? 'right' : 'left';
const dist2 = (a:{x:number;y:number},b:{x:number;y:number}) => (a.x-b.x)**2+(a.y-b.y)**2;
const plus = (n:number) => Math.min(Number.MAX_SAFE_INTEGER,n+1);
// Wrap only at the safe integer limit, skipping IDs still in use.
function nextAvailableId(s:CoreDefenseState) {
 let id=s.nextUnitId > Number.MAX_SAFE_INTEGER ? 1 : s.nextUnitId;
 const used=new Set(s.units.map(u=>u.id)); while(used.has(id)) id=id===Number.MAX_SAFE_INTEGER?1:id+1;
 s.nextUnitId=id;
}
export function waveCount(wave:number):number { return Math.min(waveRules.max_count, waveRules.initial_count + Math.max(0,wave-1)*waveRules.count_per_wave); }
export function enemyStats(id:string,wave:number) {
 const e=enemyById[id]; if(!e || !Number.isSafeInteger(wave) || wave<1) throw new Error('INVALID_CORE_DEFENSE_ENEMY');
 return { ...e, hp:Math.min(waveRules.max_hp,Math.round(e.hp*(1+(wave-1)*waveRules.hp_growth_per_wave))), damage:Math.min(waveRules.max_damage,Math.round(e.damage*(1+(wave-1)*waveRules.damage_growth_per_wave))) };
}
export function initializeCoreDefense(mode:CoreDefenseMode,seed:string,controllerIds:string[]):CoreDefenseState {
 if (!['solo','solo_bot','coop'].includes(mode) || !Array.isArray(controllerIds) || controllerIds.length !== (mode==='solo'?1:2) || controllerIds.some(id=>typeof id!=='string'||!id||id.length>128) || new Set(controllerIds).size!==controllerIds.length || typeof seed!=='string') throw new Error('INVALID_CORE_DEFENSE_MATCH');
 // The WOE initializer supplies the exact controller shuffle and laboratory geometry.
 let dummy='__core_defense_red__'; while(controllerIds.includes(dummy)) dummy += '_';
 const base=initializeMatch('1v1',seed,[controllerIds[0],dummy]);
 if (controllerIds.length===2) { let dummy2=dummy+'_2'; while(controllerIds.includes(dummy2)) dummy2+='_'; base.controllers=initializeMatch('2v2',seed,[...controllerIds,dummy,dummy2]).controllers.slice(0,2); } else base.controllers=base.controllers.slice(0,1);
 return {kind:'core_defense',mode,tick:0,controllers:base.controllers,laboratories:base.laboratories,units:[],nextUnitId:1,events:[],wave:1,completedWaves:0,enemiesSpawned:0,enemiesKilled:0,waveSpawned:0,pendingSpawns:waveCount(1),phase:'wave',intermissionTicks:0,spawnCooldown:0,result:null};
}
const asWoe = (s:CoreDefenseState) => s as unknown as MatchState;
export function validateCoreDefenseDeployment(s:CoreDefenseState,c:DeploymentCommand):string|null {
 const reason=validateDeployment(asWoe(s),c); if(reason)return reason;
 if(s.units.filter(u=>u.team==='blue').length>=waveRules.allied_unit_cap)return 'UNIT_CAP';
 return null;
}
export function applyCoreDefenseDeployment(s:CoreDefenseState,c:DeploymentCommand): {accepted:true;state:CoreDefenseState}|{accepted:false;state:CoreDefenseState;reason:string} {
 const reason=validateCoreDefenseDeployment(s,c); if(reason)return {accepted:false,state:s,reason};
 const prepared=clone(s); nextAvailableId(prepared);
 const applied=applyDeployment(asWoe(prepared),c); if(!applied.accepted) return {accepted:false,state:s,reason:applied.reason};
 const next=applied.state as unknown as CoreDefenseState, u=next.units[next.units.length-1], card=cardById[u.cardId];
 const actions=next.controllers.find(p=>p.id===c.controllerId)!.actionIds; if(actions.length>waveRules.action_id_limit) actions.shift();
 Object.assign(u,{kind:'homunculus',maxHp:card.hp,damage:card.damage,defense:card.defense,speed:card.speed,range:card.range,element:card.element});
 next.events.push({type:'spawn',tick:next.tick,team:u.team,cardId:u.cardId,position:clone(u.position),unit_id:u.id,card_id:u.cardId,lane:u.lane,controller_id:u.controllerId,kind:u.kind,assetId:u.cardId});
 return {accepted:true,state:next};
}
function spawn(s:CoreDefenseState) {
 const eligible=coreDefenseEnemies.filter(e=>e.unlock_wave<=s.wave);
 const def=eligible[(s.waveSpawned+Math.floor((s.wave-1)/2))%eligible.length];
 const stats=enemyStats(def.id,s.wave), lane:Lane=(s.waveSpawned+(s.wave-1))%2===0?'left':'right';
 const target=s.laboratories.find(l=>l.team==='blue'&&l.lane===lane&&l.hp>0)?lane:other(lane);
 nextAvailableId(s);
 const u:DefenseUnit={id:s.nextUnitId++,controllerId:'',team:'red',lane,cardId:def.id,hp:stats.hp,maxHp:stats.hp,damage:stats.damage,defense:stats.defense,speed:stats.speed,range:stats.range,element:stats.element,kind:'enemy',position:clone(arena.spawns.red[lane]),route:route('red',lane,target),waypoint:0,targetLane:target,cooldown:0};
 s.units.push(u);s.waveSpawned++;s.enemiesSpawned=plus(s.enemiesSpawned);s.pendingSpawns--;s.spawnCooldown=waveRules.spawn_interval_ticks;
 s.events.push({type:'spawn',tick:s.tick,team:u.team,cardId:u.cardId,position:clone(u.position),unit_id:u.id,card_id:u.cardId,lane,kind:u.kind,assetId:u.cardId});
}
export function advanceCoreDefenseTick(state:CoreDefenseState):CoreDefenseState {
 if(state.result)return state;
 let s=clone(state);s.events=[];s.tick=plus(s.tick);
 for(const p of s.controllers)p.zealTenths=Math.min(100,p.zealTenths+1);
 if(s.mode==='solo_bot' && s.tick%10===0) {
  const cmd=chooseBotDeployment(asWoe(s),s.controllers[1].id,{validate:(st,c)=>validateCoreDefenseDeployment(st as unknown as CoreDefenseState,c),element:id=>enemyById[id]?.element ?? cardById[id].element});
  if(cmd) s=applyCoreDefenseDeployment(s,cmd).state;
 }
 if(s.phase==='intermission') {
  s.intermissionTicks--;
  if(s.intermissionTicks===0) {s.wave=plus(s.wave);s.waveSpawned=0;s.pendingSpawns=waveCount(s.wave);s.spawnCooldown=0;s.phase='wave';}
 } else if(s.pendingSpawns>0) {
  if(s.spawnCooldown>0)s.spawnCooldown--;
  if(s.spawnCooldown===0 && s.units.length<arena.unit_cap)spawn(s);
 }
 s.units.sort((a,b)=>a.id-b.id);
 for(const u of s.units) {
  if(u.hp<=0 || s.result)continue;
  if(u.cooldown>0)u.cooldown--;
  let lab:Laboratory|undefined;
  if(u.team==='red') {
   lab=s.laboratories.find(l=>l.team==='blue'&&l.lane===u.targetLane)!;
   if(lab.hp<=0) {u.targetLane=other(u.targetLane);lab=s.laboratories.find(l=>l.team==='blue'&&l.lane===u.targetLane)!;u.route=redirectRoute(u,u.targetLane);u.waypoint=0;}
  }
  const target=nearestTarget(u,s.units,u.range);
  const victim=target ?? (lab && lab.hp>0 && dist2(u.position,lab.position)<=u.range**2 ? lab : undefined);
  if(victim) {
   if(u.cooldown===0) {
    const damage=target?attackDamage(u.damage,target.defense,elementalMultiplier(u.element,target.element)):attackDamage(u.damage,0);
    const dealt=Math.min(victim.hp,damage);victim.hp-=dealt;u.cooldown=ATTACK_INTERVAL_MS/arena.tick_ms;
    s.events.push({type:'attack',attacker:u.id,target:victim.id,damage:dealt,tick:s.tick,team:u.team,cardId:u.cardId,position:clone(u.position),targetPosition:clone(victim.position)});
    if(victim.hp===0) {
     s.events.push({type:'death',attacker:u.id,target:victim.id,tick:s.tick,team:u.team,cardId:u.cardId,position:clone(u.position),targetPosition:clone(victim.position),victimCardId:target?.cardId??null,victimTeam:victim.team,victimPosition:clone(victim.position),targetKind:target?'unit':'laboratory'});
     if(target?.kind==='enemy')s.enemiesKilled=plus(s.enemiesKilled);
     if(!target && s.laboratories.filter(l=>l.team==='blue').every(l=>l.hp===0)){s.result={winner:'red',reason:'laboratories'};s.phase='defeat';}
    }
   }
  } else move(u,u.speed*arena.tick_ms/1000);
 }
 s.units=s.units.filter(u=>u.hp>0);
 if(!s.result && s.phase==='wave' && s.pendingSpawns===0 && !s.units.some(u=>u.kind==='enemy')) {s.completedWaves=s.wave;s.phase='intermission';s.intermissionTicks=waveRules.intermission_ticks;}
 return s;
}
export function getCoreDefenseSnapshot(s:CoreDefenseState,viewerId?:string) {
 return clone({kind:s.kind,mode:s.mode,tick:s.tick,wave:s.wave,completedWaves:s.completedWaves,enemiesSpawned:s.enemiesSpawned,enemiesKilled:s.enemiesKilled,pendingSpawns:s.pendingSpawns,phase:s.phase,intermissionTicks:s.intermissionTicks,remainingBlueLabHp:s.laboratories.filter(l=>l.team==='blue').reduce((n,l)=>n+l.hp,0),laboratories:s.laboratories,units:s.units.map(u=>({id:u.id,kind:u.kind,assetId:u.cardId,cardId:u.cardId,...(u.kind==='homunculus'?{controllerId:u.controllerId}:{}),team:u.team,lane:u.lane,hp:u.hp,maxHp:u.maxHp,element:u.element,x:Math.round(u.position.x*100)/100,y:Math.round(u.position.y*100)/100})),players:s.controllers.map(p=>({id:p.id,team:p.team,...(viewerId===p.id?{zeal:p.zealTenths/10,slots:p.slots}:{})})),events:s.events,result:s.result});
}
