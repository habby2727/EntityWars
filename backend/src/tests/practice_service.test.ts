import { expect, test } from 'bun:test';
import { Database } from 'bun:sqlite';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createPracticeService } from '../practice_service';
import { trustedPvpSnapshot } from '../pvp/service';

const read = (name:string) => JSON.parse(readFileSync(resolve(import.meta.dir,'../../../data',name),'utf8'));
const catalogs = {entities:read('entities.json').entities,items:read('items.json').items,homunculi:read('homunculi.json').homunculi,spells:read('spells.json').spells,types:read('types.json'),mutations:read('static/mutations.json').mutations,balance:read('static/balance.json').balance};

test('Practice owns combat, replays actions and settles capped XP once', () => {
  const db=new Database(':memory:');
  db.exec(readFileSync(resolve(import.meta.dir,'../../migrations/sqlite/0031_practice.sql'),'utf8'));
  db.exec(`CREATE TABLE pvp_match_players(player_id TEXT,active INTEGER); CREATE TABLE pvp_queue(player_id TEXT,expires_at INTEGER); CREATE TABLE forest_duel_reservations(player_id TEXT,invite_id TEXT); CREATE TABLE forest_duel_invites(invite_id TEXT,status TEXT,expires_at INTEGER); CREATE TABLE dungeon_runs(player_id TEXT,status TEXT,expires_at INTEGER); CREATE TABLE solo_hunt_sessions(player_id TEXT,status TEXT,expires_at INTEGER); CREATE TABLE expedition_runs(player_id TEXT,status TEXT,heartbeat_at INTEGER);`);
  const ids=catalogs.spells.filter((s:any)=>s.type==='sulfur').slice(0,4).map((s:any)=>s.id);
  const hom=catalogs.homunculi[0].id;
  const selection={entity_id:'sulfur_01',weapon_ids:[null,null],homunculus_id:hom,spell_ids:ids,mode:'attack'};
  const player={player_id:'alice',homunculus_progress:{[hom]:{owned:true,level:0,xp:0}},spell_progress:{equipped_by_mode:{attack:{sulfur_01:ids}},learned_by_entity:{}},item_progress:{}};
  let xp=0, grants=0; const now=1_800_000_000_000;
  const service=createPracticeService(db,catalogs,new Uint8Array(32).fill(4),(id,build)=>trustedPvpSnapshot(id,build,player,catalogs),(_id,_snapshot,_now,amount)=>{grants++; const before=Math.floor(xp/100); xp+=amount; return {homunculus_id:hom,xp_granted:amount,level_before:before,level_after:Math.floor(xp/100)};},()=>now);
  expect(()=>service.start('alice','bad',{...selection,entity_id:'missing'})).toThrow('UNTRUSTED_SETUP');
  const start=service.start('alice','start0',selection) as any;
  expect(start.kind).toBe('practice'); expect(start.enemy.spell_ids).toBeUndefined();
  expect(service.start('alice','start0',selection)).toEqual(start);
  expect(()=>service.start('alice','start0',{...selection,entity_id:'missing'})).toThrow('ACTION_CONFLICT');
  expect(()=>service.state('bob',start.match_id,0)).toThrow('MATCH_NOT_FOUND');
  const attack=ids.find((id:string)=>catalogs.spells.find((s:any)=>s.id===id).cooldown_turns===0 && catalogs.spells.find((s:any)=>s.id===id).category==='attack');
  const decision={turn:1,spell_id:attack};
  const exchange=service.decide('alice',start.match_id,'turn0',1,decision) as any;
  expect(exchange.turn).toBe(1); expect(service.decide('alice',start.match_id,'turn0',1,decision)).toEqual(exchange);
  const finish=(id:string, action:string) => {
    const row=db.query('SELECT combat_json,revision FROM practice_sessions WHERE match_id=?').get(id) as any;
    const state=JSON.parse(row.combat_json); state.wins.left=1; state.battle_index=2; state.fighters.right.hp=1; state.fighters.left.hp=state.fighters.left.max_hp; state.fighters.left.status.stun=0; state.fighters.right.status.stun=1; state.fighters.left.inspiration_pending=false; state.fighters.right.inspiration_pending=false; state.fighters.left.spell_cooldowns[attack]=0;
    db.query('UPDATE practice_sessions SET combat_json=? WHERE match_id=?').run(JSON.stringify(state),id);
    const choice={turn:state.turn+1,spell_id:attack};
    const result=service.decide('alice',id,action,row.revision,choice) as any;
    expect(result.result.result).toBe('win'); expect(service.decide('alice',id,action,row.revision,choice)).toEqual(result); return result;
  };
  expect(finish(start.match_id,'finish0').result.homunculus_xp.xp_granted).toBe(20);
  const abandoned=service.start('alice','abandon-start',selection) as any;
  expect((service.forfeit('alice',abandoned.match_id,'abandon') as any).result.homunculus_xp).toBeUndefined();
  expect(xp).toBe(20);
  for (let i=1;i<4;i++) { const session=service.start('alice','start'+i,selection) as any; const result=finish(session.match_id,'finish'+i); if (i===3) expect(result.result.homunculus_xp).toBeUndefined(); }
  expect(xp).toBe(60); expect(grants).toBe(3);
  const last=service.start('alice','forfeit-start',selection) as any;
  const forfeited=service.forfeit('alice',last.match_id,'forfeit') as any;
  expect(forfeited.result.result).toBe('loss'); expect(forfeited.result.homunculus_xp).toBeUndefined();
  expect(service.forfeit('alice',last.match_id,'forfeit')).toEqual(forfeited); expect(xp).toBe(60);
  db.close();
});
