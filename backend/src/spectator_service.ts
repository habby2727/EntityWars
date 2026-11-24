import type { Database } from 'bun:sqlite';
import { randomUUID } from 'node:crypto';
import { activePractice, otherCombat } from './practice_service';

export type ObservedCombat = { mode:string; id:string; encounter:string };
type Observation = { id:string; viewer:string; target:string; combat:ObservedCombat; expires:number };
type Options = {
  db:Database;
  online:(player:string)=>boolean;
  enabledAccount:(player:string)=>Promise<boolean>;
  locate:(target:string, now:number)=>ObservedCombat | null;
  project:(target:string, combat:ObservedCombat, after:number, now:number)=>{snapshot:unknown; events:unknown[]; closed:boolean; terminal?:boolean} | null;
  clock?:()=>number;
};

/** In-memory lease coordinator. Combat adapters must only read committed data and
 * return an allowlisted projection; they must never invoke participant services. */
export function createSpectatorService(options:Options) {
  const {db}=options, clock=options.clock ?? Date.now;
  const observations=new Map<string,Observation>(), byViewer=new Map<string,string>();
  const prune=()=>{const now=clock();for(const entry of observations.values())if(entry.expires<=now)drop(entry);};
  const drop=(entry:Observation)=>{if(observations.get(entry.id)!==entry)return;observations.delete(entry.id);if(byViewer.get(entry.viewer)===entry.id)byViewer.delete(entry.viewer);};
  const friend=(a:string,b:string)=>{const [low,high]=[a,b].sort();return !!db.query('SELECT 1 FROM friendships WHERE player_low=? AND player_high=?').get(low,high);};
  const protectedCombat=(player:string,now:number)=>activePractice(db,player,now)||otherCombat(db,player,now);
  const same=(a:ObservedCombat,b:ObservedCombat)=>a.mode===b.mode && a.id===b.id && a.encounter===b.encounter;
  const validId=(id:unknown):id is string=>typeof id==='string' && id.length>0 && id.length<=128 && !/[\u0000-\u001f\u007f-\u009f]/u.test(id);
  return {
    async start(viewer:string,target:string) {
      if (!validId(viewer)||!validId(target)||viewer===target) throw new Error('INVALID_TARGET');
      prune();
      if (!friend(viewer,target)||!options.online(target)) throw new Error('SPECTATOR_UNAVAILABLE');
      let allowed=false;try{allowed=await options.enabledAccount(target);}catch{}
      if (!allowed) throw new Error('SPECTATOR_UNAVAILABLE');
      // Recheck after the asynchronous account lookup before creating the lease.
      const now=clock();prune();
      if (!friend(viewer,target)||!options.online(target)||protectedCombat(viewer,now)) throw new Error('SPECTATOR_UNAVAILABLE');
      const combat=options.locate(target,now);if(!combat)throw new Error('SPECTATOR_UNAVAILABLE');
      const oldId=byViewer.get(viewer), old=oldId?observations.get(oldId):undefined;
      const viewers=[...observations.values()].filter(x=>same(x.combat,combat) && x.viewer!==viewer).length;
      if(viewers>=8 || (observations.size>=512 && !old))throw new Error('SPECTATOR_CAPACITY');
      if(old)drop(old);
      const entry={id:randomUUID(),viewer,target,combat,expires:now+30_000};observations.set(entry.id,entry);byViewer.set(viewer,entry.id);
      return {observation_id:entry.id,mode:combat.mode};
    },
    async state(viewer:string,id:string,after:number) {
      if(!validId(id)||!Number.isSafeInteger(after)||after<0)throw new Error('INVALID_REQUEST');
      prune();const entry=observations.get(id);if(!entry || entry.viewer!==viewer)throw new Error('OBSERVATION_NOT_FOUND');
      if(!friend(viewer,entry.target)||!options.online(entry.target)){drop(entry);throw new Error('OBSERVATION_CLOSED');}
      let allowed=false;try{allowed=await options.enabledAccount(entry.target);}catch{}
      if(!allowed) {drop(entry);throw new Error('OBSERVATION_CLOSED');}
      const now=clock();prune();
      if(observations.get(id)!==entry || !friend(viewer,entry.target) || !options.online(entry.target) || protectedCombat(viewer,now)){drop(entry);throw new Error('OBSERVATION_CLOSED');}
      const projection=db.transaction(()=>options.project(entry.target,entry.combat,after,now))();
      if(!projection){drop(entry);throw new Error('OBSERVATION_CLOSED');}
      const current=options.locate(entry.target,now);
      if(current && !same(current,entry.combat) && !projection.terminal){drop(entry);throw new Error('OBSERVATION_CLOSED');}
      entry.expires=now+30_000;
      if(projection.closed)drop(entry);
      return {observation_id:id,mode:entry.combat.mode,...projection};
    },
    leave(viewer:string,id:string){prune();const entry=observations.get(id);if(!entry || entry.viewer!==viewer)throw new Error('OBSERVATION_NOT_FOUND');drop(entry);return {ok:true};},
    endViewer(player:string){const id=byViewer.get(player);if(id){const entry=observations.get(id);if(entry)drop(entry);}},
    endForPlayer(player:string){const id=byViewer.get(player);if(id){const entry=observations.get(id);if(entry)drop(entry);}for(const entry of observations.values())if(entry.target===player)drop(entry);},
    namesForTarget(target:string){prune();const ids=[...observations.values()].filter(x=>x.target===target).map(x=>x.viewer);if(!ids.length)return [];return (db.query('SELECT p.display_name FROM players p WHERE p.player_id IN (SELECT value FROM json_each(?)) AND EXISTS (SELECT 1 FROM friendships f WHERE f.player_low=MIN(p.player_id,?) AND f.player_high=MAX(p.player_id,?)) ORDER BY p.display_name,p.player_id').all(JSON.stringify(ids),target,target) as {display_name:string}[]).map(x=>x.display_name);}
  };
}
