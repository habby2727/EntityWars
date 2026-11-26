import type { Database } from 'bun:sqlite';

/** Called only after an accepted action, inside the participant's transaction. */
export function recordSpectatorEvents(db:Database, mode:'hunt'|'dungeon', session:string, encounter:string, revision:number, events:unknown[], now:number) {
  if (!Number.isSafeInteger(revision) || revision<1 || !Array.isArray(events)) throw new Error('INVALID_SPECTATOR_EVENTS');
  const insert=db.query('INSERT INTO spectator_events(mode,session_id,encounter,seq,payload_json,created_at) VALUES (?,?,?,?,?,?)');
  events.slice(-511).forEach((event,index)=>insert.run(mode,session,encounter,revision*512+index,JSON.stringify(event),now));
  db.query('DELETE FROM spectator_events WHERE mode=? AND session_id=? AND encounter=? AND seq <= COALESCE((SELECT seq FROM spectator_events WHERE mode=? AND session_id=? AND encounter=? ORDER BY seq DESC LIMIT 1 OFFSET 512),-1)')
    .run(mode,session,encounter,mode,session,encounter);
  db.query('DELETE FROM spectator_events WHERE rowid IN (SELECT rowid FROM spectator_events WHERE created_at<? ORDER BY created_at LIMIT 50)').run(now-86_400_000);
}
