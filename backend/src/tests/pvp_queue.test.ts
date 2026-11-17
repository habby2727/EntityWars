import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpChat, createPvpMatches, createPvpQueue, pvpRandom, settlePvpMatch, trustedPvpSnapshot } from "../pvp/service";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir,"../../../data",name),"utf8"));
const catalogs = {entities:read("entities.json").entities,items:read("items.json").items,spells:read("spells.json").spells,homunculi:read("homunculi.json").homunculi,types:read("types.json"),mutations:read("static/mutations.json").mutations,balance:read("static/balance.json").balance};
const snapshot = (player_id: string) => ({player_id,entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:catalogs.spells.filter((s: any)=>s.type==="sulfur").slice(0,4).map((s: any)=>s.id)});
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
 for (const name of ["0012_pvp_seasons.sql","0013_pvp_match_data.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
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
 for (const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
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
 for (const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
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
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b","c"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 let now=100; const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now); queue.join("a",{});
 const match=(queue.join("b",{}) as any).match_id, service=createPvpMatches(db,new Uint8Array(32).fill(7),()=>now);
 const decision={turn:1,spell_id:"cinder_fist"};
 const first=service.decide(match,"a","action-a",1,decision);
 expect(first.combat_revision).toBe(1); expect(first.ready).toEqual({player:true,enemy:false});
 const other=service.state(match,"b"); expect(other.ready).toEqual({player:false,enemy:true});
 expect(JSON.stringify(other)).not.toContain("decision_json"); expect(JSON.stringify(other)).not.toContain("inspiration_catalog");
 expect(other.enemy.spell_ids).toBeUndefined(); expect(other.enemy.spell_cooldowns).toBeUndefined();
 expect(service.decide(match,"a","action-a",1,decision)).toEqual(first);
 expect(()=>service.decide(match,"a","action-a",1,{turn:1,spell_id:"ash_temper"})).toThrow("ACTION_CONFLICT");
 const resolved=service.decide(match,"b","action-b",1,decision); expect(resolved.combat_revision).toBe(2); expect(resolved.turn).toBe(1);
 expect(resolved.events.filter((e: any)=>e.kind==="spell")).toHaveLength(2);
 const last=resolved.events[resolved.events.length-1].id; expect(service.state(match,"b",last).events).toEqual([]);
 db.query("INSERT INTO pvp_events (match_id,seq,kind,visibility,payload_json,created_at) VALUES (?,?,?,'public',?,?)").run(match,last+1,"damage",JSON.stringify({kind:"damage",side:"left",target_side:"right",spell_id:"cinder_fist",show_spell_link:false,effectiveness:1.12,spell_meta:{internal:"secret"}}),now);
 const safe=service.state(match,"b",last).events[0]; expect(safe.effectiveness).toBe(1.12); expect(safe.show_spell_link).toBe(false); expect(safe.spell_meta).toBeUndefined();
 expect(()=>service.state(match,"c")).toThrow("MATCH_NOT_FOUND");
 now+=60000; expect(service.state(match,"a").result.result).toBe("draw");
 expect(service.state(match,"b").result.result).toBe("draw"); db.close();
});

test("missing decisions forfeit and pending Inspiration auto-declines on timeout", () => {
 const db=new Database(":memory:"); db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for(const name of ["0011_pvp.sql","0012_pvp_seasons.sql","0013_pvp_match_data.sql"]) db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite",name),"utf8"));
 for(const id of ["a","b"]) db.query("INSERT INTO players VALUES (?, ?)").run(id,id);
 let now=100; const queue=createPvpQueue(db,catalogs,id=>snapshot(id),()=>now); queue.join("a",{});
 let id=(queue.join("b",{}) as any).match_id; const service=createPvpMatches(db,new Uint8Array(32).fill(7),()=>now);
 service.decide(id,"a","a1",1,{turn:1,spell_id:"cinder_fist"}); now+=60000;
 expect(service.state(id,"a").result.result).toBe("win"); expect(service.state(id,"b").result.result).toBe("loss");
 queue.join("a",{}); id=(queue.join("b",{}) as any).match_id;
 const row=db.query("SELECT combat_state_json FROM pvp_matches WHERE match_id = ?").get(id) as any, state=JSON.parse(row.combat_state_json);
 for(const side of ["left","right"]) { const f=state.fighters[side]; f.inspiration=3; f.inspiration_pending=true; f.inspiration_offers=f.inspiration_catalog.slice(0,3).map((s: any)=>s.id); }
 db.query("UPDATE pvp_matches SET combat_state_json = ? WHERE match_id = ?").run(JSON.stringify(state),id);
 expect(service.state(id,"a").enemy.inspiration_offers).toBeUndefined();
 now+=60000; const after=service.state(id,"a"); expect(after.status).toBe("ACTIVE"); expect(after.turn).toBe(0); expect(after.player.inspiration_pending).toBe(false); expect(after.enemy.inspiration_pending).toBe(false); expect(after.combat_revision).toBe(2);
 db.close();
});
