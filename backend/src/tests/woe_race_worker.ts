import {Database} from 'bun:sqlite';
import {createWoeLobby} from '../woe/lobby';
import {createForestDuels} from '../forest/duels';
const db=new Database(process.env.WOE_RACE_DB!);db.exec('PRAGMA busy_timeout=5000');
const deadline=Number(process.env.WOE_RACE_AT);while(Date.now()<deadline) await Bun.sleep(2);
const now=1000000;
const result=process.env.WOE_RACE_KIND==='woe' ? createWoeLobby(db,()=> 'duel_clearing',()=>true,()=>now).create('a',{mode:'1v1',client_action_id:'race'}) : createForestDuels(db,()=> 'duel_clearing',()=>true,()=>now).request('a',{target_player_id:'b',client_action_id:'race'});
console.log(JSON.stringify(result));db.close();
