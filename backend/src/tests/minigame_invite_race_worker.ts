import {Database} from 'bun:sqlite';
import {createCoreDefenseLobby} from '../woe/core_defense_lobby';
import {createWoeLobby} from '../woe/lobby';
import {createMinigameInvitations} from '../social/minigame_invitations';
const [path,player,invite,now]=process.argv.slice(2);const db=new Database(path);db.exec('PRAGMA busy_timeout=5000');const can=()=>true,clock=()=>Number(now),cd=createCoreDefenseLobby(db,()=> 'duel_clearing',can,clock),woe=createWoeLobby(db,()=> 'duel_clearing',can,clock),service=createMinigameInvitations(db,{canServe:can,enabled:can,online:can,join:{woe:woe.joinFromInvitation,core_defense:cd.joinFromInvitation},clock});const result=service.respond(player,{invite_id:invite,accept:true,client_action_id:`${now}:race`});console.log(JSON.stringify({status:result.status,error:result.data.error??null}));db.close();
