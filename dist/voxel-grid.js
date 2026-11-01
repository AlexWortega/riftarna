// Small, browser-friendly voxel grids for destructible arena props.
// A hit removes nearby cells; cells no longer connected to the ground collapse.
export function createVoxelGrid(nx, ny, nz, size = 0.55) {
 if (![nx, ny, nz].every(n => Number.isInteger(n) && n > 0) || !(size > 0)) throw new Error('Invalid voxel grid');
 const cells = [];
 for (let y = 0; y < ny; y++) for (let z = 0; z < nz; z++) for (let x = 0; x < nx; x++) {
  cells.push({x, y, z, px:(x-(nx-1)/2)*size, py:(y+0.5)*size, pz:(z-(nz-1)/2)*size, active:true});
 }
 return {nx, ny, nz, size, cells};
}

export function blastVoxelGrid(grid, point, radius) {
 if (!(radius > 0) || ![point.x, point.y, point.z].every(Number.isFinite)) return [];
 const removed = [];
 for (let i = 0; i < grid.cells.length; i++) {
  const c = grid.cells[i];
  if (c.active && Math.hypot(c.px-point.x,c.py-point.y,c.pz-point.z) <= radius) {
   c.active = false; removed.push(i);
  }
 }
 if (!removed.length) return removed;
 const index = (x,y,z) => x + grid.nx*(z+grid.nz*y);
 const supported = new Uint8Array(grid.cells.length), queue = [];
 for (const c of grid.cells) if (c.y === 0 && c.active) {
  const i = index(c.x,c.y,c.z); supported[i] = 1; queue.push(i);
 }
 for (let head = 0; head < queue.length; head++) {
  const c = grid.cells[queue[head]];
  for (const [dx,dy,dz] of [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]) {
   const x=c.x+dx,y=c.y+dy,z=c.z+dz;
   if (x<0||x>=grid.nx||y<0||y>=grid.ny||z<0||z>=grid.nz) continue;
   const i=index(x,y,z);
   if (grid.cells[i].active&&!supported[i]) {supported[i]=1;queue.push(i);}
  }
 }
 for (let i = 0; i < grid.cells.length; i++) if (grid.cells[i].active&&!supported[i]) {
  grid.cells[i].active=false;removed.push(i);
 }
 return removed;
}

export function voxelMask(grid) {return grid.cells.map(c=>c.active?'1':'0').join('');}

export function applyVoxelMask(grid, mask) {
 if (typeof mask!=='string'||mask.length!==grid.cells.length||/[^01]/.test(mask)) return [];
 const removed=[];
 for(let i=0;i<mask.length;i++) {if(grid.cells[i].active&&mask[i]==='0')removed.push(i);grid.cells[i].active=mask[i]==='1';}
 return removed;
}
