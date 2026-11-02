import {createServer} from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import {randomBytes, randomUUID} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dirname, extname, join, normalize, sep} from 'node:path';
import {WebSocket, WebSocketServer} from 'ws';

const root=join(dirname(fileURLToPath(import.meta.url)),'dist');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml'};
const nickPattern=/^[\p{L}\p{N}_-]{2,18}$/u;
const key=value=>value.toLocaleLowerCase('en');
const send=(c,value)=>{if(c?.ws.readyState===WebSocket.OPEN)c.ws.send(JSON.stringify(value));};
const slots=[0,8,1,9,2,10,3,11];

export function createApp(){
 const clients=new Map(),byNick=new Map(),rooms=new Map();
 const http=createServer(async(req,res)=>{
  if(req.url==='/health'){res.writeHead(200,{'content-type':'application/json'});res.end(JSON.stringify({ok:true,players:byNick.size}));return;}
  if(req.method!=='GET'&&req.method!=='HEAD'){res.writeHead(405);res.end();return;}
  let path;try{path=decodeURIComponent(new URL(req.url,'http://localhost').pathname);}catch{res.writeHead(400);res.end();return;}
  const file=join(root,normalize(path==='/'?'index.html':path).replace(/^[/\\]+/,''));
  if(file!==root&&!file.startsWith(root+sep)){res.writeHead(403);res.end();return;}
  try{const info=await stat(file);if(!info.isFile())throw Error('not file');const body=await readFile(file);res.writeHead(200,{'content-type':mime[extname(file)]||'application/octet-stream','cache-control':'no-cache','x-content-type-options':'nosniff'});res.end(req.method==='HEAD'?undefined:body);}catch{res.writeHead(404);res.end();}
 });
 const wss=new WebSocketServer({noServer:true,maxPayload:65536});
 http.on('upgrade',(req,socket,head)=>{let valid=false;try{valid=new URL(req.url,'http://localhost').pathname==='/ws'&&(!req.headers.origin||new URL(req.headers.origin).host===req.headers.host);}catch{}if(!valid){socket.destroy();return;}wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws));});
 const error=(c,code,message)=>send(c,{type:'error',code,message});
 const listing=()=>[...rooms.values()].filter(r=>!r.started&&r.public).map(r=>({id:r.id,host:r.host.nick,count:r.players.length,max:8}));
 function broadcastRooms(){const value={type:'rooms',rooms:listing()};for(const c of byNick.values())send(c,value);}
 function roomState(r){const value={type:'room',id:r.id,host:r.host.nick,players:r.players.map(c=>c.nick),max:8,started:r.started};for(const c of r.players)send(c,value);broadcastRooms();}
 function leave(c){const r=c.room;if(!r)return;c.room=null;if(r.started){if(c===r.host){for(const p of r.players){if(p!==c){p.room=null;send(p,{type:'match_end',reason:'Хост вышел из матча.'});}}rooms.delete(r.id);}else{r.players.splice(r.players.indexOf(c),1);send(r.host,{type:'player_left',slot:c.slot,nick:c.nick});for(const p of r.players)if(p!==r.host)send(p,{type:'player_left',slot:c.slot,nick:c.nick});c.slot=null;roomState(r);}return;}
  r.players.splice(r.players.indexOf(c),1);if(c===r.host){for(const p of r.players){p.room=null;send(p,{type:'room_closed',id:r.id});}rooms.delete(r.id);broadcastRooms();}else roomState(r);
 }
 wss.on('connection',ws=>{
  const c={ws,nick:null,room:null,slot:null,alive:true,lastAction:0};clients.set(ws,c);ws.on('pong',()=>{c.alive=true;});
  ws.on('message',data=>{let m;try{m=JSON.parse(data.toString());}catch{return;}if(!m||typeof m!=='object')return;
   if(m.type==='hello'){if(c.nick)return;const nick=typeof m.nick==='string'?m.nick.trim():'';if(!nickPattern.test(nick))return error(c,'bad_nick','Ник: 2–18 букв, цифр, _ или -.');if(byNick.has(key(nick)))return error(c,'nick_taken','Этот ник уже занят.');c.nick=nick;byNick.set(key(nick),c);send(c,{type:'welcome',nick});send(c,{type:'rooms',rooms:listing()});return;}
   if(!c.nick)return;
   if(m.type==='create_room'){if(c.room)return error(c,'already_in_room','Вы уже в комнате.');const id=randomBytes(5).toString('hex');const r={id,host:c,players:[c],public:true,started:false};rooms.set(id,r);c.room=r;roomState(r);return;}
   if(m.type==='join_room'){if(c.room)return error(c,'already_in_room','Сначала выйдите из текущей комнаты.');const r=rooms.get(m.id);if(!r)return error(c,'room_missing','Комната не найдена.');if(r.started)return error(c,'room_started','Бой уже начался.');if(r.players.length>=8)return error(c,'room_full','Комната заполнена.');r.players.push(c);c.room=r;roomState(r);return;}
   if(m.type==='leave_room'){leave(c);send(c,{type:'rooms',rooms:listing()});return;}
   if(m.type==='start_room'){const r=c.room;if(!r||r.host!==c)return error(c,'not_host','Запустить бой может только создатель комнаты.');if(r.started||r.players.length<2)return error(c,'need_players','Для начала нужны хотя бы два игрока.');r.started=true;r.players.forEach((p,i)=>{p.slot=slots[i];send(p,{type:'match',id:r.id,role:p===c?'host':'guest',slot:p.slot,players:r.players.map((q,j)=>({nick:q.nick,slot:slots[j]}))});});broadcastRooms();return;}
   if(m.type==='input'&&c.room?.started&&c!==c.room.host){const input=m.input;if(!input||typeof input!=='object')return;const safe={};if(['move','dash'].includes(input.kind)&&Number.isFinite(input.x)&&Number.isFinite(input.z))Object.assign(safe,{kind:input.kind,x:Math.max(-60,Math.min(60,input.x)),z:Math.max(-39,Math.min(39,input.z))});else if(input.kind==='pad'&&Number.isFinite(input.x)&&Number.isFinite(input.y))Object.assign(safe,{kind:'pad',x:Math.max(-1,Math.min(1,input.x)),y:Math.max(-1,Math.min(1,input.y))});else if(input.kind==='cast'&&Array.isArray(input.queue)&&input.queue.length<=5&&input.queue.every(e=>['water','life','shield','cold','lightning','arcane','earth','fire'].includes(e))&&['self','area','forward'].includes(input.mode)&&Number.isFinite(input.x)&&Number.isFinite(input.z))Object.assign(safe,{kind:'cast',queue:input.queue,mode:input.mode,x:Math.max(-60,Math.min(60,input.x)),z:Math.max(-39,Math.min(39,input.z))});else return;send(c.room.host,{type:'input',slot:c.slot,input:safe});return;}
   if(['state','effect'].includes(m.type)&&c.room?.started&&c.room.host===c){if(m.type==='state'&&(!m.state||JSON.stringify(m.state).length>=50000))return;for(const p of c.room.players)if(p!==c)send(p,m.type==='state'?{type:'state',state:m.state}:{type:'effect',effect:m.effect});}
  });
  ws.on('close',()=>{clients.delete(ws);if(c.nick)byNick.delete(key(c.nick));leave(c);broadcastRooms();});
 });
 const heartbeat=setInterval(()=>{for(const c of clients.values()){if(!c.alive){c.ws.terminate();continue;}c.alive=false;c.ws.ping();}},30000);heartbeat.unref();
 return{http,close:()=>new Promise(resolve=>{clearInterval(heartbeat);for(const c of clients.values())c.ws.terminate();wss.close(()=>http.close(resolve));})};
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){const{http}=createApp();http.listen(Number(process.env.PORT)||8080,'0.0.0.0',()=>console.log(`Riftbound listening on ${http.address().port}`));}
