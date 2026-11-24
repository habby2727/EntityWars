import {expect, test} from "bun:test";
import {Database} from "bun:sqlite";
import {existsSync, mkdtempSync, readdirSync, readFileSync, rmSync} from "node:fs";
import {tmpdir} from "node:os";
import {join, resolve} from "node:path";

test("authenticated logout revokes A and isolates B across restart and return to A", async () => {
  const godot=process.env.GODOT_BIN || join(process.env.USERPROFILE || "", "Desktop", "Godot_v4.6.exe");
  expect(existsSync(godot)).toBe(true);
  const dir=mkdtempSync(join(tmpdir(),"ew-logout-isolated-")), dbPath=join(dir,"test.sqlite");
  const db=new Database(dbPath);
  for(const name of readdirSync(resolve(import.meta.dir,"../../migrations/sqlite")).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
  db.close();
  const reserved=Bun.serve({port:0,hostname:"127.0.0.1",fetch:()=>new Response()}); const port=reserved.port; reserved.stop();
  const base=`http://127.0.0.1:${port}`;
  const env={...process.env,DB_PATH:dbPath,NODE_ENV:"test",BUN_ENV:"test",HOST:"127.0.0.1",PORT:String(port),DATABASE_URL:"postgres://x:x@127.0.0.1:1/test",REDIS_URL:"redis://127.0.0.1:1",AUTH_ACCOUNT_TIMEOUT_MS:"100",LOGIN_RATE_LIMIT_MAX:"100"};
  const server=Bun.spawn([process.execPath,"src/index.ts"],{cwd:resolve(import.meta.dir,"../.."),env,stdout:"ignore",stderr:"ignore"});
  try {
    let ready=false; for(let i=0;i<100;i++){try{if((await fetch(base+"/health")).ok){ready=true;break;}}catch{} await Bun.sleep(100);} expect(ready).toBe(true);
    const auth=async(path:string,username:string)=>{const r=await fetch(base+path,{method:"POST",headers:{"content-type":"application/json","X-EntityWars-Client-Build":"5509"},body:JSON.stringify({username,password:"secret1"})}); expect(r.status).toBe(200); return await r.json() as {token:string;player_id:string};};
    const a=await auth("/auth/register","isolated_a"), b=await auth("/auth/register","isolated_b"), aReturn=await auth("/auth/login","isolated_a");
    const state=(token:string)=>fetch(base+"/player/state",{headers:{authorization:`Bearer ${token}`,"X-EntityWars-Client-Build":"5509"}});
    expect((await state(a.token)).status).toBe(200); expect((await state(b.token)).status).toBe(200);
    const childEnv={...env,APPDATA:dir,LOCALAPPDATA:dir,ACCOUNT_TEST_ROOT:dir,ENTITYWARS_BACKEND_URL:base,ACCOUNT_A_ID:a.player_id,ACCOUNT_B_ID:b.player_id,ACCOUNT_A_TOKEN:a.token,ACCOUNT_B_TOKEN:b.token,ACCOUNT_A_RETURN_TOKEN:aReturn.token};
    const run=async(restart:boolean)=>{const child=Bun.spawn([godot,"--headless","--path",resolve(import.meta.dir,"../../.."),"--script","res://scripts/tests/test_authenticated_logout.gd"],{env:{...childEnv,ACCOUNT_RESTART:restart?"1":"0"},stdout:"pipe",stderr:"pipe"}); const code=await Promise.race([child.exited,Bun.sleep(30000).then(()=>{child.kill();throw Error("logout fixture timed out");})]); const output=await new Response(child.stdout).text()+await new Response(child.stderr).text(); expect({code,output}).toEqual({code:0,output:expect.stringContaining(restart?"AUTHENTICATED_LOGOUT_RESTART_PASS":"AUTHENTICATED_LOGOUT_PASS")});};
    await run(false);
    expect((await state(a.token)).status).toBe(401); expect((await state(b.token)).status).toBe(200);
    await run(true);
    expect((await state(aReturn.token)).status).toBe(200);
  } finally {server.kill(); await server.exited; rmSync(dir,{recursive:true,force:true,maxRetries:5,retryDelay:100});}
},90000);
