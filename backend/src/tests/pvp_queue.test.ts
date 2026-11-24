import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpChat, createPvpMatches, createPvpQueue, createSharedPvpMatch, pvpRandom, settlePvpMatch, trustedPvpSnapshot } from "../pvp/service";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir,"../../../data",name),"utf8"));
const catalogs = {entities:read("entities.json").entities,items:read("items.json").items,spells:read("spells.json").spells,homunculi:read("homunculi.json").homunculi,types:read("types.json"),mutations:read("static/mutations.json").mutations,balance:read("static/balance.json").balance};
const snapshot = (player_id: string) => ({player_id,entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:catalogs.spells.filter((s: any)=>s.type==="sulfur").slice(0,4).map((s: any)=>s.id)});

test("0.61h targeted audit: queued server snapshot stays frozen when progression changes", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 const states: Record<string,any> = {a:{player_id:"a",item_progress:{bismuth_talisman:{level:0}},homunculus_progress:{},spell_progress:{}},b:{player_id:"b",item_progress:{},homunculus_progress:{},spell_progress:{}}};
 const selection={entity_id:"sulfur_01",weapon_ids:["bismuth_talisman",null],homunculus_id:null,spell_ids:snapshot("a").spell_ids,mode:"attack"};
 const calls: string[]=[]; const queue=createPvpQueue(db,catalogs,(id,chosen)=>{calls.push(id); return trustedPvpSnapshot(id,chosen,states[id],catalogs);},()=>100);
 expect(queue.join("a",selection).state).toBe("QUEUED");
 states.a.item_progress.bismuth_talisman.level=7;
 const match=queue.join("b",{...selection,weapon_ids:[null,null]}) as any;
 const member=db.query("SELECT snapshot_json FROM pvp_match_players WHERE match_id = ? AND player_id = ?").get(match.match_id,"a") as any;
 expect(JSON.parse(member.snapshot_json).item_progress.bismuth_talisman.level).toBe(0);
 const combat=JSON.parse((db.query("SELECT combat_state_json FROM pvp_matches WHERE match_id = ?").get(match.match_id) as any).combat_state_json);
 const fighter=[combat.fighters.left,combat.fighters.right].find((f: any)=>f.player_id==="a");
 expect(fighter.weapons[0].forge_level).toBe(0); expect(calls).toEqual(["a","b"]);
 db.close();
});

