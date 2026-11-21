import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";
import { active, bossDamage, period, record, snapshot } from "../world_missions";
const day = 86400000, monday = Date.UTC(2026, 0, 5);
function database() {
 const db = new Database(":memory:");
 db.exec("CREATE TABLE players(player_id TEXT PRIMARY KEY); INSERT INTO players VALUES ('p'),('inactive');");
 db.exec(readFileSync(new URL("../../migrations/sqlite/0014_world_missions.sql", import.meta.url),"utf8"));
 return db;
}
test("UTC daily and Monday boundaries and six week rotation", () => {
 expect(period(monday-1,"daily").next_reset_at).toBe(monday);
 expect(period(monday-1,"weekly").next_reset_at).toBe(monday);
 expect(period(monday,"weekly").key).toBe("2026-01-05");
 const sets = Array.from({length:6},(_,i)=>active(monday+i*7*day,"weekly").map(m=>m.id));
 expect(sets.every(s=>new Set(s).size===3)).toBe(true);
 expect(new Set(sets.flat()).size).toBe(6);
 expect(active(monday+42*day,"weekly").map(m=>m.id)).toEqual(sets[0]);
});
test("bounded progress, distinct encounters, persistence and rollover", () => {
 const db=database();
 const now=Array.from({length:6},(_,i)=>monday+i*7*day).find(t=>active(t,"weekly").some(m=>m.id==='weekly_common') && active(t,"weekly").some(m=>m.id==='weekly_inspiration'))!;
 record(db,"p",now,{guardian:true,win:true,tier:"rare",damage:500});
 let data=snapshot(db,"p",now);
 expect(data.daily.missions.map((m:any)=>m.progress)).toEqual([0,0,0]);
 for(let i=0;i<6;i++) record(db,"p",now,{guardian:false,win:true,tier:"common",zone:"z",appearance:String(i%5),damage:120});
 for(let i=0;i<7;i++) record(db,"p",now,{guardian:false,choose:true,session:String(i%4)});
 data=snapshot(db,"p",now);
 expect(data.daily.missions.map((m:any)=>m.progress)).toEqual([1,500,0]);
 expect(data.weekly.missions.find((m:any)=>m.id==='weekly_common').progress).toBe(4);
 expect(data.weekly.missions.find((m:any)=>m.id==='weekly_inspiration').progress).toBe(3);
 expect(snapshot(db,"p",now)).toEqual(data);
 expect((db.query("SELECT COUNT(*) AS n FROM world_mission_progress WHERE player_id='p'").get() as any).n).toBe(2);
 const next=snapshot(db,"p",now+7*day);
 expect(next.daily.missions.every((m:any)=>m.progress===0 && !m.claimed)).toBe(true);
 expect(next.weekly.missions.every((m:any)=>m.progress===0 && !m.claimed)).toBe(true);
 db.close();
});

