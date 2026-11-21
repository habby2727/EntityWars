// Targeted local integration smoke. GODOT_BIN must point to the Godot 4.6 executable.
import { Database } from "bun:sqlite";
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { createHmac } from "node:crypto";
import { expeditionDraw } from "../expeditions_rules";

const port = () => new Promise<number>(done => { const socket=createServer().listen(0,"127.0.0.1",()=>{const p=(socket.address() as {port:number}).port; socket.close(()=>done(p));}); });
const godot=process.env.GODOT_BIN, redisBin=Bun.which("redis-server");
if (!godot || !redisBin) throw Error("Set GODOT_BIN and install redis-server");
const dir=mkdtempSync(join(tmpdir(),"ew-godot-expedition-")), dbPath=join(dir,"test.sqlite"), db=new Database(dbPath);
for(const file of readdirSync(resolve(import.meta.dir,"../../migrations/sqlite")).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",file),"utf8"));
db.close();
const serverPort=await port(), redisPort=await port();
const redis=Bun.spawn([redisBin,"--port",String(redisPort),"--bind","127.0.0.1","--save","","--appendonly","no"],{cwd:dir,stdout:"ignore",stderr:"ignore"});
const env={...process.env,DB_PATH:dbPath,NODE_ENV:"development",BUN_ENV:"development",HOST:"127.0.0.1",PORT:String(serverPort),DATABASE_URL:"postgres://x:x@127.0.0.1:1/test",REDIS_URL:`redis://127.0.0.1:${redisPort}`,PG_CONNECT_TIMEOUT_SECONDS:"1",AUTH_ACCOUNT_TIMEOUT_MS:"10",DEBUG_BYPASS:"0",WORLD_SECRET:"dev_world_secret"};
const serverLog=join(dir,"server.log");
const server=Bun.spawn([process.execPath,"src/index.ts"],{cwd:resolve(import.meta.dir,"../.."),env,stdout:Bun.file(serverLog),stderr:Bun.file(serverLog)});
try {
  const url=`http://127.0.0.1:${serverPort}`;
  let ready=false;
  for(let i=0;i<100;i++){try{if((await fetch(url+"/health")).ok){ready=true;break;}}catch{} await Bun.sleep(100);}
  if (!ready) throw Error("Server not ready");
  const login=await fetch(url+"/auth/dev_login",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({name:"godot_e5d1_smoke"})});
  if (!login.ok) throw Error("Login failed");
  const account=await login.json() as any;
  const log=join(dir,"godot.log");
  const fixtureDb=new Database(dbPath);
  const requestPath=join(dir,"fixture-request.json"), donePath=join(dir,"fixture-done");
  const watcher=setInterval(()=>{
    if (!existsSync(requestPath)) return;
    try {
      const request=JSON.parse(readFileSync(requestPath,"utf8"));
      const row=fixtureDb.query("SELECT state_json,player_id FROM expedition_runs WHERE run_id=? AND status='ACTIVE'").get(request.run_id) as any;
      if (!row) throw Error("Missing test expedition");
      const state=JSON.parse(row.state_json), combat=state.combat;
      if (request.kind === "inspiration") {
        combat.player.inspiration=3; combat.player.inspiration_used=false; combat.player.inspiration_pending=false; combat.player.inspiration_offers=[];
        combat.player.hom_energy=3; combat.player.hp=combat.player.max_hp=500; combat.npc.hp=combat.npc.max_hp=500;
      } else if (request.kind === "loss") {
        combat.player.hp=1; combat.npc.hp=combat.npc.max_hp=5000; combat.npc.atk=10000; combat.npc.tempo=10000;
        const basic=combat.spells.find((s:any)=>combat.npc.spell_ids.includes(s.id) && s.category==="attack" && s.cooldown_turns===0);
		combat.npc.cooldowns=Object.fromEntries(combat.npc.spell_ids.map((id:string)=>[id,id === basic.id ? 0 : 4]));
      } else if (request.kind === "win") {
        combat.player.hp=combat.player.max_hp=500; combat.player.atk=10000; combat.player.tempo=10000;
        combat.npc.hp=1; combat.npc.def=1; state.selected.capturable=true;
        fixtureDb.query("UPDATE expedition_balances SET crystals=3 WHERE player_id=?").run(row.player_id);
      } else if (request.kind === "crystal") {
        const seed=createHmac("sha256",env.WORLD_SECRET).update("expedition:"+request.run_id).digest();
        while (expeditionDraw(seed,JSON.stringify(["crystal-drop",request.run_id,state.depth]),0) >= 0.5) state.depth++;
      } else throw Error("Unknown fixture");
      fixtureDb.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(state),request.run_id);
      unlinkSync(requestPath); writeFileSync(donePath,"done");
    } catch (error) { console.error(error); }
  },25);
  const script=process.env.EXPEDITION_GODOT_SCRIPT ?? "res://scripts/tests/smoke_expedition_api.gd";
  const child=Bun.spawn([godot,"--headless","--path",resolve(import.meta.dir,"../../.."),"--script",script,"--log-file",log],{env:{...process.env,APPDATA:dir,LOCALAPPDATA:dir,EXPEDITION_FIXTURE_DIR:dir,EXPEDITION_TEST_TOKEN:account.token,EXPEDITION_TEST_PLAYER:account.player_id,EXPEDITION_TEST_URL:url},stdout:"ignore",stderr:"ignore"});
  let timeout: ReturnType<typeof setTimeout>;
  const result=await Promise.race([child.exited,new Promise<number>(done => {timeout=setTimeout(()=>done(-1),65000);})]);
  clearTimeout(timeout!);
  clearInterval(watcher); fixtureDb.close();
  if (result === -1) { child.kill(); await child.exited; }
  const output=readFileSync(log,"utf8");
  if (result !== 0 || !output.includes("EXPEDITION_REAL_API_PASS") || output.includes("SCRIPT ERROR")) throw Error(output + "\nServer: " + readFileSync(serverLog,"utf8"));
  console.log("EXPEDITION_REAL_API_PASS", script);
  const captureOutcome=output.match(/E5D3 capture outcome: ([^\r\n]+)/);
  if (captureOutcome) console.log("Capture:",captureOutcome[1]);
} finally {
  server.kill(); redis.kill(); await Promise.all([server.exited,redis.exited]);
  for(let i=0;i<10;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch{await Bun.sleep(100);}}
}
