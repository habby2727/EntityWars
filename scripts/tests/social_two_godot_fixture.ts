import { Database } from 'bun:sqlite';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createServer } from 'node:net';
import assert from 'node:assert/strict';

const root = resolve(import.meta.dir, '../..'), backend = join(root, 'backend');
const dir = mkdtempSync(join(tmpdir(), 'ew-social-godot-'));
const dbPath = join(dir, 'test.sqlite'), db = new Database(dbPath);
for (const file of readdirSync(join(backend, 'migrations/sqlite')).filter(f => f.endsWith('.sql')).sort()) db.exec(readFileSync(join(backend, 'migrations/sqlite', file), 'utf8'));
db.close();
const port = await new Promise<number>((done, fail) => { const server = createServer(); server.once('error', fail); server.listen(0, '127.0.0.1', () => { const value = (server.address() as any).port; server.close(() => done(value)); }); });
const base = `http://127.0.0.1:${port}`;
const server = Bun.spawn([process.execPath, 'src/index.ts'], {cwd: backend, env: {...process.env, NODE_ENV:'test', BUN_ENV:'test', HOST:'127.0.0.1', PORT:String(port), DB_PATH:dbPath, DATABASE_URL:'postgres://x:x@127.0.0.1:1/test', REDIS_URL:'redis://127.0.0.1:1', AUTH_ACCOUNT_TIMEOUT_MS:'100', LOGIN_RATE_LIMIT_MAX:'100', SOCIAL_ENABLED:'1'}, stdout:'ignore', stderr:'ignore'});
const godots: {proc: ReturnType<typeof Bun.spawn>; log: string}[] = [];
try {
 let ready = false;
 for (let i=0; i<100; i++) { try { if ((await fetch(base+'/health')).ok) { ready=true; break; } } catch {} await Bun.sleep(100); }
 assert(ready, 'Backend did not start');
 const accounts = [];
 for (const username of ['SocialAlice', 'SocialBob']) {
  const res = await fetch(base+'/auth/register', {method:'POST', headers:{'content-type':'application/json'}, body:JSON.stringify({username,password:'secret1'})});
  assert.equal(res.status, 200); const data: any = await res.json();
  const state = await fetch(base+'/social/state', {headers:{Authorization:`Bearer ${data.token}`}});
  accounts.push({token:data.token, id:(await state.json() as any).player_id});
 }
 const exe = process.env.GODOT_BIN || join(process.env.USERPROFILE || '', 'Desktop', 'Godot_v4.6.exe');
 for (let i=0; i<2; i++) {
  const log = join(dir, `godot${i}.log`);
  const proc = Bun.spawn([exe, '--headless', '--path', root, '--log-file', log, '--script', 'res://scripts/tests/smoke_social_http.gd'], {cwd:root, env:{...process.env, SOCIAL_TEST_URL:base, SOCIAL_TEST_ID:accounts[i].id, SOCIAL_TEST_TOKEN:accounts[i].token, SOCIAL_TEST_OTHER:accounts[1-i].id, SOCIAL_TEST_ROLE:i === 0 ? 'a' : 'b'}, stdout:'ignore', stderr:'ignore'});
  godots.push({proc, log});
 }
 let timer: ReturnType<typeof setTimeout>;
 const exits = await Promise.race([Promise.all(godots.map(g => g.proc.exited)), new Promise<never>((_, fail) => {timer = setTimeout(() => fail(new Error('Godot social test timed out')), 35000);})]);
 clearTimeout(timer!);
 for (const g of godots) console.log(readFileSync(g.log, 'utf8'));
 assert.deepEqual(exits, [0, 0]);
 console.log('Two authenticated Godot social clients: passed');
} finally {
 for (const g of godots) if (g.proc.exitCode === null) {g.proc.kill(); await g.proc.exited;}
 server.kill(); await server.exited;
 for (let i=0;;i++) {try {rmSync(dir, {recursive:true, force:true}); break;} catch (error) {if (i>=20) throw error; await Bun.sleep(250);}}
}