test("authenticated claims are atomic, idempotent and survive server restart", async () => {
 const { mkdtempSync, readdirSync, rmSync } = await import("node:fs");
 const { tmpdir } = await import("node:os");
 const { join, resolve } = await import("node:path");
 const { createServer } = await import("node:net");
 const port = await new Promise<number>(r=>{const s=createServer().listen(0,"127.0.0.1",()=>{const p=(s.address() as any).port;s.close(()=>r(p));});});
 const dir=mkdtempSync(join(tmpdir(),"ew-missions-")), path=join(dir,"db.sqlite"), db=new Database(path);
 const migrations=resolve(import.meta.dir,"../../migrations/sqlite");
 for(const file of readdirSync(migrations).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations,file),"utf8"));
 const env={...process.env,DB_PATH:path,NODE_ENV:"development",BUN_ENV:"development",HOST:"127.0.0.1",PORT:String(port),DATABASE_URL:"postgres://x:x@127.0.0.1:1/test",REDIS_URL:"redis://127.0.0.1:1",PG_CONNECT_TIMEOUT_SECONDS:"1",DEBUG_BYPASS:"0",WORLD_SECRET:"missions-test-secret"};
 const spawn=()=>Bun.spawn([process.execPath,"src/index.ts"],{cwd:resolve(import.meta.dir,"../.."),env,stdout:"ignore",stderr:"ignore"});
 let server=spawn();
 const request=async (url:string,body?:any,token?:string)=>{const r=await fetch(`http://127.0.0.1:${port}${url}`,{method:body===undefined?"GET":"POST",headers:{"Content-Type":"application/json",...(token?{Authorization:`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,data:await r.json() as any};};
 const ready=async()=>{for(let i=0;i<100;i++){try {if((await request("/health")).status===200)return;} catch {} await Bun.sleep(100);} throw Error("server unavailable");};
 try {
  await ready();
  expect((await request("/world/missions")).status).toBe(401);
  const login=await request("/auth/dev_login",{name:"mission_claim_test"});
  expect(login.status).toBe(200);
  const token=login.data.token, id=login.data.player_id;
  const before=(await request("/world/missions",undefined,token)).data;
  expect(before.daily.missions).toHaveLength(3); expect(before.weekly.missions).toHaveLength(3);
  const claim={client_action_id:"claim-1",mission_id:"daily_boss",period_type:"daily",period_key:before.daily.period_key};
  expect((await request("/world/missions/claim",claim,token)).status).toBe(409);
  record(db,id,Date.now(),{guardian:false,win:true,tier:"common"});
  const wallet=()=>JSON.parse((db.query("SELECT state_json FROM players WHERE player_id=?").get(id) as any).state_json).wallet.essence;
  const row=db.query("SELECT state_json FROM players WHERE player_id=?").get(id) as any;
  const full=JSON.parse(row.state_json); full.wallet.essence=1312;
  db.query("UPDATE players SET state_json=? WHERE player_id=?").run(JSON.stringify(full),id);
  const rejected=await request("/world/missions/claim",claim,token);
  expect(rejected.status).toBe(409); expect(rejected.data.error).toContain("Storage full");
  expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id=?").get(id) as any).state_json)).toEqual(full);
  expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE player_id=? AND reason='WORLD_MISSION_CLAIM'").get(id) as any).n).toBe(0);
  expect((await request("/world/missions",undefined,token)).data.daily.missions.find((m:any)=>m.id==="daily_boss").claimed).toBe(false);
  expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id=? AND client_action_id=?").get(id,claim.client_action_id) as any).n).toBe(0);
  full.wallet.essence=1212; db.query("UPDATE players SET state_json=? WHERE player_id=?").run(JSON.stringify(full),id);
  const original=wallet();
  const results=await Promise.all([request("/world/missions/claim",claim,token),request("/world/missions/claim",claim,token)]);
  expect(results.map(r=>r.status)).toEqual([200,200]); expect(wallet()).toBe(original+100);
  expect((await request("/world/missions/claim",{...claim,client_action_id:"again"},token)).status).toBe(409);
  expect((await request("/world/missions/claim",{...claim,client_action_id:"old",period_key:"2000-01-01"},token)).status).toBe(409);
  server.kill(); await server.exited; server=spawn(); await ready();
  const relogin=await request("/auth/dev_login",{name:"mission_claim_test"}); expect(relogin.data.player_id).toBe(id);
  const after=await request("/world/missions",undefined,relogin.data.token);
  expect(after.data.daily.missions.find((m:any)=>m.id==="daily_boss").claimed).toBe(true);
  expect(wallet()).toBe(original+100);
  expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE player_id=? AND reason='WORLD_MISSION_CLAIM'").get(id) as any).n).toBe(1);
 } finally { server.kill(); await server.exited; db.close(); rmSync(dir,{recursive:true,force:true}); }
},30000);


test("damage uses actual HP lost from player events targeting the boss", () => {
 expect(bossDamage([
  {actor:"player",target:"boss",kind:"damage",damage:600,actual_damage:400},
  {actor:"player",target:"boss",kind:"true_damage",actual_damage:50},
  {actor:"player",target:"boss",kind:"corrosion",actual_damage:50},
  {actor:"player",target:"minion",actual_damage:300},
  {actor:"boss",target:"player",actual_damage:300},
  {actor:"player",target:"boss",actual_damage:0},
 ])).toBe(500);
});
test("rollover prunes inactive player mission records only", () => {
 const db=database(), now=Date.now()+7200000;
 record(db,"inactive",now,{guardian:false,win:true,tier:"rare"});
 snapshot(db,"p",now+8*day);
 expect((db.query("SELECT COUNT(*) AS n FROM world_mission_progress WHERE player_id='inactive'").get() as any).n).toBe(0);
 expect((db.query("SELECT COUNT(*) AS n FROM players WHERE player_id='inactive'").get() as any).n).toBe(1);
 db.close();
});

test("boss tiers and guardians advance only their matching objectives", () => {
 const db=database();
 const times=Array.from({length:6},(_,i)=>monday+i*7*day);
 const bossWeek=times.find(t=>["weekly_boss","weekly_elite","weekly_rare"].every(id=>active(t,"weekly").some(m=>m.id===id)))!;
 record(db,"p",bossWeek,{guardian:false,win:true,tier:"mythic"});
 let current=snapshot(db,"p",bossWeek);
 expect(current.daily.missions.find((m:any)=>m.id==="daily_elite").progress).toBe(1);
 expect(current.weekly.missions.map((m:any)=>m.progress)).toEqual([1,1,0]);
 record(db,"p",bossWeek,{guardian:false,win:true,tier:"rare"});
 current=snapshot(db,"p",bossWeek);
 expect(current.weekly.missions.map((m:any)=>m.progress)).toEqual([2,2,1]);
 const guardianWeek=times.find(t=>active(t,"weekly").some(m=>m.id==="weekly_guardians"))!;
 record(db,"inactive",guardianWeek,{guardian:true,win:true,tier:"legendary"});
 current=snapshot(db,"inactive",guardianWeek);
 expect(current.weekly.missions.find((m:any)=>m.id==="weekly_guardians").progress).toBe(1);
 expect(current.daily.missions.every((m:any)=>m.progress===0)).toBe(true);
 db.close();
});

test("common zone identity, repeated wins and guardian exclusions follow active objectives", () => {
 const db=database();
 const commonWeek=Array.from({length:6},(_,i)=>monday+i*7*day).find(t=>active(t,"weekly").some(m=>m.id==="weekly_common"))!;
 for (const [zone,appearance] of [["zone_chaos","a"],["zone_chaos","a"],["zone_crystal","a"],["zone_chaos","b"]]) record(db,"p",commonWeek,{guardian:false,win:true,tier:"common",zone,appearance});
 let current=snapshot(db,"p",commonWeek);
 expect(current.weekly.missions.find((m:any)=>m.id==="weekly_common").progress).toBe(3);
 record(db,"p",commonWeek,{guardian:true,win:true,tier:"common",zone:"zone_chaos",appearance:"c",damage:500,choose:true,session:"g"});
 current=snapshot(db,"p",commonWeek);
 expect(current.weekly.missions.find((m:any)=>m.id==="weekly_common").progress).toBe(3);
 expect(current.daily.missions.find((m:any)=>m.id==="daily_damage").progress).toBe(0);
 db.close();
});
