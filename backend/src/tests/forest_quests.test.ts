import {test,expect} from 'bun:test';
import {Database} from 'bun:sqlite';
import {readFileSync} from 'node:fs';
import {createForestQuests} from '../forest_quests';

test('daily quests are stable, verified, bounded, authorized and claimed atomically',()=>{
 const db=new Database(':memory:');db.exec(readFileSync('migrations/sqlite/0033_forest_quests.sql','utf8'));db.exec(readFileSync('migrations/sqlite/0034_forest_quest_limits.sql','utf8'));
 let now=Date.parse('2026-11-24T01:00:00Z'),position:any={zone_id:'zone',x:10,y:10},wallet=0,cap=0;
 const npc={id:'quest_a',zone:'zone',position:[10,10]};
 const service=createForestQuests({db,secret:'test secret',npcs:[npc],clock:()=>now,position:()=>position,grant:(_p,reward)=>{const amount=Object.values(reward)[0];if(wallet+amount>cap)throw Error('full');wallet+=amount;}});
 const a:any=service.get('alice').quest;expect(service.get('alice').quest).toEqual(a);expect(a.reward).toBeUndefined(); const frozen=(db.query('SELECT reward FROM forest_quests WHERE id=?').get(a.quest_id) as any).reward; const db2=new Database(':memory:');db2.exec(readFileSync('migrations/sqlite/0033_forest_quests.sql','utf8'));db2.exec(readFileSync('migrations/sqlite/0034_forest_quest_limits.sql','utf8'));const second=createForestQuests({db:db2,secret:'test secret',npcs:[npc],clock:()=>now,position:()=>position,grant:()=>{}});expect(second.get('alice').quest).toEqual(a);expect((db2.query('SELECT reward FROM forest_quests').get() as any).reward).toBe(frozen);db2.close();
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

test('active limit, cancellation cooldown, duration and migration normalization',()=>{
 const db=new Database(':memory:');db.exec(readFileSync('migrations/sqlite/0033_forest_quests.sql','utf8'));
 const future=Date.now()+86400000, day=new Date(future).toISOString().slice(0,10);
 const insert=db.query("INSERT INTO forest_quests(id,player_id,npc_id,day,objective,difficulty,target,reward,state,accepted_at,expires_at,progress,progress_data) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)");
 insert.run('a','legacy','a',day,'wins','easy',3,'{}','ACTIVE',1,future,2,'{}');insert.run('b','legacy','b',day,'wins','easy',3,'{}','ACTIVE',2,future,2,'{}');
 db.exec(readFileSync('migrations/sqlite/0034_forest_quest_limits.sql','utf8'));
 expect(db.query("SELECT state,progress,progress_data,accepted_at,expires_at FROM forest_quests WHERE id='b'").get()).toEqual({state:'OFFERED',progress:0,progress_data:'{}',accepted_at:null,expires_at:Date.parse(day+'T00:00:00Z')+86400000});
 let now=Date.parse('2026-11-24T23:00:00Z'),zone='a';const npcs=[{id:'a',zone:'a',position:[0,0]},{id:'b',zone:'b',position:[0,0]}];
 const service=createForestQuests({db,secret:'s',npcs,clock:()=>now,position:()=>({zone_id:zone,x:0,y:0}),grant:()=>{}});
 const a:any=service.get('p').quest;expect(a.available_duration_ms).toBe(3600000);const accepted=service.action('p','accept',{quest_id:a.quest_id,client_action_id:'accept-a'});expect(accepted.quest.expires_at).toBe(now+a.available_duration_ms);
 zone='b';const b:any=service.get('p').quest;expect(()=>service.action('p','accept',{quest_id:b.quest_id,client_action_id:'accept-b'})).toThrow('QUEST_ACTIVE_EXISTS');
 zone='a';db.query("UPDATE forest_quests SET progress=2,progress_data='{}' WHERE id=?").run(a.quest_id);const cancel=service.action('p','cancel',{quest_id:a.quest_id,client_action_id:'cancel-a'});expect(cancel.quest.progress).toBe(0);expect(db.query('SELECT accepted_at,progress_data FROM forest_quests WHERE id=?').get(a.quest_id)).toEqual({accepted_at:null,progress_data:'{}'});
 zone='b';service.action('p','accept',{quest_id:b.quest_id,client_action_id:'accept-b'});now+=3600000;zone='a';const next:any=service.get('p').quest;expect(()=>service.action('p','accept',{quest_id:next.quest_id,client_action_id:'next'})).toThrow('QUEST_CANCEL_COOLDOWN');expect(service.action('p','cancel',{quest_id:a.quest_id,client_action_id:'cancel-a'})).toEqual(cancel);expect((db.query('SELECT cancelled_until FROM forest_quests WHERE id=?').get(a.quest_id) as any).cancelled_until).toBe(cancel.cooldown_until);
 now+=2*3600000;service.action('p','accept',{quest_id:next.quest_id,client_action_id:'next'});db.close();
});
