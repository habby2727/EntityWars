import { readFileSync } from "node:fs";
import { resolve } from "node:path";

type Point = [number, number];
type Direction = "north" | "south" | "east" | "west";
type Portal = { id: string; direction: Direction; corridor: [number, number, number, number]; destination: string; arrival: Point };
export type Zone = { id: string; polygon: Point[]; spawn: Point; portals: Portal[] };
type Catalog = { version: number; width: number; height: number; zones: Zone[] };
const opposite: Record<Direction, Direction> = { north: "south", south: "north", east: "west", west: "east" };
const finitePoint = (p: unknown): p is Point => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite);
const cross = (a: Point, b: Point, c: Point) => (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
export function inside(p: Point, poly: Point[]): boolean {
 let hit = false;
 for (let i=0,j=poly.length-1;i<poly.length;j=i++) {
  const a=poly[j], b=poly[i];
  if (Math.abs(cross(a,b,p)) < 1e-7 && p[0]>=Math.min(a[0],b[0])-1e-7 && p[0]<=Math.max(a[0],b[0])+1e-7 && p[1]>=Math.min(a[1],b[1])-1e-7 && p[1]<=Math.max(a[1],b[1])+1e-7) return true;
  if ((a[1]>p[1]) !== (b[1]>p[1]) && p[0] < (b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]) hit=!hit;
 }
 return hit;
}
// Split at every polygon edge intersection; checking each interval detects concave wall crossings.
export function segmentInside(a: Point,b: Point,poly: Point[]): boolean {
 if (!inside(a,poly) || !inside(b,poly)) return false;
 const dx=b[0]-a[0],dy=b[1]-a[1], ts=[0,1];
 for(let i=0;i<poly.length;i++) {
  const c=poly[i],d=poly[(i+1)%poly.length], ex=d[0]-c[0],ey=d[1]-c[1], den=dx*ey-dy*ex;
  if(Math.abs(den)<1e-10) continue;
  const t=((c[0]-a[0])*ey-(c[1]-a[1])*ex)/den, u=((c[0]-a[0])*dy-(c[1]-a[1])*dx)/den;
  if(t>0 && t<1 && u>=0 && u<=1) ts.push(t);
 }
 ts.sort((x,y)=>x-y);
 return ts.slice(1).every((t,i)=>{const m=(t+ts[i])/2; return inside([a[0]+dx*m,a[1]+dy*m],poly);});
}
export function validateCatalog(c: Catalog): Map<string,Zone> {
 if (!c || c.version!==1 || c.width!==1920 || c.height!==1080 || !Array.isArray(c.zones) || c.zones.length!==6) throw Error("Invalid forest catalog");
 const zones=new Map<string,Zone>();
 for(const z of c.zones) {
  if(!z || typeof z.id!=="string" || !/^[a-z_]+$/.test(z.id) || zones.has(z.id) || !Array.isArray(z.polygon) || z.polygon.length<3 || z.polygon.length>100 || !z.polygon.every(p=>finitePoint(p)&&p[0]>=0&&p[0]<=1920&&p[1]>=0&&p[1]<=1080) || !finitePoint(z.spawn) || !inside(z.spawn,z.polygon) || !Array.isArray(z.portals)) throw Error("Invalid forest zone");
  let area=0; for(let i=0;i<z.polygon.length;i++){const a=z.polygon[i],b=z.polygon[(i+1)%z.polygon.length]; if(a[0]===b[0]&&a[1]===b[1]) throw Error("Invalid polygon"); area+=a[0]*b[1]-b[0]*a[1];}
  if(Math.abs(area)<1) throw Error("Invalid polygon");
  for(let i=0;i<z.polygon.length;i++) for(let j=i+1;j<z.polygon.length;j++) {
   if(j===i+1 || (i===0 && j===z.polygon.length-1)) continue;
   const a=z.polygon[i],b=z.polygon[(i+1)%z.polygon.length],c=z.polygon[j],d=z.polygon[(j+1)%z.polygon.length];
   const ab1=cross(a,b,c),ab2=cross(a,b,d),cd1=cross(c,d,a),cd2=cross(c,d,b);
   if(ab1*ab2<=0 && cd1*cd2<=0 && Math.max(Math.min(a[0],b[0]),Math.min(c[0],d[0]))<=Math.min(Math.max(a[0],b[0]),Math.max(c[0],d[0])) && Math.max(Math.min(a[1],b[1]),Math.min(c[1],d[1]))<=Math.min(Math.max(a[1],b[1]),Math.max(c[1],d[1]))) throw Error("Self-intersecting forest polygon");
  }
  zones.set(z.id,z);
 }
 let count=0;
 for(const z of zones.values()) { const dirs=new Set<string>(); for(const p of z.portals) {
  const dest=zones.get(p.destination), dir=p.direction;
  if(!Object.hasOwn(opposite,dir) || p.id!==dir || dirs.has(dir) || !Array.isArray(p.corridor) || p.corridor.length!==4 || !p.corridor.every(Number.isFinite) || p.corridor[0]<0 || p.corridor[1]<0 || p.corridor[2]>1920 || p.corridor[3]>1080 || p.corridor[0]>=p.corridor[2] || p.corridor[1]>=p.corridor[3] || !dest || !finitePoint(p.arrival) || !inside(p.arrival,dest.polygon) || !dest.portals.some(q=>q.destination===z.id && q.direction===opposite[dir])) throw Error("Invalid forest portal");
  if ((dir==='north' && p.corridor[1]!==0) || (dir==='south' && p.corridor[3]!==1080) || (dir==='west' && p.corridor[0]!==0) || (dir==='east' && p.corridor[2]!==1920)) throw Error("Invalid portal boundary");
  dirs.add(dir); count++;
 }}
 if(count!==10 || !zones.has('central_clearing') || !inside([960,760],zones.get('central_clearing')!.polygon)) throw Error("Invalid forest graph");
 return zones;
}
export function loadCatalog(path = resolve(import.meta.dir, "../../../data/static/forest_zones.json")): Map<string,Zone> { return validateCatalog(JSON.parse(readFileSync(path,"utf8"))); }

type Socket = { send(data:string): number; close(code?:number, reason?:string): void; data: ForestData; getBufferedAmount(): number };
export type ForestData = { kind: "forest"; playerId:string; displayName:string; token:string };
type State = { player_id:string; display_name:string; zone_id:string; x:number; y:number; facing:number; summoner_id:string };
type Session = { ws:Socket; state:State; entered:boolean; seq:number; at:number; credit:number; lastMove:number; pendingMove: {seq:number; x:number; y:number; facing:number} | null; lastCosmetic:number; rateAt:number; rate:number; malformed:number; checking:boolean; busyProtocol:boolean };
type Saved = { state:State; expires:number };
type Busy = { state:State; auth:ForestData; expires:number; checking:boolean };
const BUSY_LEASE_MS = 90_000, MAX_BUSY = 768;
const cosmetics=new Set(['wizard','witch','cyberghost']);
export function createForestPresence(zones:Map<string,Zone>, authenticate:(data:ForestData)=>Promise<boolean>, clock:()=>number=Date.now, canServe:()=>boolean=()=>true) {
 const rooms=new Map<string,Map<string,Session>>([...zones.keys()].map(id=>[id,new Map()]));
 const active=new Map<string,Session>(), saved=new Map<string,Saved>(), busy=new Map<string,Busy>();
 let fenced=false;
 const prune=()=>{const now=clock(); for(const [id,s] of saved) if(s.expires<=now) saved.delete(id); for(const [id,b] of busy) if(b.expires<=now) dropBusy(id,b);};
 const send=(s:Session,m:object)=>{if(fenced || !canServe())return;try { if(s.ws.getBufferedAmount()>65536) { s.ws.close(1008,'slow client'); remove(s,120000); return; } if(s.ws.send(JSON.stringify({v:1,...m}))<0) {s.ws.close(1008,'slow client'); remove(s,120000);} } catch {remove(s,120000);} };
 const broadcast=(s:Session,m:object)=>{if(fenced || !canServe())return;for(const peer of rooms.get(s.state.zone_id)!.values()) if(peer!==s) send(peer,m);};
 const busyNotice=(b:Busy, entering:boolean)=>{ if(fenced || !canServe())return; for(const peer of rooms.get(b.state.zone_id)!.values()) { if(peer.state.player_id===b.state.player_id) continue; if(peer.busyProtocol) send(peer,{type:'peer_busy',player:{...b.state,busy:!entering}}); else send(peer,entering?{type:'peer_join',player:{...b.state}}:{type:'peer_leave',player_id:b.state.player_id}); } };
 function dropBusy(id:string,b:Busy){if(busy.get(id)!==b)return;busy.delete(id);if(fenced || !canServe())return;for(const peer of rooms.get(b.state.zone_id)!.values()) if(peer.busyProtocol && peer.state.player_id!==id)send(peer,{type:'peer_leave',player_id:id});}
 const countRoom=(zone:string)=>rooms.get(zone)!.size+[...busy.values()].filter(b=>b.state.zone_id===zone).length;
 const peers=(s:Session)=>[...rooms.get(s.state.zone_id)!.values()].filter(p=>p!==s).map(p=>({...p.state})).concat(s.busyProtocol ? [...busy.values()].filter(b=>b.state.zone_id===s.state.zone_id && b.state.player_id!==s.state.player_id).map(b=>({...b.state,busy:true})) : []);
 function remove(s:Session,ttl:number) { if(fenced || !canServe() || active.get(s.state.player_id)!==s) return; active.delete(s.state.player_id); if(s.entered){rooms.get(s.state.zone_id)!.delete(s.state.player_id); broadcast(s,{type:'peer_leave',player_id:s.state.player_id});} if(ttl){prune(); if(saved.size>=1024) saved.delete(saved.keys().next().value!); saved.set(s.state.player_id,{state:{...s.state},expires:clock()+ttl});} else saved.delete(s.state.player_id); }
 const correction=(s:Session,seq:unknown,reason:string)=>send(s,{type:'correction',seq:Number.isSafeInteger(seq)?seq:0,zone_id:s.state.zone_id,x:s.state.x,y:s.state.y,facing:s.state.facing,reason});
 const validSeq=(n:unknown):n is number=>Number.isSafeInteger(n) && (n as number)>=0 && (n as number)<=2147483647;
 function open(ws:Socket) {
  if(fenced || !canServe()){ws.close(1011,'service unavailable');return;}
  prune(); const old=active.get(ws.data.playerId); if(old){remove(old,120000); old.ws.close(1000,'replaced');}
  if(active.size>=512){ws.close(1013,'capacity');return;}
  const occupied=busy.get(ws.data.playerId), previous=saved.get(ws.data.playerId); if(!occupied) saved.delete(ws.data.playerId);
  const state:State=occupied ? {...occupied.state,display_name:ws.data.displayName} : previous ? {...previous.state,display_name:ws.data.displayName} : {player_id:ws.data.playerId,display_name:ws.data.displayName,zone_id:'central_clearing',x:960,y:760,facing:0,summoner_id:'wizard'};
  active.set(state.player_id,{ws,state,entered:false,seq:-1,at:clock(),credit:24,lastMove:0,pendingMove:null,lastCosmetic:0,rateAt:clock(),rate:0,malformed:0,checking:false,busyProtocol:false});
 }
 function message(ws:Socket,raw:string|Buffer) {
  if(fenced || !canServe())return;
  const s=active.get(ws.data.playerId); if(!s || s.ws!==ws)return;
  const now=clock(); if(now-s.rateAt>=1000){s.rateAt=now;s.rate=0;} if(++s.rate>30){ws.close(1008,'rate limit');remove(s,120000);return;}
  if(typeof raw!=='string' || Buffer.byteLength(raw)>2048){ws.close(1009,'invalid frame');remove(s,120000);return;}
  let m:any; try {m=JSON.parse(raw);} catch {if(++s.malformed>=3){ws.close(1008,'invalid message');remove(s,120000);} return;}
  if(!m || typeof m!=='object' || Array.isArray(m) || m.v!==1 || typeof m.type!=='string'){if(++s.malformed>=3){ws.close(1008,'invalid message');remove(s,120000);}return;}
  if(m.type==='ping'){send(s,{type:'pong',server_time:now});return;}
  if(m.type==='leave' || m.type==='suspend'){
   const kind=m.type; prune();
   if(kind==='suspend' && s.entered && busy.size<MAX_BUSY) {
    active.delete(s.state.player_id); rooms.get(s.state.zone_id)!.delete(s.state.player_id); s.pendingMove=null;
    prune(); if(saved.size>=1024) saved.delete(saved.keys().next().value!);
    saved.set(s.state.player_id,{state:{...s.state},expires:now+900000});
    const record:Busy={state:{...s.state},auth:{...ws.data},expires:now+BUSY_LEASE_MS,checking:false}; busy.set(s.state.player_id,record); busyNotice(record,false);
   } else { remove(s,kind==='leave'?0:900000); if(kind==='leave') {const record=busy.get(s.state.player_id);if(record)dropBusy(s.state.player_id,record);} }
   send(s,{type:'handoff_ack',kind});
   // Godot can discard unread data when it receives the close frame in the same poll.
   // The client closes after the ACK; old clients still receive a bounded server close.
   setTimeout(()=>{try{ws.close(1000,kind==='leave'?'left':'suspended');}catch{}},500).unref();return;
  }
  if(m.type==='enter'){
   if(s.entered || !cosmetics.has(m.summoner_id)){send(s,{type:'error',error:'INVALID_ENTER'});return;}
   prune(); const ownBusy=busy.get(s.state.player_id); if(ownBusy) s.state={...ownBusy.state,display_name:ws.data.displayName};
   const room=rooms.get(s.state.zone_id)!; if(countRoom(s.state.zone_id)-(ownBusy?1:0)>=128){send(s,{type:'error',error:'ROOM_FULL'});return;}
   s.busyProtocol=m.busy_protocol===1; s.state.summoner_id=m.summoner_id; s.entered=true;s.at=now; s.seq=-1;
   if(ownBusy){busy.delete(s.state.player_id);saved.delete(s.state.player_id);} room.set(s.state.player_id,s);
   send(s,{type:'welcome',self:{...s.state},peers:peers(s),server_time:now});
   if(active.get(s.state.player_id)===s) {if(ownBusy)busyNotice({...ownBusy,state:{...s.state}},true);else broadcast(s,{type:'peer_join',player:{...s.state}});}return;
  }
  if(!s.entered){send(s,{type:'error',error:'ENTER_REQUIRED'});return;}
  if(m.type==='cosmetic'){if(!cosmetics.has(m.summoner_id)){send(s,{type:'error',error:'INVALID_COSMETIC'});return;} if(now-s.lastCosmetic>=200 && s.state.summoner_id!==m.summoner_id){s.lastCosmetic=now;s.state.summoner_id=m.summoner_id;broadcast(s,{type:'peer_cosmetic',player_id:s.state.player_id,summoner_id:m.summoner_id});}return;}
  if(m.type!=='move' && m.type!=='portal'){send(s,{type:'error',error:'UNKNOWN_TYPE'});return;}
  if(!validSeq(m.seq) || m.seq<=s.seq){correction(s,m.seq,'INVALID_SEQ');return;} s.seq=m.seq;
  const x=m.type==='move'?m.x:m.crossing_x, y=m.type==='move'?m.y:m.crossing_y;
  if(!Number.isFinite(x)||!Number.isFinite(y)||x<0||x>1920||y<0||y>1080 || (m.type==='move' && (!Number.isInteger(m.facing)||m.facing<0||m.facing>3))){correction(s,m.seq,'INVALID_POSITION');return;}
  const a:Point=[s.state.x,s.state.y],b:Point=[x,y],zone=zones.get(s.state.zone_id)!;
  s.credit=Math.min(79,s.credit+Math.max(0,now-s.at)*0.22);s.at=now;
  const distance=Math.hypot(x-a[0],y-a[1]);
  if(distance>s.credit || !segmentInside(a,b,zone.polygon)){correction(s,m.seq,'INVALID_MOVEMENT');return;}
  if(m.type==='move'){
   s.credit-=distance;s.state.x=x;s.state.y=y;s.state.facing=m.facing;
   s.pendingMove={seq:m.seq,x,y,facing:m.facing};
   if(now-s.lastMove>=200) flushSession(s,now);
   return;
  }
  const p=zone.portals.find(p=>p.direction===m.direction);
  if(!p || x<p.corridor[0] || x>p.corridor[2] || y<p.corridor[1] || y>p.corridor[3] || !((p.direction==='north'&&y===0&&a[1]>y)||(p.direction==='south'&&y===1080&&a[1]<y)||(p.direction==='west'&&x===0&&a[0]>x)||(p.direction==='east'&&x===1920&&a[0]<x))){correction(s,m.seq,'INVALID_PORTAL');return;}
  prune(); const destination=rooms.get(p.destination)!; if(countRoom(p.destination)>=128){correction(s,m.seq,'ROOM_FULL');return;}
  s.pendingMove=null;
  rooms.get(s.state.zone_id)!.delete(s.state.player_id);broadcast(s,{type:'peer_leave',player_id:s.state.player_id});
  s.state.zone_id=p.destination;[s.state.x,s.state.y]=p.arrival;s.credit=0;s.at=now;destination.set(s.state.player_id,s);
  send(s,{type:'zone',zone_id:s.state.zone_id,x:s.state.x,y:s.state.y,facing:s.state.facing,peers:peers(s)});if(active.get(s.state.player_id)===s) broadcast(s,{type:'peer_join',player:{...s.state}});
 }
 function flushSession(s:Session,now:number){if(!s.pendingMove || !s.entered || now-s.lastMove<200)return;const move=s.pendingMove;s.pendingMove=null;s.lastMove=now;broadcast(s,{type:'peer_move',player_id:s.state.player_id,...move});}
 function flush(){if(fenced || !canServe())return;const now=clock();for(const s of active.values())flushSession(s,now);}
 async function sweep(){if(fenced || !canServe())return;prune(); await Promise.all([...active.values()].map(async s=>{if(s.checking)return;s.checking=true;try{if(!await authenticate(s.ws.data) && !fenced && canServe() && active.get(s.state.player_id)===s)evict(s.state.player_id);}catch{if(!fenced && canServe() && active.get(s.state.player_id)===s){remove(s,0);const b=busy.get(s.state.player_id);if(b)dropBusy(s.state.player_id,b);s.ws.close(1011,'authentication unavailable');}}finally{s.checking=false;}}).concat([...busy.values()].map(async b=>{if(b.checking)return;b.checking=true;const auth=b.auth;try{if(!await authenticate(auth) && b.auth===auth && !fenced && canServe() && busy.get(b.state.player_id)===b){saved.delete(b.state.player_id);dropBusy(b.state.player_id,b);}}catch{if(b.auth===auth && !fenced && canServe() && busy.get(b.state.player_id)===b){saved.delete(b.state.player_id);dropBusy(b.state.player_id,b);}}finally{b.checking=false;}})));}
 function evict(playerId:string){if(fenced || !canServe())return;const s=active.get(playerId);if(s){remove(s,0);s.ws.close(1008,'session ended');}saved.delete(playerId);const b=busy.get(playerId);if(b)dropBusy(playerId,b);}
 function fence(){if(fenced)return;fenced=true;for(const s of active.values()){try{s.ws.close(1011,'service unavailable');}catch{}}active.clear();saved.clear();busy.clear();for(const room of rooms.values())room.clear();}
 function peerChat(playerId:string, message:{id:number;player_id:string;text:string;created_at:number}) {
  if(fenced || !canServe() || message.player_id!==playerId || !Number.isSafeInteger(message.id) || !Number.isSafeInteger(message.created_at) || typeof message.text!=='string') return;
  const session=active.get(playerId);
  if(!session?.entered || rooms.get(session.state.zone_id)?.get(playerId)!==session) return;
  const event={type:'peer_chat',player_id:playerId,message_id:message.id,text:message.text,created_at:message.created_at,expires_at:message.created_at+10_000,server_time:clock()};
  send(session,event); broadcast(session,event);
 }
 return {open,message,peerChat,positionOf(playerId:string):{zone_id:string;x:number;y:number}|null {if(fenced || !canServe() || busy.has(playerId))return null;const s=active.get(playerId);return s?.entered && rooms.get(s.state.zone_id)?.get(playerId)===s ? {zone_id:s.state.zone_id,x:s.state.x,y:s.state.y} : null;},renewBusy(playerId:string,token:string){if(fenced || !canServe() || !token)return;prune();const b=busy.get(playerId);if(b){b.auth={...b.auth,token};b.expires=clock()+BUSY_LEASE_MS;}},isBusy(playerId:string){if(fenced || !canServe())return false;prune();return busy.has(playerId);},roomOf(playerId:string):string|null {if(fenced || !canServe()) return null;const s=active.get(playerId);return s?.entered && rooms.get(s.state.zone_id)?.get(playerId)===s ? s.state.zone_id : null;},close(ws:Socket){if(fenced)return;const s=active.get(ws.data.playerId);if(s?.ws===ws)remove(s,120000);},sweep,flush,evict,fence};
}
