import test from 'node:test';
import assert from 'node:assert/strict';
import {createVoxelGrid,blastVoxelGrid,voxelMask,applyVoxelMask} from '../dist/voxel-grid.js';

test('blast removes local cells and unsupported upper cells collapse',()=>{
 const grid=createVoxelGrid(1,3,1,1);
 assert.deepEqual(blastVoxelGrid(grid,{x:0,y:.5,z:0},.3),[0,1,2]);
 assert.equal(voxelMask(grid),'000');
});

test('a distant blast leaves a prop intact',()=>{
 const grid=createVoxelGrid(3,3,2,.5);
 assert.deepEqual(blastVoxelGrid(grid,{x:20,y:1,z:20},1),[]);
 assert.equal(voxelMask(grid),'1'.repeat(18));
});

test('a top cell survives when another grounded path supports it',()=>{
 const grid=createVoxelGrid(2,2,1,1);
 const removed=blastVoxelGrid(grid,{x:-.5,y:.5,z:0},.3);
 assert.deepEqual(removed,[0]);
 assert.equal(voxelMask(grid),'0111');
});

test('network mask applies only newly destroyed voxels',()=>{
 const grid=createVoxelGrid(2,2,1);
 assert.deepEqual(applyVoxelMask(grid,'0111'),[0]);
 assert.deepEqual(applyVoxelMask(grid,'0011'),[1]);
 assert.deepEqual(applyVoxelMask(grid,'0011'),[]);
 assert.equal(voxelMask(grid),'0011');
});
