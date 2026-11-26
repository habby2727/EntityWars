import type {Potion} from './catalog';
import type {Team, Unit, Point} from './engine';

export const paralyzed = (u:Unit,tick:number) => (u.paralyzedUntil ?? 0) >= tick && (u.paralyzedUntil ?? 0) > 0;
export const poisoned = (u:Unit,tick:number) => (u.poisonUntil ?? 0) >= tick && (u.poisonUntil ?? 0) > 0;
export const empowered = (u:Unit,tick:number) => (u.aetherUntil ?? 0) >= tick && (u.aetherUntil ?? 0) > 0;

// The caller owns the cloned state; effects are applied only to targets present now.
export function castPotion(units:Unit[], team:Team, potion:Readonly<Potion>, point:Point, tick:number):void {
 for(const u of units){
  const friendly=potion.id==='blood_potion'||potion.id==='aether_potion';
  if(u.hp<=0 || (friendly ? u.team!==team : u.team===team) || (u.position.x-point.x)**2+(u.position.y-point.y)**2>potion.radius**2)continue;
  if(potion.id==='thunderlock' && (u.paralyzedUntil ?? 0)<=tick)u.paralyzedUntil=tick+potion.duration_ticks;
  if(potion.id==='vitriol_potion' && (u.poisonUntil ?? 0)<=tick){u.poisonUntil=tick+potion.duration_ticks;u.poisonNextTick=tick+10;u.poisonTeam=team;}
  if(potion.id==='blood_potion' && (u.bloodUntil ?? 0)<=tick){u.bloodUntil=tick+potion.duration_ticks;u.bloodNextTick=tick+10;}
  if(potion.id==='aether_potion' && (u.aetherUntil ?? 0)<=tick)u.aetherUntil=tick+potion.duration_ticks;
 }
}

// Damage is resolved once, before actions, so dead targets cannot act.
export function processPotionStatuses(units:Unit[], tick:number, maxHp:(u:Unit)=>number, emit:(event:any,u:Unit,died:boolean)=>void):void {
 for(const u of units){
  if(u.paralyzedUntil !== undefined && tick>u.paralyzedUntil)delete u.paralyzedUntil;
  if(u.poisonUntil !== undefined && tick>u.poisonUntil){delete u.poisonUntil;delete u.poisonNextTick;delete u.poisonTeam;}
  if(u.bloodUntil !== undefined && tick>u.bloodUntil){delete u.bloodUntil;delete u.bloodNextTick;}
  if(u.aetherUntil !== undefined && tick>u.aetherUntil)delete u.aetherUntil;
  if(u.hp<=0)continue;
  if(poisoned(u,tick) && u.poisonNextTick!==undefined && tick>=u.poisonNextTick){
   const damage=Math.min(u.hp,Math.max(1,Math.round(maxHp(u)*0.1)));u.hp-=damage;u.poisonNextTick+=10;
   const pos={...u.position};
   const event={type:'potion_damage',tick,team:u.poisonTeam ?? (u.team==='blue'?'red':'blue'),cardId:'vitriol_potion',target:u.id,position:pos,targetPosition:pos,damage,attackerKind:'potion',targetKind:'unit',victimCardId:u.cardId,victimAssetId:u.cardId,victimTeam:u.team,victimPosition:pos,victimKind:(u as any).kind ?? 'homunculus',victimElement:(u as any).element};
   emit(event,u,u.hp===0);
  }
  if(u.hp>0 && (u.bloodUntil??0)>=tick && (u.bloodUntil??0)>0 && u.bloodNextTick!==undefined && tick>=u.bloodNextTick){
   u.bloodNextTick+=10;const healing=Math.min(maxHp(u)-u.hp,Math.max(1,Math.round(maxHp(u)*0.1)));
   if(healing>0){u.hp+=healing;const pos={...u.position};emit({type:'potion_heal',tick,team:u.team,cardId:'blood_potion',target:u.id,position:pos,targetPosition:pos,healing,attackerKind:'potion',targetKind:'unit'},u,false);}
  }
 }
}

// Cooldowns remain compatible with old integer values. Fifths represent 60% exactly.
export function advanceUnitCooldown(u:Unit,slow:boolean):void {
 if(!slow && u.cooldownFraction===undefined){if(u.cooldown>0)u.cooldown--;return;}
 if(u.cooldown<=0){u.cooldown=0;delete u.cooldownFraction;return;}
 const remaining=Math.max(0,u.cooldown*5-(u.cooldownFraction ?? 0)-(slow?3:5));
 u.cooldown=Math.ceil(remaining/5);u.cooldownFraction=u.cooldown*5-remaining;
}
export function potionSnapshot(u:Unit,tick:number) {
 return {...((u.paralyzedUntil ?? 0)>tick?{paralyzed_until:u.paralyzedUntil}:{}),...((u.poisonUntil ?? 0)>tick?{poison_until:u.poisonUntil}:{}),...((u.bloodUntil ?? 0)>tick?{blood_until:u.bloodUntil}:{}),...((u.aetherUntil ?? 0)>tick?{aether_until:u.aetherUntil}:{})};
}
