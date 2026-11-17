import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

test("enabled ranked routes authenticate, pair and resolve private decisions", async () => {
 const port=await new Promise<number>(r=>{const s=createServer().listen(0,"127.0.0.1",()=>{const p=(s.address() as {port:number}).port;s.close(()=>r(p));});});
 const dir=mkdtempSync(join(tmpdir(),"ew-pvp-routes-")), db=new Database(join(dir,"test.sqlite")), migrations=resolve(import.meta.dir,"../../migrations/sqlite");
 for(const f of readdirSync(migrations).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations,f),"utf8"));
 const env={...process.env,DB_PATH:join(dir,"test.sqlite"),NODE_ENV:"development",BUN_ENV:"development",HOST:"127.0.0.1",PORT:String(port),DATABASE_URL:"postgres://x:x@127.0.0.1:1/test",REDIS_URL:"redis://127.0.0.1:1",PG_CONNECT_TIMEOUT_SECONDS:"1",DEBUG_BYPASS:"0",PVP_ENABLED:"1",PVP_RNG_SECRET:"test-secret-with-at-least-32-characters"};
 const spawn=()=>Bun.spawn([process.execPath,"src/index.ts"],{cwd:resolve(import.meta.dir,"../.."),env,stdout:"ignore",stderr:"ignore"});
 let server=spawn();
 const request=async(path: string, body?: unknown, token?: string)=>{const r=await fetch(`http://127.0.0.1:${port}${path}`,{method:body===undefined?"GET":"POST",headers:{"content-type":"application/json",...(token?{authorization:`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,data:await r.json() as any};};
 try {
  let ready=false; for(let i=0;i<120;i++){try{if((await request("/health")).status===200){ready=true;break;}}catch{} await Bun.sleep(100);} expect(ready).toBe(true);
  let a=(await request("/auth/dev_login",{name:"rank_a"})).data.token, b=(await request("/auth/dev_login",{name:"rank_b"})).data.token; const c=(await request("/auth/dev_login",{name:"rank_c"})).data.token;
  expect((await request("/pvp/leaderboard")).status).toBe(401);
  const spells=JSON.parse(readFileSync(resolve(import.meta.dir,"../../../data/spells.json"),"utf8")).spells.filter((s: any)=>s.type==="sulfur").map((s: any)=>s.id);
  const selection={entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:spells,mode:"attack"};
  const [x,y]=await Promise.all([request("/pvp/queue/join",{client_action_id:"join-a",selection},a),request("/pvp/queue/join",{client_action_id:"join-b",selection},b)]);
  expect([x.status,y.status]).toEqual([200,200]); const match=(await request("/pvp/queue/state",undefined,a)).data.match_id; expect(match).toBeTruthy();
  expect((await request(`/pvp/match/state?match_id=${match}`,undefined,c)).status).toBe(404);
  const one=await request("/pvp/match/decision",{match_id:match,client_action_id:"a1",combat_revision:1,decision:{turn:1,spell_id:spells[0]}},a);
  expect(one.status).toBe(200); expect(one.data.ready).toEqual({player:true,enemy:false});
  server.kill(); await server.exited; server=spawn();
  ready=false; for(let i=0;i<120;i++){try{if((await request("/health")).status===200){ready=true;break;}}catch{} await Bun.sleep(100);} expect(ready).toBe(true);
  a=(await request("/auth/dev_login",{name:"rank_a"})).data.token; b=(await request("/auth/dev_login",{name:"rank_b"})).data.token;
  const rival=(await request(`/pvp/match/state?match_id=${match}`,undefined,b)).data; expect(rival.ready.enemy).toBe(true); expect(JSON.stringify(rival)).not.toContain("inspiration_catalog"); expect(JSON.stringify(rival)).not.toContain("item_progress"); expect(JSON.stringify(rival)).not.toContain("test-secret");
  const two=await request("/pvp/match/decision",{match_id:match,client_action_id:"b1",combat_revision:1,decision:{turn:1,spell_id:spells[0]}},b);
  expect(two.status).toBe(200); expect(two.data.combat_revision).toBe(2); expect(two.data.turn).toBe(1);
  expect((await request("/pvp/leaderboard",undefined,a)).data.player.mp).toBe(1000);
  const finish=await request("/pvp/match/forfeit",{match_id:match,client_action_id:"b-forfeit"},b); expect(finish.status).toBe(200); expect(finish.data.result.result).toBe("loss");
  expect((await request("/pvp/leaderboard",undefined,a)).data.player.mp).toBe(1024);
 } finally {server.kill();await server.exited;db.close();rmSync(dir,{recursive:true,force:true,maxRetries:5,retryDelay:100});}
},120000);
