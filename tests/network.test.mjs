import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {createApp} from '../server.mjs';

function client(url) {
 const ws=new WebSocket(url),queue=[],waiting=[];
 ws.on('message',raw=>{const m=JSON.parse(raw);const i=waiting.findIndex(w=>w.type===m.type);if(i>=0){const w=waiting.splice(i,1)[0];clearTimeout(w.timer);w.resolve(m);}else queue.push(m);});
 return {ws,send:m=>ws.send(JSON.stringify(m)),next:type=>{const i=queue.findIndex(m=>m.type===type);if(i>=0)return Promise.resolve(queue.splice(i,1)[0]);return new Promise((resolve,reject)=>{const w={type,resolve,timer:setTimeout(()=>{waiting.splice(waiting.indexOf(w),1);reject(new Error(`Timed out waiting for ${type}`));},3000)};waiting.push(w);});}};
}

test('nickname login, invite, remote controls, state relay and disconnect', async () => {
 const app=createApp();app.http.listen(0,'127.0.0.1');await once(app.http,'listening');
 const url=`ws://127.0.0.1:${app.http.address().port}/ws`;
 const alice=client(url),bob=client(url),duplicate=client(url);
 try {
  await Promise.all([once(alice.ws,'open'),once(bob.ws,'open'),once(duplicate.ws,'open')]);
  alice.send({type:'hello',nick:'Алиса'});assert.equal((await alice.next('welcome')).nick,'Алиса');
  duplicate.send({type:'hello',nick:'алиса'});assert.equal((await duplicate.next('error')).code,'nick_taken');
  bob.send({type:'hello',nick:'Bob'});assert.equal((await bob.next('welcome')).nick,'Bob');
  alice.send({type:'invite',nick:'bOb'});const invite=await bob.next('invite');assert.equal(invite.from,'Алиса');
  bob.send({type:'accept',id:invite.id});const [aMatch,bMatch]=await Promise.all([alice.next('match'),bob.next('match')]);
  assert.equal(aMatch.role,'host');assert.equal(bMatch.role,'guest');assert.equal(aMatch.id,bMatch.id);
  bob.send({type:'input',input:{kind:'move',x:1000,z:-1000}});assert.deepEqual((await alice.next('input')).input,{kind:'move',x:60,z:-39});
  alice.send({type:'state',state:{time:1,agents:[{hp:1000}]}});assert.equal((await bob.next('state')).state.time,1);
  const response=await fetch(`http://127.0.0.1:${app.http.address().port}/health`);assert.deepEqual(await response.json(),{ok:true,players:2});
  bob.ws.close();assert.match((await alice.next('match_end')).reason,/Bob/);
 } finally {alice.ws.terminate();bob.ws.terminate();duplicate.ws.terminate();await app.close();}
});
