import { expect, test } from "bun:test";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { createServer } from "node:net";
import { createHmac } from "node:crypto";
import { Database } from "bun:sqlite";
import { expeditionCaptures, expeditionDraw, expeditionCaptureChance, EXPEDITION_MANA_INTERVAL_MS } from "../expeditions_rules";
import { maintainExpeditionReplays, EXPEDITION_REPLAY_RETENTION_MS } from "../expeditions_service";

const freePort=()=>new Promise<number>(done=>{const server=createServer().listen(0,"127.0.0.1",()=>{const port=(server.address() as {port:number}).port;server.close(()=>done(port));});});
test("50% drop and rarity capture distributions use separate deterministic domains",()=>{
  let drops=0; const seed=new Uint8Array(32).fill(3);
  for(let i=0;i<1000;i++) if(expeditionDraw(seed,JSON.stringify(["crystal-drop",`run-${i}`,1]),0)<0.5) drops++;
  expect(drops).toBeGreaterThan(450); expect(drops).toBeLessThan(550);
  expect(expeditionCaptureChance(1)).toBe(0.65); expect(expeditionCaptureChance(10)).toBe(0.2);
});

test("mana interval migration preserves earned points and extends pending regeneration", () => {
  const db = new Database(":memory:");
  db.exec("CREATE TABLE expedition_balances (mana INTEGER, regen_at INTEGER)");
  const now = Math.floor(Date.now() / 1000) * 1000;
  db.query("INSERT INTO expedition_balances VALUES (?, ?), (?, ?), (?, ?)").run(4, now + 600000, 2, now - 1800000, 6, 0);
  db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0025_expedition_mana_interval.sql"), "utf8"));
  expect(db.query("SELECT mana, regen_at FROM expedition_balances ORDER BY rowid").all()).toEqual([
    {mana: 4, regen_at: now + 600000 + 5400000},
    {mana: 4, regen_at: now + 1800000 + 5400000},
    {mana: 6, regen_at: 0},
  ]);
  db.close();
});

