import test from 'node:test';
import assert from 'node:assert/strict';
import {padVector,screenToWorld} from '../dist/touch-input.js';
test('resting thumb does not cause movement',()=>{assert.deepEqual(padVector(2,-1),{x:0,y:0});assert.deepEqual(padVector(0,0),{x:0,y:0});});
test('dragging beyond pad stays bounded including diagonals',()=>{const v=padVector(100,100);assert.ok(Math.abs(Math.hypot(v.x,v.y)-1)<1e-10);});
test('partial movement retains analog strength',()=>{const v=padVector(21,0);assert.ok(v.x>0&&v.x<1);assert.equal(v.y,0);});
test('camera conversion preserves speed and screen direction',()=>{for(const [x,y]of [[1,0],[0,1],[.5,.5]]){const v=screenToWorld(x,y);assert.ok(Math.abs(Math.hypot(v.x,v.z)-Math.hypot(x,y))<1e-10);}const right=screenToWorld(1,0);assert.ok(right.x>0&&right.z<0);const down=screenToWorld(0,1);assert.ok(down.x>0&&down.z>0);});
