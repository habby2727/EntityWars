import { expect, test } from "bun:test";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { createServer } from "node:net";
import { Database } from "bun:sqlite";
import { expeditionEnemyAt, expeditionHomunculusAt, maintainExpeditionReplays } from "../expeditions_service";
import { expeditionBackgroundAt, EXPEDITION_BACKGROUNDS } from "../expeditions_backgrounds";
import { expeditionEnemies, expeditionCaptures } from "../expeditions_rules";

const seed = new Uint8Array(32).fill(29);
test("homunculus shuffle bag rotates all species deterministically", () => {
  const draws = Array.from({length: 56}, (_, i) => expeditionHomunculusAt(seed, "run", i));
  for (let i = 0; i < 4; i++) expect(new Set(draws.slice(i * 14, (i + 1) * 14))).toEqual(new Set(expeditionCaptures.map(h => h.id)));
  for (let i = 1; i < draws.length; i++) expect(draws[i]).not.toBe(draws[i - 1]);
  expect(Array.from({length: 56}, (_, i) => expeditionHomunculusAt(seed, "run", i))).toEqual(draws);
  expect(() => expeditionHomunculusAt(seed, "run", -1)).toThrow();
});
test("shuffle bags exhaust every enemy and background and avoid boundary repeats", () => {
  const enemies = Array.from({length:84},(_,i)=>expeditionEnemyAt(seed,"run",i));
  const backgrounds = Array.from({length:78},(_,i)=>expeditionBackgroundAt(seed,"run",i));
  for(let i=0;i<4;i++) expect(new Set(enemies.slice(i*21,(i+1)*21))).toEqual(new Set(expeditionEnemies.map(e=>e.id)));
  for(let i=1;i<enemies.length;i++) expect(enemies[i]).not.toBe(enemies[i-1]);
  for(let i=0;i<3;i++) expect(new Set(backgrounds.slice(i*26,(i+1)*26))).toEqual(new Set(EXPEDITION_BACKGROUNDS));
  for(let i=1;i<backgrounds.length;i++) expect(backgrounds[i]).not.toBe(backgrounds[i-1]);
  expect(Array.from({length:21},(_,i)=>expeditionEnemyAt(seed,"another-run",i))).not.toEqual(enemies.slice(0,21));
  expect(Array.from({length:26},(_,i)=>expeditionBackgroundAt(seed,"another-run",i))).not.toEqual(backgrounds.slice(0,26));
});