test("expedition economics and captures settle atomically through authenticated routes",async()=>{
  const port=await freePort(),redisPort=await freePort(),dir=mkdtempSync(join(tmpdir(),"entitywars-e5c-")),db=new Database(join(dir,"test.sqlite"));
  const migrations=resolve(import.meta.dir,"../../migrations/sqlite");
  for(const file of readdirSync(migrations).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations,file),"utf8"));
  const redis=Bun.spawn([Bun.which("redis-server")!,"--port",String(redisPort),"--bind","127.0.0.1","--save","","--appendonly","no"],{cwd:dir,stdout:"ignore",stderr:"ignore"});
  const env={...process.env,DB_PATH:join(dir,"test.sqlite"),NODE_ENV:"development",BUN_ENV:"development",HOST:"127.0.0.1",PORT:String(port),DATABASE_URL:"postgres://x:x@127.0.0.1:1/test",REDIS_URL:`redis://127.0.0.1:${redisPort}`,PG_CONNECT_TIMEOUT_SECONDS:"1",AUTH_ACCOUNT_TIMEOUT_MS:"10",DEBUG_BYPASS:"0",WORLD_SECRET:"dev_world_secret",EXPENSIVE_RATE_LIMIT_MAX:"2000"};
  const spawn=()=>Bun.spawn([process.execPath,"src/index.ts"],{cwd:resolve(import.meta.dir,"../.."),env,stdout:"ignore",stderr:"ignore"}); let server=spawn(),serial=0;
  const leaseByName = new Map<string,string>(), nameByToken = new Map<string,string>(), runByName = new Map<string,string>();
  const req=async(path:string,body?:any,token?:string)=>{
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
  const ready=async()=>{for(let i=0;i<100;i++){try{if((await req("/health")).status===200)return;}catch{}await Bun.sleep(100);}throw Error("server unavailable");};
  const id=()=>`e5c-${serial++}`;
  const player=(id:string)=>JSON.parse((db.query("SELECT state_json FROM players WHERE player_id=?").get(id) as any).state_json);
  const setPool=(id:string,mana:number,crystals:number,regenAt:number)=>db.query("UPDATE expedition_balances SET mana=?,crystals=?,regen_at=? WHERE player_id=?").run(mana,crystals,regenAt,id);
  const saved=(run:string)=>JSON.parse((db.query("SELECT state_json FROM expedition_runs WHERE run_id=?").get(run) as any).state_json);
  const save=(run:string,state:any)=>db.query("UPDATE expedition_runs SET state_json=? WHERE run_id=?").run(JSON.stringify(state),run);
  const body=(session:any,extras:any={})=>({run_id:session.run_id,expected_revision:session.revision,client_action_id:id(),...extras});
  const loadout={entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:"cinder",spell_ids:["cinder_fist","furnace_rush","ash_temper","brimstone_crash"],mode:"attack"};
  try {
    await ready(); let a=(await req("/auth/dev_login",{name:"e5c_player_a"})).data, b=(await req("/auth/dev_login",{name:"e5c_player_b"})).data;
    let status=(await req("/expeditions/state",undefined,a.token)).data; expect([status.mana,status.crystals,status.next_regeneration_at]).toEqual([6,0,null]);
    setPool(a.player_id,2,0,Date.now()-EXPEDITION_MANA_INTERVAL_MS-1000);
    status=(await req("/expeditions/state",undefined,a.token)).data; expect(status.mana).toBe(4); expect(status.next_regeneration_at).toBeGreaterThan(Date.now());
    setPool(a.player_id,5,0,Date.now()-EXPEDITION_MANA_INTERVAL_MS*4);
    status=(await req("/expeditions/state",undefined,a.token)).data; expect(status.mana).toBe(6); expect(status.next_regeneration_at).toBeNull();
    setPool(a.player_id,0,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
    expect((await req("/expeditions/start",{...loadout,client_action_id:id()},a.token)).status).toBe(409);
    setPool(a.player_id,6,0,0);
    let start=await req("/expeditions/start",{...loadout,client_action_id:id()},a.token); expect(start.status).toBe(200); expect(start.data.mana).toBe(6); let session=start.data.session;
    expect((await req("/expeditions/capture",body(session),b.token)).status).toBe(404);
    expect((await req("/expeditions/capture",body(session,{candidate_id:"honin"}),a.token)).status).toBe(400);
    const runSeed=createHmac("sha256","dev_world_secret").update("expedition:"+session.run_id).digest();
    let victories=0;
    const victory=async()=>{
      if (victories === 1) {
        const capped=player(a.player_id); capped.wallet.essence=1_000_000;
        db.query("UPDATE players SET state_json=? WHERE player_id=?").run(JSON.stringify(capped),a.player_id);
      }
      if (victories >= 2 && (db.query("SELECT mana FROM expedition_balances WHERE player_id=?").get(a.player_id) as any).mana < 0.3) setPool(a.player_id,6,0,0);
      const before=player(a.player_id).homunculus_progress.cinder?.xp ?? 0;
      const selected=Math.max(0,session.choices.findIndex((x:any)=>x.capturable));
      const select=await req("/expeditions/select",body(session,{choice:selected}),a.token); expect(select.status).toBe(200);session=select.data.session;
      // Fixture makes an actual resolver turn decisive without forging a terminal result.
      const state=saved(session.run_id); const frozenTier=state.victory_tier;
      const difficulty=state.difficulty_depth ?? state.depth;
      const expectedTier=difficulty >= (state.selected.capturable ? 30 : 35) ? "exceptional" : difficulty >= (state.selected.capturable ? 12 : 15) ? "very_difficult" : difficulty >= (state.selected.capturable ? 4 : 5) ? "difficult" : "normal";
      expect(frozenTier).toBe(expectedTier);
      if (victories === 0) state.difficulty_depth=100;
      state.combat.player.hp=state.combat.player.max_hp=500; state.combat.player.tempo=1000; state.combat.npc.hp=1; state.combat.npc.status={}; state.combat.npc.item_effects.evasion_pct=0; state.combat.spells.find((s:any)=>s.id==="cinder_fist").accuracy=1; save(session.run_id,state);
      const winBody=body(session,{decision:{turn:1,spell_id:"cinder_fist"}});
      const beforePlayer=player(a.player_id);
      if (victories === 0) {
        setPool(a.player_id,0,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
        expect((await req("/expeditions/turn",winBody,a.token)).status).toBe(400);
        expect(saved(session.run_id).phase).toBe("COMBAT");
        expect(player(a.player_id)).toEqual(beforePlayer);
        setPool(a.player_id,6,0,0);
        db.exec("CREATE TRIGGER expedition_victory_failure BEFORE INSERT ON audit_wallet WHEN NEW.reason='EXPEDITION_VICTORY' BEGIN SELECT RAISE(ABORT, 'forced failure'); END");
        expect((await req("/expeditions/turn",winBody,a.token)).status).toBeGreaterThanOrEqual(400);
        expect(player(a.player_id)).toEqual(beforePlayer);
        expect((db.query("SELECT mana FROM expedition_balances WHERE player_id=?").get(a.player_id) as any).mana).toBe(6);
        expect(saved(session.run_id).phase).toBe("COMBAT");
        db.exec("DROP TRIGGER expedition_victory_failure");
      }
      const win=await req("/expeditions/turn",winBody,a.token); expect(win.status).toBe(200); expect(win.data.session.phase).toBe("REWARD"); expect(win.data.events.some((e:any)=>e.kind==="damage"&&e.actor==="player")).toBe(true);
      const reward=win.data.session.victory_reward;
      expect(reward.tier).toBe(frozenTier);
      if (victories === 1) expect(reward.grants.essence).toBe(0);
      expect(reward.reward_id).toBe(`${session.run_id}:${session.depth}:victory`);
      expect(["normal","difficult","very_difficult","exceptional"]).toContain(reward.tier);
      const afterPlayer=player(a.player_id);
      const audit=db.query("SELECT delta_wallet FROM audit_wallet WHERE player_id=? AND reason='EXPEDITION_VICTORY' AND related_id=?").get(a.player_id,reward.reward_id) as any;
      const nonzero=Object.fromEntries(Object.entries(reward.grants).filter(([, amount])=>Number(amount)>0));
      if (Object.keys(nonzero).length) expect(JSON.parse(audit.delta_wallet)).toEqual(nonzero); else expect(audit).toBeNull();
      for (const [resource, amount] of Object.entries(reward.grants)) expect((afterPlayer.wallet[resource] ?? 0)-(beforePlayer.wallet[resource] ?? 0)).toBe(amount);
      expect((await req("/expeditions/turn",winBody,a.token)).data).toEqual(win.data);
      expect(player(a.player_id)).toEqual(afterPlayer);
      expect(player(a.player_id).homunculus_progress.cinder.xp).toBe(before+20);
      session=win.data.session; victories++; return win.data;
    };
    let win=await victory(); expect(win.mana).toBe(5.7); expect((db.query("SELECT mana FROM expedition_balances WHERE player_id=?").get(a.player_id) as any).mana).toBe(5.7);
    const skipAdvance=async(expectedPool?:number)=>{
      let skip=await req("/expeditions/skip",body(session),a.token); expect(skip.status).toBe(200); session=skip.data.session;
      const previousDepth=session.depth, advanceBody=body(session,{direction:"forward"});
      const advanced=await req("/expeditions/advance",advanceBody,a.token); expect(advanced.status).toBe(200); expect((await req("/expeditions/advance",advanceBody,a.token)).data).toEqual(advanced.data);
      const drop=advanced.data.events.find((e:any)=>e.kind==="crystal_drop");
      if(expectedPool!==undefined) expect(drop.granted).toBe(expectedPool<5 && expeditionDraw(runSeed,JSON.stringify(["crystal-drop",session.run_id,previousDepth]),0)<0.5);
      session=advanced.data.session; expect(session.latest_reward).toEqual(drop); return advanced.data;
    };
    const firstAdvance=await skipAdvance(0); win=await victory(); expect(win.mana).toBe(5.4); expect(session.latest_reward).toEqual(firstAdvance.events[0]);
    await skipAdvance(); setPool(a.player_id,0.2,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
    expect((await req("/expeditions/select",body(session,{choice:0}),a.token)).status).toBe(400);
    setPool(a.player_id,0.3,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
    win=await victory(); expect(win.mana).toBe(0);
    await skipAdvance();
    expect((await req("/expeditions/select",body(session,{choice:0}),a.token)).status).toBe(400);
    const buyer=player(a.player_id); buyer.wallet.essence=299;
    db.query("UPDATE players SET state_json=? WHERE player_id=?").run(JSON.stringify(buyer),a.player_id);
    const firstBuy=body(session);
    expect((await req("/expeditions/buy_mana",firstBuy,a.token)).status).toBe(400);
    expect(player(a.player_id).wallet.essence).toBe(299);
    buyer.wallet.essence=3900;
    db.query("UPDATE players SET state_json=? WHERE player_id=?").run(JSON.stringify(buyer),a.player_id);
    db.exec("CREATE TRIGGER expedition_mana_failure BEFORE INSERT ON audit_wallet WHEN NEW.reason='EXPEDITION_BUY_MANA' BEGIN SELECT RAISE(ABORT, 'forced failure'); END");
    expect((await req("/expeditions/buy_mana",firstBuy,a.token)).status).toBeGreaterThanOrEqual(400);
    expect(player(a.player_id).wallet.essence).toBe(3900);
    expect((db.query("SELECT mana FROM expedition_balances WHERE player_id=?").get(a.player_id) as any).mana).toBe(0);
    expect(db.query("SELECT 1 FROM action_log WHERE player_id=? AND client_action_id=?").get(a.player_id,firstBuy.client_action_id)).toBeNull();
    db.exec("DROP TRIGGER expedition_mana_failure");
    const bought=await req("/expeditions/buy_mana",firstBuy,a.token); expect(bought.status).toBe(200);
    expect(bought.data.mana).toBe(1); expect(bought.data.mana_purchases_remaining).toBe(11);
    expect(player(a.player_id).wallet.essence).toBe(3600);
    expect((await req("/expeditions/buy_mana",firstBuy,a.token)).data).toEqual(bought.data);
    expect(player(a.player_id).wallet.essence).toBe(3600);
    session=bought.data.session;
    setPool(a.player_id,5.5,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
    expect((await req("/expeditions/buy_mana",body(session),a.token)).status).toBe(400);
    expect(player(a.player_id).wallet.essence).toBe(3600);
    for(let i=1;i<12;i++) {
      setPool(a.player_id,0,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
      const next=await req("/expeditions/buy_mana",body(session),a.token);
      expect(next.status).toBe(200); expect(next.data.mana_purchases_remaining).toBe(11-i); session=next.data.session;
    }
    setPool(a.player_id,0,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
    expect((await req("/expeditions/buy_mana",body(session),a.token)).status).toBe(400);
    expect(player(a.player_id).wallet.essence).toBe(300);
    db.query("UPDATE action_log SET created_at=? WHERE player_id=? AND client_action_id=?").run(Date.now()-86400001,a.player_id,firstBuy.client_action_id);
    const renewed=await req("/expeditions/buy_mana",body(session),a.token);
    expect(renewed.status).toBe(200); expect(player(a.player_id).wallet.essence).toBe(0); session=renewed.data.session;
    setPool(a.player_id,0,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
    expect((await req("/expeditions/buy_mana",body(session),a.token)).status).toBe(400);
    setPool(a.player_id,6,0,0);
    win=await victory();
    server.kill(); await server.exited; server=spawn(); await ready(); a=(await req("/auth/dev_login",{name:"e5c_player_a"})).data;b=(await req("/auth/dev_login",{name:"e5c_player_b"})).data;
    expect((await req("/expeditions/state",undefined,a.token)).data.session).toEqual(session);
    // Find a genuinely flagged victory, then choose deterministic fixture candidates from the trusted manifest.
    for(let i=0;i<15 && !session.capture_candidate;i++){ await skipAdvance(); await victory(); }
    expect(session.capture_candidate).toBeTruthy();
    const chooseCandidate=(want:(candidate:any,depth:number)=>boolean)=>{
      const state=saved(session.run_id); let candidate:any;
      // Depth only selects a deterministic fixture; success is still resolved by the real server draw.
      for(let depth=state.depth;depth<state.depth+200 && !candidate;depth++) for(const item of expeditionCaptures) if(want(item,depth)){candidate=item;state.depth=depth;break;}
      if(!candidate) throw Error("no deterministic capture fixture");
      state.candidate=candidate; state.selected.homunculus_id=candidate.id; save(session.run_id,state); session.depth=state.depth; session.capture_candidate=candidate; return candidate;
    };
    const roll=(c:any,d:number,n:number)=>expeditionDraw(runSeed,JSON.stringify(["capture",session.run_id,d,c.id]),n);
    const first=chooseCandidate((c,d)=>roll(c,d,0)<expeditionCaptureChance(c.rarity));
    setPool(a.player_id,6,0,0); expect((await req("/expeditions/capture",body(session),a.token)).status).toBe(409);
    setPool(a.player_id,6,5,0);
    const captureBody=body(session);
    db.exec("CREATE TRIGGER expedition_capture_failure BEFORE UPDATE ON players BEGIN SELECT RAISE(ABORT, 'forced failure'); END");
    expect((await req("/expeditions/capture",captureBody,a.token)).status).toBeGreaterThanOrEqual(400);
    expect((db.query("SELECT crystals FROM expedition_balances WHERE player_id=?").get(a.player_id) as any).crystals).toBe(5);
    expect((db.query("SELECT revision FROM expedition_runs WHERE run_id=?").get(session.run_id) as any).revision).toBe(session.revision);
    expect(db.query("SELECT 1 FROM action_log WHERE player_id=? AND client_action_id=?").get(a.player_id,captureBody.client_action_id)).toBeNull();
    db.exec("DROP TRIGGER expedition_capture_failure");
    const captured=await req("/expeditions/capture",captureBody,a.token); expect(captured.status).toBe(200); expect(captured.data.crystals).toBe(4);
    expect(captured.data.events[0]).toMatchObject({kind:"capture_success",candidate_id:first.id,duplicate:false,duplicate_xp:0,preview_texture:first.preview_texture,remaining_attempts:0});
    expect(captured.data.session.capture_attempts_remaining).toBe(0);
    expect(player(a.player_id).homunculus_progress[first.id]).toEqual({owned:true,level:0,xp:0}); expect((await req("/expeditions/capture",captureBody,a.token)).data).toEqual(captured.data);
    session=captured.data.session; expect((await req("/expeditions/capture",body(session),a.token)).status).toBe(409);
    expect((await req("/expeditions/state",undefined,a.token)).data.session.latest_reward).toEqual(captured.data.events[0]);
    setPool(a.player_id,6,5,0); const advancedCap=await skipAdvance(5); expect(advancedCap.crystals).toBe(5); expect(advancedCap.events[0].granted).toBe(false);
    win=await victory();
    for(let i=0;i<15 && !session.capture_candidate;i++){await skipAdvance();await victory();}
    expect(session.capture_candidate).toBeTruthy();
    // Preserve an existing level and mutation when granting duplicate XP.
    const progress=player(a.player_id); progress.homunculus_progress[first.id]={owned:true,level:3,xp:550,mutation_id:"catalyst",mutation_changed_at:123}; db.query("UPDATE players SET state_json=? WHERE player_id=?").run(JSON.stringify(progress),a.player_id);
    const duplicate=chooseCandidate((c,d)=>c.id===first.id && roll(c,d,0)<expeditionCaptureChance(c.rarity));
    setPool(a.player_id,6,5,0); const dup=await req("/expeditions/capture",body(session),a.token); expect(dup.status).toBe(200); session=dup.data.session;
    expect(dup.data.events[0]).toMatchObject({kind:"capture_success",candidate_id:duplicate.id,duplicate:true,duplicate_xp:20});
    expect(player(a.player_id).homunculus_progress[first.id]).toEqual({owned:true,level:3,xp:570,mutation_id:"catalyst",mutation_changed_at:123});
    await skipAdvance(); await victory();
    for(let i=0;i<15 && !session.capture_candidate;i++){await skipAdvance();await victory();}
    expect(session.capture_candidate).toBeTruthy();
    const failCandidate=chooseCandidate((c,d)=>[0,1,2].every(n=>roll(c,d,n)>=expeditionCaptureChance(c.rarity)));
    setPool(a.player_id,6,5,0);
    for(let i=1;i<=3;i++) {const failureBody=body(session),failure=await req("/expeditions/capture",failureBody,a.token);expect(failure.status).toBe(200);expect(failure.data.events[0]).toMatchObject({kind:"capture_failure",candidate_id:failCandidate.id,attempt:i,remaining_attempts:3-i});expect((await req("/expeditions/capture",failureBody,a.token)).data).toEqual(failure.data);session=failure.data.session;}
    expect(session.capture_closed).toBe(true); expect((await req("/expeditions/capture",body(session),a.token)).status).toBe(409);
    expect((await req("/expeditions/state",undefined,a.token)).data.session.latest_reward.kind).toBe("capture_failure");
    const oldRun=session.run_id,exitBody=body(session),exited=await req("/expeditions/exit",exitBody,a.token); expect(exited.status).toBe(200);expect(exited.data.mana).toBe(5);expect(exited.data.remaining_cooldown_ms).toBe(60000);
    maintainExpeditionReplays(db,Date.now()+6*24*60*60*1000);
    expect((await req("/expeditions/exit",exitBody,a.token)).data).toEqual(exited.data);
    expect((await req("/expeditions/start",{...loadout,client_action_id:id()},a.token)).status).toBe(409);
    // Defeat spends exactly one mana, with the regeneration clock starting from full.
    await req("/expeditions/state",undefined,b.token);let bs=(await req("/expeditions/start",{...loadout,client_action_id:id()},b.token)).data.session;
    bs=(await req("/expeditions/select",body(bs,{choice:0}),b.token)).data.session;
    const beforeLoss=player(b.player_id);
    setPool(b.player_id,0.5,0,Date.now()+EXPEDITION_MANA_INTERVAL_MS);
    const losing=saved(bs.run_id);losing.combat.player.hp=1;losing.combat.npc.atk=1000;losing.combat.npc.tempo=100;save(bs.run_id,losing);
    for(let i=0;i<10 && bs.phase==="COMBAT";i++){const loseBody=body(bs,{decision:{turn:bs.combat_state.turn+1,spell_id:"cinder_fist"}}),lose=await req("/expeditions/turn",loseBody,b.token);expect(lose.status).toBe(200);if(lose.data.session.phase==="LOSS"){expect(lose.data.mana).toBe(0);expect(lose.data.next_regeneration_at).toBeGreaterThan(Date.now());expect((await req("/expeditions/turn",loseBody,b.token)).status).toBe(409);}bs=lose.data.session;}
    expect(bs.phase).toBe("LOSS"); expect(player(b.player_id)).toEqual(beforeLoss); expect(bs.victory_reward).toBeUndefined();
    // Retention removes only finished Expedition history, in bounded passes.
    db.query("INSERT INTO action_log(player_id,client_action_id,action_type,payload_json,result_state_json,created_at,expedition_run_id) VALUES(?,?,?,?,?,?,?)").run(a.player_id,"unrelated","OTHER","{}","{}",0,oldRun);
    for(let i=0;i<30 && db.query("SELECT 1 FROM expedition_runs WHERE run_id=?").get(oldRun);i++) maintainExpeditionReplays(db,Date.now()+EXPEDITION_REPLAY_RETENTION_MS+1000);
    expect(db.query("SELECT 1 FROM expedition_runs WHERE run_id=?").get(oldRun)).toBeNull();
    expect(db.query("SELECT 1 FROM action_log WHERE player_id=? AND client_action_id='unrelated'").get(a.player_id)).toBeTruthy();
    expect((await req("/expeditions/skip",{run_id:oldRun,expected_revision:1,client_action_id:id()},a.token)).status).toBe(404);
    expect(victories).toBeGreaterThanOrEqual(3);
  } finally { server.kill();await server.exited;redis.kill();await redis.exited;db.close();for(let i=0;i<10;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch{await Bun.sleep(100);}} }
},60000);
