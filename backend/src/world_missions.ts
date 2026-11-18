import type { Database } from "bun:sqlite";

export type Period = "daily" | "weekly";
type Mission = { id: string; title: string; description: string; target: number; reward: Record<string, number> };
export const DAILY: Mission[] = [
 {id:"daily_boss",title:"Boss Hunter",description:"Defeat 1 boss in Solo Hunt.",target:1,reward:{essence:100}},
 {id:"daily_damage",title:"Heavy Hitter",description:"Deal 500 HP of damage to bosses.",target:500,reward:{essence:100}},
 {id:"daily_elite",title:"Elite Slayer",description:"Defeat 1 Mythic, Rare, Epic or Legendary boss.",target:1,reward:{essence:100,core:1}},
];
export const WEEKLY: Mission[] = [
 {id:"weekly_boss",title:"Boss Hunter",description:"Defeat 5 bosses in Solo Hunt.",target:5,reward:{essence:300}},
 {id:"weekly_elite",title:"Elite Slayer",description:"Defeat 3 non-common bosses.",target:3,reward:{essence:250,core:2}},
 {id:"weekly_rare",title:"Rising Threat",description:"Defeat 1 Rare, Epic or Legendary boss.",target:1,reward:{essence:200,core:2}},
 {id:"weekly_guardians",title:"Guardian Breaker",description:"Defeat 5 guardians in Solo Hunt.",target:5,reward:{essence:300,core:1}},
 {id:"weekly_common",title:"Common Exterminator",description:"Defeat 4 different Common Boss appearances.",target:4,reward:{essence:250,core:1}},
 {id:"weekly_inspiration",title:"Inspired Warrior",description:"Choose an Inspiration spell in 3 different boss fights.",target:3,reward:{essence:200,core:2}},
];
const DAY = 86400000, WEEK = 7 * DAY, MONDAY_EPOCH = Date.UTC(1970,0,5);
export function period(now: number, type: Period) {
 const start = type === "daily" ? Math.floor(now / DAY) * DAY : Math.floor((now - MONDAY_EPOCH) / WEEK) * WEEK + MONDAY_EPOCH;
 return { key: new Date(start).toISOString().slice(0,10), next_reset_at: start + (type === "daily" ? DAY : WEEK), week: Math.floor((start-MONDAY_EPOCH)/WEEK) };
}
export function active(now: number, type: Period): Mission[] {
 if (type === "daily") return DAILY;
 const week = period(now, type).week;
 // Six distinct sets in a cycle; every mission appears three times.
 const start = ((week % 6) + 6) % 6;
 return [0,1,2].map(i => WEEKLY[(start+i)%6]);
}
type Row = { period_key: string; progress_json: string; claimed_json: string };
type Data = { progress: Record<string, any>; claimed: Record<string, boolean> };
let lastPrune = 0;
export function load(db: Database, player: string, type: Period, now: number): Data {
 if (now - lastPrune > 3600000) {
  db.query("DELETE FROM world_mission_progress WHERE (period_type = 'daily' AND period_key <> ?) OR (period_type = 'weekly' AND period_key <> ?)").run(period(now,"daily").key,period(now,"weekly").key);
  lastPrune = now;
 }
 const key = period(now,type).key;
 const row = db.query("SELECT period_key, progress_json, claimed_json FROM world_mission_progress WHERE player_id = ? AND period_type = ?").get(player,type) as Row | null;
 if (!row || row.period_key !== key) {
  db.query("INSERT INTO world_mission_progress (player_id,period_type,period_key,progress_json,claimed_json,updated_at) VALUES (?,?,?,'{}','{}',?) ON CONFLICT(player_id,period_type) DO UPDATE SET period_key=excluded.period_key,progress_json='{}',claimed_json='{}',updated_at=excluded.updated_at").run(player,type,key,now);
  return {progress:{},claimed:{}};
 }
 return {progress:JSON.parse(row.progress_json),claimed:JSON.parse(row.claimed_json)};
}
export function save(db: Database, player: string, type: Period, now: number, data: Data) {
 db.query("UPDATE world_mission_progress SET progress_json=?,claimed_json=?,updated_at=? WHERE player_id=? AND period_type=?").run(JSON.stringify(data.progress),JSON.stringify(data.claimed),now,player,type);
}
export function snapshot(db: Database, player: string, now: number) {
 const result: any = {server_time_unix_ms:now};
 for (const type of ["daily","weekly"] as const) {
  const p=period(now,type), d=load(db,player,type,now);
  result[type]={period_key:p.key,next_reset_at:p.next_reset_at,missions:active(now,type).map(m=>{const progress=Array.isArray(d.progress[m.id]) ? d.progress[m.id].length : (d.progress[m.id] ?? 0); return {...m,progress,completed:progress>=m.target,claimed:!!d.claimed[m.id]};})};
 }
 return result;
}
export function record(db: Database, player: string, now: number, event: {guardian:boolean; win?:boolean; tier?:string; zone?:string|null; appearance?:string; session?:string; choose?:boolean; damage?:number}) {
 const tier=(event.tier ?? "").toLowerCase();
 for (const type of ["daily","weekly"] as const) {
  const data=load(db,player,type,now), enabled=new Map(active(now,type).map(m=>[m.id,m]));
  const add=(id:string, n:number) => {const m=enabled.get(id); if(m && n>0) data.progress[id]=Math.min(m.target,(data.progress[id] ?? 0)+n);};
  const unique=(id:string,key:string,limit:number) => {if(!enabled.has(id)||!key)return; const a: string[]=data.progress[id] ?? []; if(a.length<limit&&!a.includes(key)) a.push(key); data.progress[id]=a;};
  if(event.guardian) { if(event.win) add("weekly_guardians",1); }
  else {
   add("daily_damage",event.damage ?? 0);
   if(event.win) {
    add("daily_boss",1); add("weekly_boss",1);
    if(["mythic","rare","epic","legendary"].includes(tier)){add("daily_elite",1);add("weekly_elite",1);}
    if(["rare","epic","legendary"].includes(tier)) add("weekly_rare",1);
    if(tier==="common" && event.zone && event.appearance) unique("weekly_common",JSON.stringify([event.zone,event.appearance]),4);
   }
   if(event.choose && event.session) unique("weekly_inspiration",event.session,3);
  }
  save(db,player,type,now,data);
 }
}

export function bossDamage(events: any[]): number {
 return events.reduce((sum, e) => sum + (e.actor === "player" && e.target === "boss" && Number.isSafeInteger(e.actual_damage) && e.actual_damage > 0 ? e.actual_damage : 0), 0);
}