test("authenticated persistent expedition battles, rewards, routing, loss and exit", async () => {
  const port = await new Promise<number>(done => { const socket=createServer().listen(0,"127.0.0.1",()=>{ const p=(socket.address() as {port:number}).port; socket.close(()=>done(p)); }); });
  const dir=mkdtempSync(join(tmpdir(),"entitywars-expedition-")), dbPath=join(dir,"test.sqlite"), db=new Database(dbPath);
  for(const file of readdirSync(resolve(import.meta.dir,"../../migrations/sqlite")).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",file),"utf8"));
  const redisPort=await new Promise<number>(done => { const socket=createServer().listen(0,"127.0.0.1",()=>{ const p=(socket.address() as {port:number}).port; socket.close(()=>done(p)); }); });
  const redis=Bun.spawn([Bun.which("redis-server")!,"--port",String(redisPort),"--bind","127.0.0.1","--save","","--appendonly","no"],{cwd:dir,stdout:"ignore",stderr:"ignore"});
  const env={...process.env,DB_PATH:dbPath,NODE_ENV:"development",BUN_ENV:"development",HOST:"127.0.0.1",PORT:String(port),DATABASE_URL:"postgres://x:x@127.0.0.1:1/test",REDIS_URL:`redis://127.0.0.1:${redisPort}`,PG_CONNECT_TIMEOUT_SECONDS:"1",AUTH_ACCOUNT_TIMEOUT_MS:"10",DEBUG_BYPASS:"0",WORLD_SECRET:"dev_world_secret",EXPENSIVE_RATE_LIMIT_MAX:"2000",LOGIN_RATE_LIMIT_MAX:"100"};
  const spawn=()=>Bun.spawn([process.execPath,"src/index.ts"],{cwd:resolve(import.meta.dir,"../.."),env,stdout:"ignore",stderr:"ignore"});
  let server=spawn(), serial=0;
  const leaseByName = new Map<string,string>(), nameByToken = new Map<string,string>(), runByName = new Map<string,string>();
  const request=async(path:string,body?:any,token?:string)=>{
    const name=token ? nameByToken.get(token) : undefined, lease=name ? leaseByName.get(name) : undefined;
    const run=name ? runByName.get(name) : undefined;
    if (lease && run && path.startsWith("/expeditions/") && !["/expeditions/heartbeat","/expeditions/exit","/expeditions/state","/expeditions/start"].includes(path)) {
      await fetch(`http://127.0.0.1:${port}/expeditions/heartbeat`,{method:"POST",headers:{"content-type":"application/json",authorization:`Bearer ${token}`,"x-expedition-lease":lease},body:JSON.stringify({run_id:run})});
    }
    const r=await fetch(`http://127.0.0.1:${port}${path}`,{method:body===undefined?"GET":"POST",headers:{"content-type":"application/json",...(token?{authorization:`Bearer ${token}`}:{ }),...(lease?{"x-expedition-lease":lease}:{})},body:body===undefined?undefined:JSON.stringify(body)});
    const data=await r.json() as any;
    if(path==="/auth/dev_login" && data.token) nameByToken.set(data.token,body.name);
    if(path==="/expeditions/start" && r.status===200 && name && data.lease) { leaseByName.set(name,data.lease); runByName.set(name,data.session.run_id); }
    return {status:r.status,data};
  };
  const ready=async()=>{for(let i=0;i<100;i++){try{if((await request("/health")).status===200)return;}catch{} await Bun.sleep(100);}throw Error("Server not ready");};
  const id=()=>`e5b-${serial++}`;
  const loadout={entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:"cinder",spell_ids:["cinder_fist","furnace_rush","ash_temper","brimstone_crash"],mode:"attack"};
  try {
    await ready();
    let a=(await request("/auth/dev_login",{name:"expedition_test_a"})).data;
    let b=(await request("/auth/dev_login",{name:"expedition_test_b"})).data;
    expect((await request("/expeditions/state")).status).toBe(401);
    const disconnected=(await request("/auth/dev_login",{name:"expedition_disconnected"})).data;
    const disconnectedStart=await request("/expeditions/start",{...loadout,client_action_id:id()},disconnected.token);
    expect(disconnectedStart.status).toBe(200);
    const disconnectedRun=disconnectedStart.data.session.run_id;
    expect((await request("/expeditions/heartbeat",{run_id:disconnectedRun},disconnected.token)).status).toBe(200);
    db.query("UPDATE expedition_runs SET heartbeat_at=? WHERE run_id=?").run(Date.now()-15000,disconnectedRun);
    expect((await request("/expeditions/heartbeat",{run_id:disconnectedRun},disconnected.token)).status).toBe(409);
    expect((await request("/expeditions/state",undefined,disconnected.token)).data).toMatchObject({session:null,mana:5});
    expect((db.query("SELECT status FROM expedition_runs WHERE run_id=?").get(disconnectedRun) as any).status).toBe("ABANDONED");
    const restarted=(await request("/auth/dev_login",{name:"expedition_restarted"})).data;
    const restartStart=await request("/expeditions/start",{...loadout,client_action_id:id()},restarted.token);
    expect(restartStart.status).toBe(200);
    const raw=await fetch(`http://127.0.0.1:${port}/expeditions/state`,{headers:{authorization:`Bearer ${restarted.token}`}});
    expect((await raw.json() as any)).toMatchObject({session:null,mana:5});
    expect((await request("/expeditions/heartbeat",{run_id:restartStart.data.session.run_id},restarted.token)).status).toBe(409);
    const raced=(await request("/auth/dev_login",{name:"expedition_race"})).data;
    const raceStart=await request("/expeditions/start",{...loadout,client_action_id:id()},raced.token);
    const raceSession=raceStart.data.session;
    db.query("UPDATE expedition_runs SET heartbeat_at=? WHERE run_id=?").run(Date.now()-15000,raceSession.run_id);
    const race=await Promise.all([
      request("/expeditions/heartbeat",{run_id:raceSession.run_id},raced.token),
      request("/expeditions/exit",{run_id:raceSession.run_id,expected_revision:raceSession.revision,client_action_id:id()},raced.token),
    ]);
    expect(race.map(r=>r.status)).toEqual([409,409]);
    expect((await request("/expeditions/state",undefined,raced.token)).data).toMatchObject({session:null,mana:5});
    // Seed the meter in the persisted combat fixture so both decisions are exercised
    // deterministically through the authenticated API, independent of battle RNG.
    for (const decision of ["choose", "decline"] as const) {
      const player=(await request("/auth/dev_login",{name:`expedition_inspiration_${decision}`})).data;
      const started=await request("/expeditions/start",{...loadout,weapon_ids:["bismuth_talisman","wind_amulet"],client_action_id:id()},player.token);
      expect(started.status).toBe(200);
      const selected=await request("/expeditions/select",{run_id:started.data.session.run_id,expected_revision:started.data.session.revision,choice:0,client_action_id:id()},player.token);
      expect(selected.status).toBe(200);
      let combat=selected.data.session;
      const saved=JSON.parse((db.query("SELECT state_json FROM expedition_runs WHERE run_id=?").get(combat.run_id) as any).state_json);
      saved.combat.player.inspiration=3;
      saved.combat.player.hp=saved.combat.player.max_hp=500;
      saved.combat.npc.hp=saved.combat.npc.max_hp=500;
      db.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(saved),combat.run_id);
      const switched=await request("/expeditions/turn",{run_id:combat.run_id,expected_revision:combat.revision,decision:{turn:1,switch_slot:2},client_action_id:id()},player.token);
      expect(switched.status).toBe(200);
      expect(switched.data.session.revision).toBe(combat.revision+1);
      combat=switched.data.session;
      expect(combat.combat_state.active_weapon_slot).toBe(2);
      expect(combat.combat_state.item_id).toBe("wind_amulet");
      expect(combat.combat_state.player.inspiration_pending).toBe(true);
      const offer=combat.combat_state.player.inspiration_offers[0];
      const resolved=await request("/expeditions/inspiration",{run_id:combat.run_id,expected_revision:combat.revision,decision:decision === "choose" ? {kind:decision,spell_id:offer} : {kind:decision},client_action_id:id()},player.token);
      expect(resolved.status).toBe(200);
      expect(resolved.data.session.revision).toBe(combat.revision+1);
      expect(resolved.data.session.combat_state.player.inspiration_pending).toBe(false);
      if (decision === "choose") expect(resolved.data.session.combat_state.player.spell_ids).toContain(offer);
      const after=JSON.parse((db.query("SELECT state_json FROM expedition_runs WHERE run_id=?").get(combat.run_id) as any).state_json);
      expect(after.combat.blessing == null).toBe(true);
      expect(after.log.some((event:any)=>String(event.kind).includes("blessing"))).toBe(false);
    }
    const bad=await request("/expeditions/start",{...loadout,homunculus_id:"honin",client_action_id:id()},a.token); expect(bad.status).toBe(400);
    const startBody={...loadout,client_action_id:id()}, started=await request("/expeditions/start",startBody,a.token);
    expect(started.status).toBe(200); let session=started.data.session;
    expect(session.phase).toBe("EXPLORE"); expect(session.choices).toHaveLength(2); expect(session.choices[0].id).not.toBe(session.choices[1].id);
    expect(JSON.stringify(session.choices)).not.toMatch(/homunculus|hom_id|hom_type|hom_texture|hom_energy/);
    expect((await request("/expeditions/start",startBody,a.token)).data).toEqual(started.data);
    expect((await request("/expeditions/start",{...startBody,entity_id:"sodium_01"},a.token)).status).toBe(409);
    expect((await request("/expeditions/start",{...loadout,client_action_id:id()},a.token)).status).toBe(409);
    expect((await request("/expeditions/select",{run_id:session.run_id,expected_revision:session.revision,choice:0,client_action_id:id()},b.token)).status).toBe(404);
    expect((await request("/expeditions/select",{run_id:session.run_id,expected_revision:session.revision,choice:2,client_action_id:id()},a.token)).status).toBe(400);
    expect((await request("/expeditions/select",{run_id:session.run_id,expected_revision:session.revision,choice:0,enemy_id:"forged",client_action_id:id()},a.token)).status).toBe(400);
    server.kill(); await server.exited; server=spawn(); await ready(); a=(await request("/auth/dev_login",{name:"expedition_test_a"})).data; b=(await request("/auth/dev_login",{name:"expedition_test_b"})).data;
    expect((await request("/expeditions/state",undefined,a.token)).data.session).toEqual(session);
    let rewardCandidate=false, sawAdvance=false, firstRun=session.run_id, nextBackground="";
    for(let node=0;node<18 && !rewardCandidate;node++) {
      if(!session) {
        const restart=await request("/expeditions/start",{...loadout,client_action_id:id()},a.token); expect(restart.status).toBe(200); session=restart.data.session;
      }
      const choice=Math.max(0,session.choices.findIndex((v:any)=>v.capturable));
      const selected=session.choices[choice], background=session.background_key;
      const selectBody={run_id:session.run_id,expected_revision:session.revision,choice,client_action_id:id()};
      const selectedResult=await request("/expeditions/select",selectBody,a.token); expect(selectedResult.status).toBe(200); session=selectedResult.data.session;
      expect(session.background_key).toBe(background); expect(session.phase).toBe("COMBAT"); expect(session.combat_state.npc.id).toBe(selected.id); expect(expeditionCaptures.some(h => h.id === session.combat_state.npc.hom_id)).toBe(true); expect(session.combat_state.npc.spell_ids).toBeUndefined();
      const foughtHom=session.combat_state.npc.hom_id;
      expect((await request("/expeditions/select",selectBody,a.token)).data).toEqual(selectedResult.data);
      expect((await request("/expeditions/turn",{run_id:session.run_id,expected_revision:session.revision-1,decision:{turn:1,spell_id:"cinder_fist"},client_action_id:id()},a.token)).status).toBe(409);
      for(let turn=0;turn<100 && session?.phase==="COMBAT";turn++) {
        if(session.combat_state.player.inspiration_pending) {
          const inspire=await request("/expeditions/inspiration",{run_id:session.run_id,expected_revision:session.revision,decision:{kind:"decline"},client_action_id:id()},a.token); expect(inspire.status).toBe(200); session=inspire.data.session;
        }
        const player=session.combat_state.player;
        const chosen=player.spell_ids.find((s:string)=>s==="cinder_fist" && !(player.cooldowns[s]>0)) ?? player.spell_ids.find((s:string)=>!(player.cooldowns[s]>0));
        const turnBody={run_id:session.run_id,expected_revision:session.revision,decision:{turn:session.combat_state.turn+1,spell_id:chosen,...(player.hom_energy>=3?{hom_action:"attack"}:{})},client_action_id:id()};
        const result=await request("/expeditions/turn",turnBody,a.token); expect(result.status).toBe(200);
        const replay=await request("/expeditions/turn",turnBody,a.token); if (result.data.session.phase === "LOSS") expect(replay.status).toBe(409); else expect(replay.data).toEqual(result.data);
        session=result.data.session;
      }
      if(session.phase==="LOSS") { expect((await request("/expeditions/state",undefined,a.token)).data.session).toBeNull(); session=null; continue; }
      expect(session.phase).toBe("REWARD"); expect(session.background_key).toBe(background);
      expect(session.combat_state).toBeUndefined();
      if(selected.capturable) { expect(session.capture_candidate?.id).toBe(foughtHom); expect(session.capture_candidate.preview_texture).toContain("_pv.png"); rewardCandidate=true; }
      else expect(session.capture_candidate).toBeNull();
      const reconnected=(await request("/expeditions/state",undefined,a.token)).data.session; expect(reconnected).toEqual(session);
      const skipped=await request("/expeditions/skip",{run_id:session.run_id,expected_revision:session.revision,client_action_id:id()},a.token); expect(skipped.status).toBe(200); session=skipped.data.session; expect(session.directions).toEqual(["left","forward","right"]);
      const advanced=await request("/expeditions/advance",{run_id:session.run_id,expected_revision:session.revision,direction:"left",client_action_id:id()},a.token); expect(advanced.status).toBe(200); session=advanced.data.session; expect(session.phase).toBe("EXPLORE"); expect(session.background_key).not.toBe(background); expect(session.choices).toHaveLength(2); sawAdvance=true; nextBackground=session.background_key;
    }
    expect(rewardCandidate).toBe(true); expect(sawAdvance).toBe(true); expect(nextBackground).toBeTruthy();
    const second=await request("/expeditions/select",{run_id:session.run_id,expected_revision:session.revision,choice:0,client_action_id:id()},a.token); expect(second.status).toBe(200); session=second.data.session;
    const secondTurn=await request("/expeditions/turn",{run_id:session.run_id,expected_revision:session.revision,decision:{turn:1,spell_id:"cinder_fist"},client_action_id:id()},a.token); expect(secondTurn.status).toBe(200); session=secondTurn.data.session;
    expect(session.phase).toBe("COMBAT"); expect(session.background_key).toBe(nextBackground);
    server.kill(); await server.exited; server=spawn(); await ready(); a=(await request("/auth/dev_login",{name:"expedition_test_a"})).data; b=(await request("/auth/dev_login",{name:"expedition_test_b"})).data;
    expect((await request("/expeditions/state",undefined,a.token)).data.session).toEqual(session);
    const exitBody={run_id:session.run_id,expected_revision:session.revision,client_action_id:id()}, exited=await request("/expeditions/exit",exitBody,a.token); expect(exited.status).toBe(200); expect(exited.data.session).toBeNull(); expect(exited.data.remaining_cooldown_ms).toBe(60000);
    expect((await request("/expeditions/exit",exitBody,a.token)).data).toEqual(exited.data);
    expect(maintainExpeditionReplays(db,Date.now()+3*60*60*1000)).toBeGreaterThan(0);
    expect((await request("/expeditions/exit",exitBody,a.token)).data).toEqual(exited.data);
    expect((await request("/expeditions/start",{...loadout,client_action_id:id()},a.token)).status).toBe(409);
    { const current=await request("/expeditions/state",undefined,a.token); expect(current.status).toBe(200); expect(current.data.remaining_cooldown_ms).toBeGreaterThan(0); }
    expect((await request("/expeditions/select",{run_id:session.run_id,expected_revision:session.revision,choice:0,client_action_id:id()},a.token)).status).toBe(409);
    const closed=db.query("SELECT state_json,setup_json,snapshot_json,loadout_json FROM expedition_runs WHERE run_id=?").get(session.run_id) as any; expect(Object.values(closed).every(v=>v===null)).toBe(true);
    server.kill(); await server.exited; server=spawn(); await ready(); a=(await request("/auth/dev_login",{name:"expedition_test_a"})).data; b=(await request("/auth/dev_login",{name:"expedition_test_b"})).data;
    expect((await request("/expeditions/state",undefined,a.token)).data.remaining_cooldown_ms).toBeGreaterThan(0);
    const lossStart=await request("/expeditions/start",{...loadout,client_action_id:id()},b.token); expect(lossStart.status).toBe(200);
    let losing=lossStart.data.session;
    const lossSelect=await request("/expeditions/select",{run_id:losing.run_id,expected_revision:losing.revision,choice:0,client_action_id:id()},b.token); expect(lossSelect.status).toBe(200); losing=lossSelect.data.session;
    const stored=JSON.parse((db.query("SELECT state_json FROM expedition_runs WHERE run_id=?").get(losing.run_id) as any).state_json);
    stored.combat.player.hp=1; stored.combat.npc.atk=1000; stored.combat.npc.tempo=100;
    db.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(stored),losing.run_id);
    for(let i=0;i<10 && losing.phase==="COMBAT";i++) {
      const lossTurn=await request("/expeditions/turn",{run_id:losing.run_id,expected_revision:losing.revision,decision:{turn:losing.combat_state.turn+1,spell_id:"cinder_fist"},client_action_id:id()},b.token);
      expect(lossTurn.status).toBe(200); losing=lossTurn.data.session;
    }
    expect(losing.phase).toBe("LOSS"); expect((await request("/expeditions/state",undefined,b.token)).data.session).toBeNull();
  } finally {
    server.kill(); await server.exited; redis.kill(); await redis.exited; db.close();
    for (let i=0;i<10;i++) { try { rmSync(dir,{recursive:true,force:true}); break; } catch { await Bun.sleep(100); } }
  }
},60000);
