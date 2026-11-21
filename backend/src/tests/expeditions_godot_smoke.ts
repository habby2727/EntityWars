// Targeted local integration smoke. GODOT_BIN must point to the Godot 4.6 executable.
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

const port = () => new Promise<number>(done => { const socket=createServer().listen(0,"127.0.0.1",()=>{const p=(socket.address() as {port:number}).port; socket.close(()=>done(p));}); });
const godot=process.env.GODOT_BIN, redisBin=Bun.which("redis-server");
if (!godot || !redisBin) throw Error("Set GODOT_BIN and install redis-server");
const dir=mkdtempSync(join(tmpdir(),"ew-godot-expedition-")), dbPath=join(dir,"test.sqlite"), db=new Database(dbPath);
for(const file of readdirSync(resolve(import.meta.dir,"../../migrations/sqlite")).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",file),"utf8"));
db.close();
const serverPort=await port(), redisPort=await port();
const redis=Bun.spawn([redisBin,"--port",String(redisPort),"--bind","127.0.0.1","--save","","--appendonly","no"],{cwd:dir,stdout:"ignore",stderr:"ignore"});
const env={...process.env,DB_PATH:dbPath,NODE_ENV:"development",BUN_ENV:"development",HOST:"127.0.0.1",PORT:String(serverPort),DATABASE_URL:"postgres://x:x@127.0.0.1:1/test",REDIS_URL:`redis://127.0.0.1:${redisPort}`,PG_CONNECT_TIMEOUT_SECONDS:"1",AUTH_ACCOUNT_TIMEOUT_MS:"10",DEBUG_BYPASS:"0",WORLD_SECRET:"dev_world_secret"};
const server=Bun.spawn([process.execPath,"src/index.ts"],{cwd:resolve(import.meta.dir,"../.."),env,stdout:"ignore",stderr:"ignore"});
try {
  const url=`http://127.0.0.1:${serverPort}`;
  let ready=false;
  for(let i=0;i<100;i++){try{if((await fetch(url+"/health")).ok){ready=true;break;}}catch{} await Bun.sleep(100);}
  if (!ready) throw Error("Server not ready");
  const login=await fetch(url+"/auth/dev_login",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({name:"godot_e5d1_smoke"})});
  if (!login.ok) throw Error("Login failed");
  const account=await login.json() as any;
  const log=join(dir,"godot.log");
  const child=Bun.spawn([godot,"--headless","--path",resolve(import.meta.dir,"../../.."),"--script","res://scripts/tests/smoke_expedition_api.gd","--log-file",log],{env:{...process.env,APPDATA:dir,LOCALAPPDATA:dir,EXPEDITION_TEST_TOKEN:account.token,EXPEDITION_TEST_PLAYER:account.player_id,EXPEDITION_TEST_URL:url},stdout:"ignore",stderr:"ignore"});
  let timeout: ReturnType<typeof setTimeout>;
  const result=await Promise.race([child.exited,new Promise<number>(done => {timeout=setTimeout(()=>done(-1),25000);})]);
  clearTimeout(timeout!);
  if (result === -1) { child.kill(); await child.exited; }
  const output=readFileSync(log,"utf8");
  if (result !== 0 || !output.includes("EXPEDITION_REAL_API_PASS") || output.includes("SCRIPT ERROR")) throw Error(output);
  console.log("EXPEDITION_REAL_API_PASS");
} finally {
  server.kill(); redis.kill(); await Promise.all([server.exited,redis.exited]);
  for(let i=0;i<10;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch{await Bun.sleep(100);}}
}
