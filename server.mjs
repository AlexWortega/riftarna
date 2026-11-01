import {createServer} from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dirname, extname, join, normalize, sep} from 'node:path';
import {WebSocket, WebSocketServer} from 'ws';

const root = join(dirname(fileURLToPath(import.meta.url)), 'dist');
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.txt':'text/plain; charset=utf-8','.svg':'image/svg+xml'};
const nickPattern = /^[\p{L}\p{N}_-]{2,18}$/u;
const key = value => value.toLocaleLowerCase('en');
const send = (client, value) => {if (client?.ws.readyState === WebSocket.OPEN) client.ws.send(JSON.stringify(value));};

export function createApp() {
 const clients = new Map(), byNick = new Map(), invites = new Map();
 const http = createServer(async (req,res) => {
  if (req.url === '/health') {res.writeHead(200, {'content-type':'application/json'});res.end(JSON.stringify({ok:true,players:byNick.size}));return;}
  if (req.method !== 'GET' && req.method !== 'HEAD') {res.writeHead(405);res.end();return;}
  let path;
  try {path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);} catch {res.writeHead(400);res.end();return;}
  const file = join(root, normalize(path === '/' ? 'index.html' : path).replace(/^[/\\]+/,''));
  if (file !== root && !file.startsWith(root + sep)) {res.writeHead(403);res.end();return;}
  try {
   const info = await stat(file);
   if (!info.isFile()) throw new Error('not file');
   const body = await readFile(file);
   res.writeHead(200, {'content-type':mime[extname(file)] || 'application/octet-stream','cache-control':extname(file)==='.html'?'no-cache':'public, max-age=3600','x-content-type-options':'nosniff'});
   res.end(req.method === 'HEAD' ? undefined : body);
  } catch {res.writeHead(404);res.end();}
 });
 const wss = new WebSocketServer({noServer:true,maxPayload:65536});
 http.on('upgrade',(req,socket,head) => {
  const origin = req.headers.origin;
  const host = req.headers.host;
  let valid=false;
  try {valid=new URL(req.url,'http://localhost').pathname==='/ws' && (!origin || new URL(origin).host===host);} catch {}
  if (!valid) {socket.destroy();return;}
  wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws));
 });
 function roster() {
  const names = [...byNick.values()].filter(c=>!c.match).map(c=>c.nick).sort((a,b)=>a.localeCompare(b));
  for (const c of byNick.values()) send(c,{type:'roster',names});
 }
 function endMatch(match,reason) {
  for (const c of match.players) {if(c.match===match){c.match=null;send(c,{type:'match_end',reason});}}
  roster();
 }
 function clearInvites(client) {
  for (const [id,invite] of invites) if (invite.from===client || invite.to===client) {
   invites.delete(id);
   send(invite.from,{type:'invite_closed',id});send(invite.to,{type:'invite_closed',id});
  }
 }
 wss.on('connection',ws => {
  const c={ws,nick:null,match:null,alive:true,lastInvite:0};clients.set(ws,c);
  ws.on('pong',()=>{c.alive=true;});
  ws.on('message',data => {
   let m;try {m=JSON.parse(data.toString());}catch{return;}
   if (!m || typeof m!=='object') return;
   if (m.type==='hello') {
    if (c.nick) return;
    const nick=typeof m.nick==='string'?m.nick.trim():'';
    if (!nickPattern.test(nick)) return send(c,{type:'error',code:'bad_nick',message:'Ник: 2–18 букв, цифр, _ или -.'});
    if (byNick.has(key(nick))) return send(c,{type:'error',code:'nick_taken',message:'Этот ник уже занят.'});
    c.nick=nick;byNick.set(key(nick),c);send(c,{type:'welcome',nick});roster();return;
   }
   if (!c.nick) return;
   if (m.type==='invite') {
    if (c.match || Date.now()-c.lastInvite<750) return;
    c.lastInvite=Date.now();
    const to=byNick.get(key(String(m.nick||'')));
    if (!to || to===c || to.match) return send(c,{type:'error',code:'not_available',message:'Игрок с таким ником сейчас недоступен.'});
    const id=randomUUID();invites.set(id,{from:c,to,expires:Date.now()+60000});
    send(to,{type:'invite',id,from:c.nick});send(c,{type:'invite_sent',id,to:to.nick});return;
   }
   if (m.type==='accept' || m.type==='decline') {
    const invite=invites.get(m.id);
    if (!invite || invite.to!==c || invite.expires<Date.now()) return send(c,{type:'error',code:'invite_expired',message:'Приглашение уже недействительно.'});
    invites.delete(m.id);
    if (m.type==='decline') {send(invite.from,{type:'invite_closed',id:m.id,declined:true});return;}
    const host=invite.from;
    if (host.match || c.match) return;
    clearInvites(host);clearInvites(c);
    const match={id:randomUUID(),players:[host,c]};host.match=match;c.match=match;
    send(host,{type:'match',id:match.id,role:'host',slot:0,peer:c.nick});
    send(c,{type:'match',id:match.id,role:'guest',slot:8,peer:host.nick});roster();return;
   }
   if (m.type==='input' && c.match && c.match.players[1]===c) {
    const input=m.input;
    if (!input || typeof input!=='object') return;
    const safe={};
    if (input.kind==='move' && Number.isFinite(input.x) && Number.isFinite(input.z)) {safe.kind='move';safe.x=Math.max(-60,Math.min(60,input.x));safe.z=Math.max(-39,Math.min(39,input.z));}
    else if (input.kind==='pad' && Number.isFinite(input.x) && Number.isFinite(input.y)) {safe.kind='pad';safe.x=Math.max(-1,Math.min(1,input.x));safe.y=Math.max(-1,Math.min(1,input.y));}
    else if (input.kind==='cast' && Array.isArray(input.queue) && input.queue.length<=5 && ['self','area','forward'].includes(input.mode) && Number.isFinite(input.x) && Number.isFinite(input.z)) {
     const elements=['water','life','shield','cold','lightning','arcane','earth','fire'];
     if (!input.queue.every(e=>elements.includes(e))) return;
     Object.assign(safe,{kind:'cast',queue:input.queue,mode:input.mode,x:Math.max(-60,Math.min(60,input.x)),z:Math.max(-39,Math.min(39,input.z))});
    } else return;
    send(c.match.players[0],{type:'input',input:safe});return;
   }
   if (m.type==='state' && c.match?.players[0]===c && m.state && JSON.stringify(m.state).length<50000) {send(c.match.players[1],{type:'state',state:m.state});return;}
   if (m.type==='effect' && c.match?.players[0]===c) {send(c.match.players[1],{type:'effect',effect:m.effect});return;}
  });
  ws.on('close',()=>{clients.delete(ws);if(c.nick)byNick.delete(key(c.nick));clearInvites(c);if(c.match)endMatch(c.match,`${c.nick} вышел из матча.`);roster();});
 });
 const heartbeat=setInterval(()=>{for(const c of clients.values()){if(!c.alive){c.ws.terminate();continue;}c.alive=false;c.ws.ping();}for(const [id,invite] of invites)if(invite.expires<Date.now()){invites.delete(id);send(invite.from,{type:'invite_closed',id});send(invite.to,{type:'invite_closed',id});}},30000);
 heartbeat.unref();
 return {http,close:()=>new Promise(resolve=>{clearInterval(heartbeat);for(const c of clients.values())c.ws.terminate();wss.close(()=>http.close(resolve));})};
}

if (process.argv[1] && fileURLToPath(import.meta.url)===process.argv[1]) {
 const {http}=createApp();
 http.listen(Number(process.env.PORT)||8080,'0.0.0.0',()=>console.log(`Riftbound listening on ${http.address().port}`));
}