test("0.61h targeted audit: resolved status is public to both viewers without private state", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>100); queue.join("a",{}); const match=(queue.join("b",{}) as any).match_id;
 const row=db.query("SELECT combat_state_json FROM pvp_matches WHERE match_id = ?").get(match) as any, state=JSON.parse(row.combat_state_json);
 for(const side of ["left","right"]) {const f=state.fighters[side]; f.status.poison_on_reflect=2; f.spell_neutralize_active=0.2; f.spell_neutralize_pending=0.3; f.strategic_trap={value:0.25,activated_turn:1,expires_turn:3}; f.strategic_heal_suppression={expires_turn:3}; f.inspiration_used_this_battle=true; f.inspiration_pending=true; f.inspiration_offers=["private-offer-"+side]; f.item_progress={private_progress:"secret"};}
 state.strategic_delayed=[{actor:"left",target:"right",amount:9,due_turn:2},{actor:"right",target:"left",amount:4,due_turn:2}];
 db.query("UPDATE pvp_matches SET combat_state_json = ? WHERE match_id = ?").run(JSON.stringify(state),match);
 const service=createPvpMatches(db,new Uint8Array(32).fill(7),()=>100);
 for(const id of ["a","b"]) {
  const view=service.state(match,id); const viewerSide=state.fighters.left.player_id===id?"left":"right";
  for(const [name,side] of [["player",viewerSide],["enemy",viewerSide==="left"?"right":"left"]]) {
   const f=(view as any)[name]; expect(f.status.poison_on_reflect).toBe(2); expect(f.spell_neutralize_active).toBe(0.2); expect(f.spell_neutralize_pending).toBe(0.3);
   expect(f.trap).toEqual({value:0.25,expires_turn:3}); expect(f.heal_suppression).toEqual({expires_turn:3}); expect(f.inspiration_used_this_battle).toBe(true);
   expect(f.delayed_damage).toEqual([{amount:side==="left"?4:9,due_turn:2}]);
  }
  expect(view.player.inspiration_offers).toEqual(["private-offer-"+viewerSide]); expect(view.enemy.inspiration_offers).toBeUndefined(); expect(view.enemy.spell_ids).toBeUndefined();
  const serialized=JSON.stringify(view); expect(serialized).not.toContain("private_progress"); expect(serialized).not.toContain("private-offer-"+(viewerSide==="left"?"right":"left")); expect(serialized).not.toContain("inspiration_catalog"); expect(serialized).not.toContain("rng_counter");
 }
 db.close();
});
test("trusted selection derives progress from server state and checks learned spells", () => {
 const base=snapshot("a"), selection={entity_id:base.entity_id,weapon_ids:base.weapon_ids,homunculus_id:null,spell_ids:base.spell_ids,mode:"attack"};
 const state={player_id:"a",item_progress:{},homunculus_progress:{},spell_progress:{learned_by_entity:{},equipped_by_mode:{}}};
 expect(trustedPvpSnapshot("a",selection,state,catalogs)?.spell_ids).toEqual(base.spell_ids);
 expect(trustedPvpSnapshot("a",{...selection,weapon_ids:["not_a_weapon",null]},state,catalogs)).toBeNull();
 expect(trustedPvpSnapshot("a",{...selection,atk:9999},state,catalogs)).toBeNull();
 const researchable=catalogs.spells.find((s: any)=>s.type==="universal" && s.eligible_types.includes("sulfur"));
 const chosen=[researchable.id,...base.spell_ids.slice(1)]; state.spell_progress.equipped_by_mode={attack:{sulfur_01:chosen}};
 expect(trustedPvpSnapshot("a",{...selection,spell_ids:chosen},state,catalogs)).toBeNull();
 state.spell_progress.learned_by_entity={sulfur_01:[researchable.id]};
 expect(trustedPvpSnapshot("a",{...selection,spell_ids:chosen},state,catalogs)?.spell_ids).toEqual(chosen);
});
test("ranked RNG is deterministic and domain-separated by match, battle, turn and draw", () => {
 const secret=new Uint8Array(32).fill(7), value=pvpRandom(secret,"match-a",1,1,0);
 expect(value).toBe(pvpRandom(secret,"match-a",1,1,0)); expect(value).toBeGreaterThanOrEqual(0); expect(value).toBeLessThan(1);
 for (const input of [["match-b",1,1,0],["match-a",2,1,0],["match-a",1,2,0],["match-a",1,1,1]] as [string,number,number,number][]) expect(pvpRandom(secret,...input)).not.toBe(value);
 expect(()=>pvpRandom(new Uint8Array(31),"match-a",1,1,0)).toThrow();
});
test("queue is persistent, FIFO, exclusive, expires and cancels idempotently", () => {
 const db = new Database(":memory:");
 db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite/0011_pvp.sql"),"utf8"));
 for (const name of ["0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for (const id of ["a","b","c"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 let now=100; const queue=createPvpQueue(db,catalogs,(id)=>id === "c" ? null : snapshot(id),()=>now);
 expect(queue.join("a",{})).toEqual({state:"QUEUED",joined_at:100,expires_at:3600100});
 expect(queue.join("a",{}).state).toBe("QUEUED");
 expect(()=>queue.join("c",{})).toThrow("UNTRUSTED_SETUP");
 const result=queue.join("b",{}) as any; expect(result.state).toBe("MATCHED");
 expect(queue.state("a")).toEqual({state:"MATCHED",match_id:result.match_id});
 expect(queue.state("b")).toEqual({state:"MATCHED",match_id:result.match_id});
 expect((db.query("SELECT COUNT(*) n FROM pvp_match_players WHERE match_id = ?").get(result.match_id) as any).n).toBe(2);
 const settled=settlePvpMatch(db,result.match_id,"left",now);
 expect(settled.deltas).toEqual({left:24,right:-12});
 expect(settlePvpMatch(db,result.match_id,"left",now)).toEqual(settled);
 expect(()=>settlePvpMatch(db,result.match_id,"right",now)).toThrow("RESULT_CONFLICT");
 expect((db.query("SELECT COUNT(*) n FROM pvp_match_players WHERE active = 1").get() as any).n).toBe(0);
 expect(queue.join("a",{}).state).toBe("QUEUED"); now+=3600000; expect(queue.state("a")).toEqual({state:"IDLE"});
 expect(queue.cancel("b")).toEqual({state:"IDLE"}); expect(queue.cancel("b")).toEqual({state:"IDLE"}); db.close();
});

test("a match crossing UTC month end settles without changing either season", () => {
 const db = new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for (const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for (const id of ["a","b"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 let now=Date.UTC(2026,0,31,23,59,30); const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now);
 queue.join("a",{}); const match=queue.join("b",{}) as any;
 now=Date.UTC(2026,1,1); const result=settlePvpMatch(db,match.match_id,"left",now);
 expect(result.deltas).toEqual({left:0,right:0});
 expect((db.query("SELECT SUM(rating) AS n FROM pvp_season_ratings WHERE season = '2026-01'").get() as any).n).toBe(2000);
 expect((db.query("SELECT COUNT(*) AS n FROM pvp_season_ratings WHERE season = '2026-02'").get() as any).n).toBe(0);
 db.close();
});

test("match chat is private, rate limited and idempotent", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for (const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b","c"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 let now=100; const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now);
 queue.join("a",{}); const match=(queue.join("b",{}) as any).match_id; const chat=createPvpChat(db,()=>now);
 expect(chat.send(match,"a","1","hello").duplicate).toBe(false);
 expect(chat.send(match,"a","1","hello").duplicate).toBe(true);
 expect(()=>chat.send(match,"a","1","different")).toThrow("ACTION_CONFLICT");
 expect(()=>chat.send(match,"a","2","again")).toThrow("CHAT_RATE_LIMIT");
 expect(()=>chat.list(match,"c")).toThrow("MATCH_NOT_FOUND");
 expect(()=>chat.send(match,"b","3","bad\ntext")).toThrow("INVALID_CHAT");
 now+=10000; chat.send(match,"a","2","again");
 expect(chat.list(match,"b").map((m: any)=>m.text)).toEqual(["hello","again"]);
 db.close();
});

test("private simultaneous decisions resolve once, preserve revisions and enforce access", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b","c"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 let now=100; const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now); queue.join("a",{});
 const match=(queue.join("b",{}) as any).match_id, service=createPvpMatches(db,new Uint8Array(32).fill(7),()=>now);
 expect(service.state(match,"a").deadline).toBe(now + 90_000);
 const decision={turn:1,spell_id:"cinder_fist"};
 const first=service.decide(match,"a","action-a",1,decision);
 expect(first.combat_revision).toBe(1); expect(first.ready).toEqual({player:true,enemy:false});
 const other=service.state(match,"b"); expect(other.ready).toEqual({player:false,enemy:true});
 expect(JSON.stringify(other)).not.toContain("decision_json"); expect(JSON.stringify(other)).not.toContain("inspiration_catalog");
 expect(other.enemy.spell_ids).toBeUndefined(); expect(other.enemy.spell_cooldowns).toBeUndefined();
 expect(service.decide(match,"a","action-a",1,decision)).toEqual(first);
 expect(()=>service.decide(match,"a","action-a",1,{turn:1,spell_id:"ash_temper"})).toThrow("ACTION_CONFLICT");
 const resolved=service.decide(match,"b","action-b",1,decision); expect(resolved.combat_revision).toBe(2); expect(resolved.turn).toBe(1);
 expect(resolved.deadline).toBe(now + 90_000);
 expect(resolved.events.filter((e: any)=>e.kind==="spell")).toHaveLength(2);
 const last=resolved.events[resolved.events.length-1].id; expect(service.state(match,"b",last).events).toEqual([]);
 db.query("INSERT INTO pvp_events (match_id,seq,kind,visibility,payload_json,created_at) VALUES (?,?,?,'public',?,?)").run(match,last+1,"damage",JSON.stringify({kind:"damage",side:"left",target_side:"right",spell_id:"cinder_fist",show_spell_link:false,effectiveness:1.12,spell_meta:{internal:"secret"}}),now);
 const safe=service.state(match,"b",last).events[0]; expect(safe.effectiveness).toBe(1.12); expect(safe.show_spell_link).toBe(false); expect(safe.spell_meta).toBeUndefined();
 expect(()=>service.state(match,"c")).toThrow("MATCH_NOT_FOUND");
 now+=89_000; expect(service.state(match,"a").status).toBe("ACTIVE");
 now+=1_000; expect(service.state(match,"a").result.result).toBe("draw");
 expect(service.state(match,"b").result.result).toBe("draw"); db.close();
});

test("missing decisions forfeit and pending Inspiration auto-declines on timeout", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 let now=100; const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now); queue.join("a",{});
 let id=(queue.join("b",{}) as any).match_id; const service=createPvpMatches(db,new Uint8Array(32).fill(7),()=>now);
 service.decide(id,"a","a1",1,{turn:1,spell_id:"cinder_fist"}); now+=90_000;
 const win = service.state(id,"a").result, loss = service.state(id,"b").result;
 expect(win).toMatchObject({result:"win", mp_delta:24, mp_total_after:1024, league:"Copper", division:"IV"});
 expect(loss).toMatchObject({result:"loss", mp_delta:-12, mp_total_after:988, league:"Copper", division:"IV"});
 db.query("UPDATE pvp_season_ratings SET rating = 2500 WHERE player_id = ?").run("a");
 expect(service.state(id,"a").result).toEqual(win);
 queue.join("a",{}); id=(queue.join("b",{}) as any).match_id;
 const row=db.query("SELECT combat_state_json FROM pvp_matches WHERE match_id = ?").get(id) as any, state=JSON.parse(row.combat_state_json);
 for(const side of ["left","right"]) { const f=state.fighters[side]; f.inspiration=3; f.inspiration_pending=true; f.inspiration_offers=f.inspiration_catalog.slice(0,3).map((s: any)=>s.id); }
 db.query("UPDATE pvp_matches SET combat_state_json = ? WHERE match_id = ?").run(JSON.stringify(state),id);
 expect(service.state(id,"a").enemy.inspiration_offers).toBeUndefined();
 now+=90_000; const after=service.state(id,"a"); expect(after.status).toBe("ACTIVE"); expect(after.turn).toBe(0); expect(after.player.inspiration_pending).toBe(false); expect(after.enemy.inspiration_pending).toBe(false); expect(after.combat_revision).toBe(2);
 db.close();
});

test("playback waits for both ACKs or expiry, preserving revision and a full decision window", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b"]) db.query("INSERT INTO players VALUES (?,?)").run(id,id);
 let now=100; const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now), service=createPvpMatches(db,new Uint8Array(32).fill(7),()=>now);
 queue.join("a",{},1); const id=(queue.join("b",{},1) as any).match_id;
 const decision={turn:1,spell_id:"cinder_fist"}; service.decide(id,"a","a1",1,decision);
 const resolved=service.decide(id,"b","b1",1,decision); expect(resolved.phase).toBe("PLAYBACK"); expect(resolved.playback_event_end).toBeGreaterThan(0);
 expect(()=>service.decide(id,"a","early",2,{turn:2,spell_id:"cinder_fist"})).toThrow("PLAYBACK_PENDING");
 expect(service.ack(id,"a",2).phase).toBe("PLAYBACK"); expect(service.ack(id,"a",2).phase).toBe("PLAYBACK");
 now+=1000; const opened=service.ack(id,"b",2); expect(opened.phase).toBe("DECISION"); expect(opened.combat_revision).toBe(2); expect(opened.deadline).toBe(now+60_000);
 expect(()=>service.ack(id,"a",1)).toThrow("STALE_REVISION");
 service.decide(id,"a","a2",2,{turn:2,spell_id:"cinder_fist"}); const second=service.decide(id,"b","b2",2,{turn:2,spell_id:"cinder_fist"});
 expect(second.phase).toBe("PLAYBACK"); expect(()=>service.ack(id,"a",2)).toThrow("STALE_REVISION"); expect(service.state(id,"a").phase).toBe("PLAYBACK"); expect(()=>service.ack(id,"outsider",3)).toThrow("MATCH_NOT_FOUND"); now=second.playback_until; service.sweep(); const fallback=service.state(id,"a");
 expect(fallback.phase).toBe("DECISION"); expect(fallback.combat_revision).toBe(3); expect(fallback.deadline).toBe(now+60_000);
 expect(()=>service.ack(id,"a",2)).toThrow("STALE_REVISION");
 service.forfeit(id,"a","end"); queue.join("a",{},1); const mixed=(queue.join("b",{}) as any).match_id;
 expect(service.state(mixed,"a").phase).toBeUndefined(); expect(service.state(mixed,"a").deadline).toBe(now+90_000); db.close();
});

