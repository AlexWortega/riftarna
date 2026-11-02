import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {createApp} from '../server.mjs';

function client(url){
 const ws=new WebSocket(url),queue=[],waiting=[];
 ws.on('message',raw=>{const m=JSON.parse(raw);const i=waiting.findIndex(w=>w.type===m.type);if(i>=0){const w=waiting.splice(i,1)[0];clearTimeout(w.timer);w.resolve(m);}else queue.push(m);});
 return {ws,send:m=>ws.send(JSON.stringify(m)),next:type=>{const i=queue.findIndex(m=>m.type===type);if(i>=0)return Promise.resolve(queue.splice(i,1)[0]);return new Promise((resolve,reject)=>{const w={type,resolve,timer:setTimeout(()=>{waiting.splice(waiting.indexOf(w),1);reject(new Error(`Timed out waiting for ${type}`));},3000)};waiting.push(w);});},clear:type=>{for(let i=queue.length-1;i>=0;i--)if(queue[i].type===type)queue.splice(i,1);}};
}

test('eight-player room, slot routing, state fanout and disconnect',async()=>{
 const app=createApp();app.http.listen(0,'127.0.0.1');await once(app.http,'listening');const url=`ws://127.0.0.1:${app.http.address().port}/ws`,cs=Array.from({length:10},()=>client(url));
 try{
  await Promise.all(cs.map(c=>once(c.ws,'open')));
  for(let i=0;i<9;i++){cs[i].send({type:'hello',nick:`Mage${i}`});assert.equal((await cs[i].next('welcome')).nick,`Mage${i}`);}
  cs[9].send({type:'hello',nick:'mage0'});assert.equal((await cs[9].next('error')).code,'nick_taken');
  for(const c of cs)c.clear('rooms');cs[0].send({type:'create_room'});const room=await cs[0].next('room');assert.match(room.id,/^[0-9a-f]{10}$/);
  const listed=await cs[1].next('rooms');assert.equal(listed.rooms[0].id,room.id);
  for(let i=1;i<8;i++){cs[i].send({type:'join_room',id:room.id});assert.equal((await cs[i].next('room')).players.length,i+1);}
  cs[8].send({type:'join_room',id:room.id});assert.equal((await cs[8].next('error')).code,'room_full');
  cs[1].send({type:'start_room'});assert.equal((await cs[1].next('error')).code,'not_host');
  cs[0].send({type:'start_room'});const matches=await Promise.all(cs.slice(0,8).map(c=>c.next('match')));assert.deepEqual(matches.map(m=>m.slot),[0,8,1,9,2,10,3,11]);assert.equal(matches[0].players.length,8);
  cs[8].send({type:'join_room',id:room.id});assert.equal((await cs[8].next('error')).code,'room_started');
  cs[2].send({type:'input',input:{kind:'move',x:1000,z:-1000}});assert.deepEqual(await cs[0].next('input'),{type:'input',slot:1,input:{kind:'move',x:60,z:-39}});
  cs[0].send({type:'state',state:{time:1,agents:[]}});for(let i=1;i<8;i++)assert.equal((await cs[i].next('state')).state.time,1);
  cs[3].ws.close();assert.equal((await cs[0].next('player_left')).slot,9);
  const health=await fetch(`http://127.0.0.1:${app.http.address().port}/health`);assert.equal((await health.json()).players,8);
  cs[0].ws.close();assert.match((await cs[1].next('match_end')).reason,/Хост/);
 }finally{for(const c of cs)c.ws.terminate();await app.close();}
});
