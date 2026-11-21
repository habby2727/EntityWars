import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createHmac } from "node:crypto";
import { createExpeditionService, EXPEDITION_LEASE_EXPIRY_MS, EXPEDITION_MAX_REVISION } from "../expeditions_service";

test("leases expire and different client instances abandon atomically", () => {
  const db=new Database(":memory:");
  const dir=resolve(import.meta.dir,"../../migrations/sqlite");
  for(const file of readdirSync(dir).filter(f=>f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(dir,file),"utf8"));
  const options={db,secret:"secret",catalogs:{},getPlayer:()=>({}),makeSetup:()=>({}),awardVictory:()=>{},captureHomunculus:()=>({duplicate:false})};
  let service=createExpeditionService(options);
  const lease="a".repeat(64), hash=createHmac("sha256","secret").update("expedition-lease:"+lease).digest("hex");
  const create=(id:string,mana:number,heartbeat:number,phase="EXPLORE")=>{
    db.query("INSERT INTO expedition_balances(player_id,mana,crystals,regen_at) VALUES(?,?,2,?)").run(id,mana,mana===6?0:Date.now()+1800000);
    db.query("INSERT INTO expedition_runs(run_id,player_id,status,revision,loadout_json,state_json,started_at,updated_at,lease_hash,heartbeat_at) VALUES(?,?,'ACTIVE',1,'{}',?,?,?,?,?)").run(id,id,JSON.stringify({phase,depth:1,choices:[],log:[]}),heartbeat,heartbeat,hash,heartbeat);
  };
  create("alive",6,Date.now());
  expect(service.state("alive",lease).session?.run_id).toBe("alive");
  const beat=service.heartbeat("alive",lease,{run_id:"alive"});
  expect(beat.expires_at-beat.server_time_unix_ms).toBe(EXPEDITION_LEASE_EXPIRY_MS);
  service=createExpeditionService(options); // server process restart keeps the persisted deadline
  expect(service.state("alive",lease).session?.run_id).toBe("alive");
  expect(service.state("alive",null).session).toBeNull(); // new client instance has no lease
  expect((db.query("SELECT status FROM expedition_runs WHERE run_id='alive'").get() as any).status).toBe("ABANDONED");
  expect((db.query("SELECT mana FROM expedition_balances WHERE player_id='alive'").get() as any).mana).toBe(5);
  expect(()=>service.heartbeat("alive",lease,{run_id:"alive"})).toThrow();
  expect(()=>service.action("alive","select",{run_id:"alive",expected_revision:1,choice:0,client_action_id:"stale"},lease)).toThrow();
  expect((db.query("SELECT mana FROM expedition_balances WHERE player_id='alive'").get() as any).mana).toBe(5);
  expect(service.state("alive",lease).remaining_cooldown_ms).toBeGreaterThan(59000);
  create("expired",1,Date.now()-EXPEDITION_LEASE_EXPIRY_MS,"COMBAT");
  expect(()=>service.heartbeat("expired",lease,{run_id:"expired"})).toThrow();
  expect((db.query("SELECT mana FROM expedition_balances WHERE player_id='expired'").get() as any).mana).toBe(0);
  expect(service.expireLeases()).toBe(0);
  create("zero",0,Date.now()-EXPEDITION_LEASE_EXPIRY_MS,"REWARD");
  expect(service.expireLeases()).toBe(1);
  expect(service.expireLeases()).toBe(0);
  expect((db.query("SELECT mana,crystals FROM expedition_balances WHERE player_id='zero'").get() as any)).toEqual({mana:0,crystals:2});
  create("late",6,Date.now()-EXPEDITION_LEASE_EXPIRY_MS-61000);
  const late=service.state("late",lease);
  expect(late.session).toBeNull(); expect(late.mana).toBe(5); expect(late.remaining_cooldown_ms).toBe(0);
  create("wrong",6,Date.now(),"ROUTE");
  expect(()=>service.action("wrong","exit",{run_id:"wrong",expected_revision:1,client_action_id:"x"},"b".repeat(64))).toThrow();
  expect((db.query("SELECT status FROM expedition_runs WHERE run_id='wrong'").get() as any).status).toBe("ABANDONED");
  create("capped",6,Date.now());
  db.query("UPDATE expedition_runs SET revision=? WHERE run_id='capped'").run(EXPEDITION_MAX_REVISION);
  expect(()=>service.action("capped","select",{run_id:"capped",expected_revision:EXPEDITION_MAX_REVISION,choice:0,client_action_id:"cap"},lease)).toThrow();
  expect((db.query("SELECT status FROM expedition_runs WHERE run_id='capped'").get() as any).status).toBe("ABANDONED");
  db.close();
});
