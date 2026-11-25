import { cardById, cardCost, potionById, elementalMultiplier } from './catalog';
import { validateDeployment, type DeploymentCommand, type MatchState, type Lane } from './engine';

// Only own hand and visible units/labs enter the score. Stable ties spread controllers across lanes.
export function chooseBotDeployment(state: MatchState, id: string, options?: { validate: (state: MatchState, command: DeploymentCommand) => string | null; element: (cardId: string) => typeof cardById[string]['element'] }): DeploymentCommand | null {
 const p=state.controllers.find(c=>c.id===id); if(!p || state.result)return null;
 const alliesAlive=state.units.filter(u=>u.hp>0&&u.team===p.team).length;
 const enemiesAlive=state.units.filter(u=>u.hp>0&&u.team!==p.team).length;
 if(alliesAlive>enemiesAlive || (alliesAlive===0 && enemiesAlive===0 && state.tick<50))return null;
 const choices: {cmd:DeploymentCommand;score:number}[]=[];
 const bias=[...id].reduce((n,c)=>(n*33+c.charCodeAt(0))>>>0,0);
 const enemiesVisible=state.units.filter(u=>u.hp>0&&u.team!==p.team).sort((a,b)=>a.id-b.id);
 for(let slot=0;slot<p.slots.length;slot++){
  const potion=potionById[p.slots[slot]];if(!potion)continue;
  for(const center of enemiesVisible){
   const targets=enemiesVisible.filter(u=>(u.position.x-center.position.x)**2+(u.position.y-center.position.y)**2<=potion.radius**2 && (potion.id==='thunderlock'?(u.paralyzedUntil??0)<=state.tick:(u.poisonUntil??0)<=state.tick));
   if(targets.length<2)continue;
   const cmd={actionId:`bot:${state.tick}:${id}`,controllerId:id,slot,cardId:potion.id,target_x:center.position.x,target_y:center.position.y};
   if((options?.validate ?? validateDeployment)(state,cmd))continue;
   choices.push({cmd,score:targets.length*5-potion.cost*0.12-slot*0.001});
  }
 }
 if(alliesAlive!==enemiesAlive || alliesAlive<3)for(const lane of ['left','right'] as Lane[]) for(let slot=0;slot<p.slots.length;slot++) {
  if(!cardById[p.slots[slot]])continue;
  const card=cardById[p.slots[slot]], cmd={actionId:`bot:${state.tick}:${id}`,controllerId:id,slot,cardId:card.id,lane};
  if((options?.validate ?? validateDeployment)(state,cmd))continue;
  const enemies=state.units.filter(u=>u.hp>0&&u.team!==p.team&&u.lane===lane), allies=state.units.filter(u=>u.hp>0&&u.team===p.team&&u.lane===lane);
  const lab=state.laboratories.find(l=>l.team===p.team&&l.lane===lane)!;
  const counters=enemies.reduce((n,u)=>n+elementalMultiplier(card.element,(options?.element ? options.element(u.cardId) : cardById[u.cardId].element))-1,0);
  const threat=enemies.reduce((n,u)=>n+Math.max(0,1-Math.abs(u.position.y-lab.position.y)/700),0);
  const score=threat*5+enemies.length*1.5-allies.length*1.2+(1-lab.hp/lab.maxHp)*3+counters*4+cardCost(card,state.kind)*0.12+((bias+state.tick/10)%2===(lane==='left'?0:1)?0.3:0)-slot*0.001;
  choices.push({cmd,score});
 }
 choices.sort((a,b)=>b.score-a.score);return choices[0]?.cmd??null;
}
