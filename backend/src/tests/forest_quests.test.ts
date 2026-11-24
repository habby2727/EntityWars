import {test,expect} from 'bun:test';
import {Database} from 'bun:sqlite';
import {readFileSync} from 'node:fs';
import {createForestQuests} from '../forest_quests';

test('daily quests are stable, verified, bounded, authorized and claimed atomically',()=>{
 const db=new Database(':memory:');db.exec(readFileSync('migrations/sqlite/0033_forest_quests.sql','utf8'));
 let now=Date.parse('2026-11-24T01:00:00Z'),position:any={zone_id:'zone',x:10,y:10},wallet=0,cap=0;
 const npc={id:'quest_a',zone:'zone',position:[10,10]};
 const service=createForestQuests({db,secret:'test secret',npcs:[npc],clock:()=>now,position:()=>position,grant:(_p,reward)=>{const amount=Object.values(reward)[0];if(wallet+amount>cap)throw Error('full');wallet+=amount;}});
 const a:any=service.get('alice').quest;expect(service.get('alice').quest).toEqual(a);expect(a.reward).toBeUndefined(); const frozen=(db.query('SELECT reward FROM forest_quests WHERE id=?').get(a.quest_id) as any).reward; const db2=new Database(':memory:');db2.exec(readFileSync('migrations/sqlite/0033_forest_quests.sql','utf8'));const second=createForestQuests({db:db2,secret:'test secret',npcs:[npc],clock:()=>now,position:()=>position,grant:()=>{}});expect(second.get('alice').quest).toEqual(a);expect((db2.query('SELECT reward FROM forest_quests').get() as any).reward).toBe(frozen);db2.close();
 expect(()=>service.action('bob','accept',{quest_id:a.quest_id,client_action_id:'a'})).toThrow();
 position={zone_id:'zone',x:400,y:10};expect(()=>service.action('alice','accept',{quest_id:a.quest_id,client_action_id:'a'})).toThrow();position={zone_id:'zone',x:10,y:10};
 db.query("UPDATE forest_quests SET objective='streak',target=2,difficulty='easy',reward=? WHERE id=?").run(JSON.stringify({essence:120}),a.quest_id);
 const accepted=service.action('alice','accept',{quest_id:a.quest_id,client_action_id:'a'});position=null;expect(service.action('alice','accept',{quest_id:a.quest_id,client_action_id:'a'})).toEqual(accepted);expect(()=>service.action('alice','claim',{quest_id:a.quest_id,client_action_id:'a'})).toThrow();
 const victory=(runId:string)=>service.progress({kind:'victory',playerId:'alice',now,runId,depth:1,difficultyDepth:1,tier:'normal',enemyId:'e'});
 victory('run1');victory('run2');expect((db.query('SELECT progress FROM forest_quests').get() as any).progress).toBe(1);victory('run2');expect((db.query('SELECT state FROM forest_quests').get() as any).state).toBe('COMPLETED');
 position={zone_id:'zone',x:10,y:10};expect(()=>service.action('alice','claim',{quest_id:a.quest_id,client_action_id:'b'})).toThrow('full');expect(wallet).toBe(0);cap=200;
 const claimed=service.action('alice','claim',{quest_id:a.quest_id,client_action_id:'b'});position=null;expect(service.action('alice','claim',{quest_id:a.quest_id,client_action_id:'b'})).toEqual(claimed);expect(wallet).toBe(120);
 position={zone_id:'zone',x:10,y:10};now+=86400000;const b:any=service.get('alice').quest;db.query("UPDATE forest_quests SET objective='captures',target=2,difficulty='easy' WHERE id=?").run(b.quest_id);service.action('alice','accept',{quest_id:b.quest_id,client_action_id:'c'});
 const capture={kind:'capture',playerId:'alice',now,runId:'r',depth:1,homunculusId:'h',success:true} as const;service.progress(capture);service.progress(capture);expect((db.query('SELECT state FROM forest_quests WHERE id=?').get(b.quest_id) as any).state).toBe('COMPLETED');
 now+=86400000;const c:any=service.get('alice').quest;service.action('alice','accept',{quest_id:c.quest_id,client_action_id:'d'});now+=12*3600000;service.progress({...capture,now});expect((db.query('SELECT progress FROM forest_quests WHERE id=?').get(c.quest_id) as any).progress).toBe(0);
 db.close();
});