test("terminal rewards are once-only, exclude forfeits and timeouts, and cap friendly wins per UTC day", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql","0027_forest_duels.sql","0028_friendly_pvp.sql","0030_pvp_playback_xp.sql","0031_practice.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b"]) db.query("INSERT INTO players VALUES (?,?)").run(id,id);
 let now=100; let grants=0; const reward=(player:string, frozen:string)=>{expect(JSON.parse(frozen).player_id).toBe(player); grants++; return {xp_granted:20,level_before:1,level_after:1};};
 const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now), service=createPvpMatches(db,new Uint8Array(32).fill(7),()=>now,reward);
 queue.join("a",{}); let id=(queue.join("b",{}) as any).match_id;
 const raw=db.query("SELECT combat_state_json FROM pvp_matches WHERE match_id=?").get(id) as any, state=JSON.parse(raw.combat_state_json);
 state.wins.left=1; state.fighters.right.hp=1; state.fighters.left.hp=state.fighters.left.max_hp;
 db.query("UPDATE pvp_matches SET combat_state_json=? WHERE match_id=?").run(JSON.stringify(state),id);
 service.decide(id,"a","award-a",1,{turn:1,spell_id:"cinder_fist"}); const final=service.decide(id,"b","award-b",1,{turn:1,spell_id:"cinder_fist"});
 expect(final.status).toBe("FINISHED"); expect(grants).toBe(1); const views=[service.state(id,"a"),service.state(id,"b")]; expect(views.find(v=>v.result?.result==='win')?.result?.homunculus_xp?.xp_granted).toBe(20); expect(views.find(v=>v.result?.result==='loss')?.result?.homunculus_xp).toBeUndefined(); service.decide(id,"b","award-b",1,{turn:1,spell_id:"cinder_fist"}); expect(grants).toBe(1);
 queue.join("a",{}); id=(queue.join("b",{}) as any).match_id; service.forfeit(id,"a","give-up"); expect(grants).toBe(1);
 queue.join("a",{}); id=(queue.join("b",{}) as any).match_id; now+=90_000; service.state(id,"a"); expect(grants).toBe(1);
 const friendlyWin=(n:number)=>{ const invite=`invite-${n}`; db.query("INSERT INTO forest_duel_invites VALUES (?,'a','b','room','STARTED',?,?,?)").run(invite,now,now,now+1000); const match=createSharedPvpMatch(db,catalogs,snapshot("a"),snapshot("b"),now,"friendly",invite); const side=(db.query("SELECT side FROM pvp_match_players WHERE match_id=? AND player_id='a'").get(match) as any).side.toLowerCase(); settlePvpMatch(db,match,side,now,reward); };
 for(let i=0;i<4;i++) friendlyWin(i);
 expect(grants).toBe(4); now+=86_400_000; friendlyWin(4); expect(grants).toBe(5); db.close();
});
