import {createVoxelGrid, blastVoxelGrid, voxelMask, applyVoxelMask} from './voxel-grid.js';

const MAX_SPARKS=650, MAX_DEBRIS=360, MAX_MARKS=360, MAX_SCORCH=180;
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));

function stampTexture(kind) {
 const canvas=document.createElement('canvas');canvas.width=canvas.height=128;
 const ctx=canvas.getContext('2d'),mid=64;
 if(kind==='scorch'){
  const g=ctx.createRadialGradient(mid,mid,5,mid,mid,63);
  g.addColorStop(0,'rgba(9,9,9,.84)');g.addColorStop(.55,'rgba(13,12,10,.58)');g.addColorStop(.82,'rgba(30,23,17,.25)');g.addColorStop(1,'rgba(0,0,0,0)');
  ctx.fillStyle=g;ctx.fillRect(0,0,128,128);
 }else{
  const g=ctx.createRadialGradient(mid,mid,0,mid,mid,64);
  g.addColorStop(0,'rgba(255,255,255,.5)');g.addColorStop(.25,'rgba(255,255,255,.3)');g.addColorStop(.65,'rgba(255,255,255,.09)');g.addColorStop(1,'rgba(255,255,255,0)');
  ctx.fillStyle=g;ctx.fillRect(0,0,128,128);
  ctx.strokeStyle='rgba(255,255,255,.9)';ctx.lineWidth=2;ctx.beginPath();ctx.arc(mid,mid,40,.25,2.6);ctx.arc(mid,mid,40,3.4,5.9);ctx.stroke();
  ctx.lineWidth=1.4;for(let i=0;i<8;i++){const a=i*Math.PI/4;ctx.beginPath();ctx.moveTo(mid+Math.cos(a)*30,mid+Math.sin(a)*30);ctx.lineTo(mid+Math.cos(a)*53,mid+Math.sin(a)*53);ctx.stroke();}
 }
 return canvas;
}

export function createDestruction(THREE,scene,treeData,{touchMode=false}={}) {
 const color=new THREE.Color(),dummy=new THREE.Object3D(),upQuat=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0));
 const geometry=new THREE.BoxGeometry(1,1,1);
 const sparkMesh=new THREE.InstancedMesh(new THREE.TetrahedronGeometry(1),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.94,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false}),MAX_SPARKS);
 sparkMesh.count=0;sparkMesh.frustumCulled=false;sparkMesh.castShadow=false;scene.add(sparkMesh);
 const debrisMesh=new THREE.InstancedMesh(geometry,new THREE.MeshStandardMaterial({color:0xffffff,roughness:1,metalness:0}),MAX_DEBRIS);
 debrisMesh.count=0;debrisMesh.frustumCulled=false;debrisMesh.castShadow=false;scene.add(debrisMesh);
 const flameMesh=new THREE.InstancedMesh(new THREE.ConeGeometry(.5,1.5,7),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.85,blending:THREE.AdditiveBlending,depthTest:false,depthWrite:false,toneMapped:false}),180);
 flameMesh.count=0;flameMesh.frustumCulled=false;flameMesh.castShadow=false;scene.add(flameMesh);
 function makeMarkMesh(kind,count){const texture=new THREE.CanvasTexture(stampTexture(kind));texture.colorSpace=THREE.SRGBColorSpace;const material=new THREE.MeshBasicMaterial({map:texture,color:0xffffff,transparent:true,opacity:kind==='scorch'?.8:.75,depthWrite:false,blending:kind==='scorch'?THREE.NormalBlending:THREE.AdditiveBlending,side:THREE.DoubleSide,toneMapped:false});const m=new THREE.InstancedMesh(new THREE.PlaneGeometry(1,1),material,count);m.count=0;m.frustumCulled=false;scene.add(m);return m;}
 const glowMesh=makeMarkMesh('glow',MAX_MARKS),scorchMesh=makeMarkMesh('scorch',MAX_SCORCH);
 const sparks=[],debris=[],marks=[],scorches=[];
 const flash=new THREE.PointLight('#ffffff',0,13,2);flash.position.set(0,3,0);scene.add(flash);
 let flashLife=0;
 function spark(x,y,z,tint,vx,vy,vz,life=.6,size=.15){if(sparks.length>=MAX_SPARKS)sparks.shift();sparks.push({x,y,z,vx,vy,vz,life,max:life,size,color:tint});}
 function burst(x,z,tint,count=10,y=1){for(let i=0;i<count;i++){const a=Math.random()*Math.PI*2,s=2+Math.random()*7;spark(x,y,z,tint,Math.cos(a)*s,1+Math.random()*6,Math.sin(a)*s,.35+Math.random()*.5,.08+Math.random()*.16);}}
 function chip(x,y,z,tint,power=1){if(debris.length>=MAX_DEBRIS)debris.shift();const a=Math.random()*Math.PI*2,s=2+Math.random()*5*power;debris.push({x,y,z,vx:Math.cos(a)*s,vy:2+Math.random()*5*power,vz:Math.sin(a)*s,size:.25+Math.random()*.24,spin:Math.random()*6,life:2+Math.random()*1.7,color:tint});}
 function mark(x,z,tint,radius=2,life=12,scorch=false){const list=scorch?scorches:marks,limit=scorch?MAX_SCORCH:MAX_MARKS;if(list.length>=limit)list.shift();const item={x,z,radius,life,max:life,color:tint,rotation:Math.random()*Math.PI*2,fire:false};list.push(item);return item;}

 // The whole forest uses four draw calls; each tree can still burn or disappear independently.
 const trees=treeData.map((t,i)=>({...t,id:i,hp:100,burn:0,dead:false,emit:0,spread:0}));
 const forestMeshes=[];
 const forestShapes=[new THREE.CylinderGeometry(.23,.45,3.5,6),...Array.from({length:3},(_,j)=>new THREE.BoxGeometry(3.3-j*.45,2.1,3.3-j*.45))];
 for(let layer=0;layer<4;layer++){const m=new THREE.InstancedMesh(forestShapes[layer],new THREE.MeshStandardMaterial({color:0xffffff,roughness:1,side:THREE.FrontSide}),trees.length);m.castShadow=!touchMode;m.receiveShadow=true;m.frustumCulled=false;scene.add(m);forestMeshes.push(m);}
 const leafColors=['#426f66','#568e80','#76a598'];
 function renderTree(t){const black=clamp((100-t.hp)/110,0,.78),heat=t.burn>0?Math.min(.45,t.burn/12):0;
  for(let j=0;j<4;j++){const m=forestMeshes[j],y=j===0?(t.dead?.45:1.5):3.4+(j-1)*1.1;
   dummy.position.set(t.x,y*t.scale,t.z);dummy.rotation.set(0,t.rotation+(j===0?0:j*.6),0);if(t.dead&&j===0)dummy.scale.set(t.scale*.8,t.scale*.25,t.scale*.8);else dummy.scale.setScalar(t.dead?0:t.scale);dummy.updateMatrix();m.setMatrixAt(t.id,dummy.matrix);
   color.set(j===0?'#665342':leafColors[j-1]).lerp(new THREE.Color('#171b19'),black);if(j>0&&heat)color.lerp(new THREE.Color('#ff863b'),heat);m.setColorAt(t.id,color);
   m.instanceMatrix.needsUpdate=true;if(m.instanceColor)m.instanceColor.needsUpdate=true;
  }
 }
 trees.forEach(renderTree);

 // Local voxel ruins: blast radius removes cells, unsupported cells fall as debris.
 const props=[];
 const positions=[];for(const side of[-1,1])for(const z of[-13,13])for(const x of[18,30])positions.push({x:side*x,z,nx:3,ny:7,nz:3,size:.56});
 for(const [x,z] of [[-38,-9],[-38,10],[38,-9],[38,10],[-12,17],[12,-17]])positions.push({x,z,nx:5,ny:4,nz:2,size:.6});
 positions.forEach((spec,id)=>{
  const grid=createVoxelGrid(spec.nx,spec.ny,spec.nz,spec.size),mesh=new THREE.InstancedMesh(geometry,new THREE.MeshStandardMaterial({color:0xffffff,roughness:1}),grid.cells.length);
  mesh.position.set(spec.x,0,spec.z);mesh.castShadow=!touchMode;mesh.receiveShadow=true;mesh.frustumCulled=false;scene.add(mesh);
  const palette=['#9dbda9','#b8b396','#819fa8','#c5aa91'];
  const p={id,x:spec.x,z:spec.z,grid,mesh,colors:grid.cells.map((c,i)=>c.y>=spec.ny-2&&i%3===0?(spec.x<0?'#69d9e5':'#f5949d'):palette[(i+c.y)%palette.length])};props.push(p);
  renderProp(p);
 });
 function renderProp(p){let n=0;for(let i=0;i<p.grid.cells.length;i++){const c=p.grid.cells[i];if(!c.active)continue;dummy.position.set(c.px,c.py,c.pz);dummy.rotation.set(0,0,0);dummy.scale.setScalar(p.grid.size*.96);dummy.updateMatrix();p.mesh.setMatrixAt(n,dummy.matrix);p.mesh.setColorAt(n,color.set(p.colors[i]));n++;}p.mesh.count=n;p.mesh.instanceMatrix.needsUpdate=true;if(p.mesh.instanceColor)p.mesh.instanceColor.needsUpdate=true;}
 function treeFall(t){if(t.dead)return;t.dead=true;t.burn=0;renderTree(t);mark(t.x,t.z,'#1b1510',2.4,35,true);for(let i=0;i<18;i++)chip(t.x+(Math.random()-.5)*1.8,1+Math.random()*4*t.scale,t.z+(Math.random()-.5)*1.8,i%4?'#314b35':'#665342',1.3);burst(t.x,t.z,'#ffac54',12,2);}
 function impact({x,z,element='arcane',radius=2,power=1,y=1.4,authoritative=true}){
  if(!Number.isFinite(x)||!Number.isFinite(z)||!Number.isFinite(radius))return;
  x=clamp(x,-62,62);z=clamp(z,-43,43);radius=clamp(radius,.5,7);power=clamp(power,.2,4);
  const tint={fire:'#ff7e35',water:'#4fc7fa',cold:'#b2f2ff',lightning:'#c994ff',arcane:'#ff69c4',earth:'#e6b56b',life:'#93f382',shield:'#f8dd83'}[element]||'#fff1b8';
  mark(x,z,tint,radius*2.1,element==='fire'?18:12);
  if(['fire','earth','arcane','lightning'].includes(element)){const scar=mark(x,z,'#1a130e',radius*1.5,element==='fire'?42:25,true);scar.fire=element==='fire';}
  burst(x,z,tint,Math.round(5+power*5),y);
  flash.color.set(tint);flash.position.set(x,2,z);flash.intensity=Math.min(27,8+power*5);flashLife=.22;
  if(!authoritative)return;
  const stoneRadius=radius*(element==='earth'?1.15:element==='arcane'?1:element==='lightning'?.72:element==='fire'?.56:0);
  if(stoneRadius>0)for(const p of props){if(Math.hypot(p.x-x,p.z-z)>radius+3)continue;const gone=blastVoxelGrid(p.grid,{x:x-p.x,y,z:z-p.z},stoneRadius);if(gone.length){renderProp(p);for(const i of gone.slice(0,26)){const c=p.grid.cells[i];chip(p.x+c.px,c.py,p.z+c.pz,p.colors[i],power);}burst(p.x,p.z,'#e0c8a1',Math.min(18,gone.length),1);}}
  for(const t of trees){if(t.dead||Math.hypot(t.x-x,t.z-z)>radius+t.scale*1.7)continue;
   if(element==='fire'){t.burn=Math.max(t.burn,8+power);t.hp-=10*power;}
   else if(element==='water'||element==='cold'){t.burn=0;t.hp-=element==='cold'?5*power:0;}
   else if(['earth','arcane','lightning'].includes(element))t.hp-=(element==='earth'?55:28)*power;
   if(t.hp<=0)treeFall(t);else renderTree(t);
  }
 }
 function trace(from,to,element,spacing=2.3){if(!from||!to)return;const d=Math.hypot(to.x-from.x,to.z-from.z);if(!Number.isFinite(d)||d<.1)return;const n=Math.min(12,Math.floor(d/spacing));for(let i=1;i<=n;i++){const f=i/(n+1);mark(from.x+(to.x-from.x)*f,from.z+(to.z-from.z)*f,{fire:'#ff913a',water:'#52caff',cold:'#b3edff',lightning:'#c49bfa',arcane:'#fa74bc',earth:'#d4ad79',life:'#a2db72',shield:'#e5ca73'}[element]||'#ffffff',element==='fire'?1.4:1.1,element==='fire'?13:8);}}
 let clock=0;
 function update(dt,authoritative=true){
  clock+=dt;
  flashLife=Math.max(0,flashLife-dt);flash.intensity*=Math.exp(-dt*17);if(!flashLife)flash.intensity=0;
  for(const t of trees){if(t.dead||t.burn<=0)continue;if(authoritative){t.burn=Math.max(0,t.burn-dt);t.hp-=15*dt;if(t.hp<=0){treeFall(t);continue;}t.spread+=dt;if(t.spread>.45){t.spread=0;for(const other of trees)if(!other.dead&&other.burn<=0&&Math.hypot(t.x-other.x,t.z-other.z)<4&&Math.random()<.16){other.burn=7.5;renderTree(other);}}}
   t.emit+=dt;if(t.emit>.1){t.emit=0;const y=2+Math.random()*3*t.scale;spark(t.x+(Math.random()-.5)*1.4,y,t.z+(Math.random()-.5)*1.4,Math.random()<.6?'#ff7138':'#ffca62',(Math.random()-.5)*1.5,2+Math.random()*2,(Math.random()-.5)*1.5,.45,.2);}
   if(authoritative&&Math.random()<dt*3)renderTree(t);
  }
  let flameCount=0;
  function addFlame(x,y,z,size,tint,phase){if(flameCount>=180)return;dummy.position.set(x,y+Math.sin(clock*10+phase)*.13,z);dummy.rotation.set(0,clock*3+phase,Math.sin(clock*7+phase)*.12);dummy.scale.setScalar(size*(.82+Math.sin(clock*12+phase)*.15));dummy.updateMatrix();flameMesh.setMatrixAt(flameCount,dummy.matrix);flameMesh.setColorAt(flameCount,color.set(tint));flameCount++;}
  for(const t of trees)if(!t.dead&&t.burn>0){addFlame(t.x+.8*t.scale,3.3*t.scale,t.z+.8*t.scale,t.scale*1.25,'#ff4c20',t.id);addFlame(t.x+.3*t.scale,4.4*t.scale,t.z+.7*t.scale,t.scale*.98,'#ffab2e',t.id+2);addFlame(t.x-.4*t.scale,5.3*t.scale,t.z+.55*t.scale,t.scale*.7,'#fff06b',t.id+4);}
  for(let i=0;i<scorches.length&&flameCount<180;i++){const s=scorches[i];if(s.fire&&s.life>2&&i%2===0)addFlame(s.x,.55,s.z,.65,'#ff782e',i);}
  flameMesh.count=flameCount;flameMesh.instanceMatrix.needsUpdate=true;if(flameMesh.instanceColor)flameMesh.instanceColor.needsUpdate=true;
  for(let i=sparks.length-1;i>=0;i--){const p=sparks[i];p.life-=dt;if(p.life<=0){sparks.splice(i,1);continue;}p.x+=p.vx*dt;p.y+=p.vy*dt;p.z+=p.vz*dt;p.vy-=dt*8;}
  sparkMesh.count=sparks.length;sparks.forEach((p,i)=>{dummy.position.set(p.x,p.y,p.z);dummy.rotation.set(p.life*8,p.life*7,0);dummy.scale.setScalar(p.size*clamp(p.life/p.max,.08,1));dummy.updateMatrix();sparkMesh.setMatrixAt(i,dummy.matrix);sparkMesh.setColorAt(i,color.set(p.color));});sparkMesh.instanceMatrix.needsUpdate=true;if(sparkMesh.instanceColor)sparkMesh.instanceColor.needsUpdate=true;
  for(let i=debris.length-1;i>=0;i--){const p=debris[i];p.life-=dt;if(p.life<=0){debris.splice(i,1);continue;}p.vy-=dt*18;p.x+=p.vx*dt;p.y+=p.vy*dt;p.z+=p.vz*dt;if(p.y<p.size/2){p.y=p.size/2;p.vy=Math.abs(p.vy)*.25;p.vx*=.75;p.vz*=.75;}}
  debrisMesh.count=debris.length;debris.forEach((p,i)=>{dummy.position.set(p.x,p.y,p.z);dummy.rotation.set(p.life*p.spin,p.life*p.spin*.6,0);dummy.scale.setScalar(p.size);dummy.updateMatrix();debrisMesh.setMatrixAt(i,dummy.matrix);debrisMesh.setColorAt(i,color.set(p.color));});debrisMesh.instanceMatrix.needsUpdate=true;if(debrisMesh.instanceColor)debrisMesh.instanceColor.needsUpdate=true;
  function updateMarks(list,m){for(let i=list.length-1;i>=0;i--){list[i].life-=dt;if(list[i].life<=0)list.splice(i,1);}m.count=list.length;list.forEach((p,i)=>{dummy.position.set(p.x,scorches===list ? .095 : .12,p.z);dummy.rotation.set(-Math.PI/2,0,p.rotation);dummy.scale.setScalar(p.radius*clamp(p.life/2,.05,1));dummy.updateMatrix();m.setMatrixAt(i,dummy.matrix);m.setColorAt(i,color.set(p.color));});m.instanceMatrix.needsUpdate=true;if(m.instanceColor)m.instanceColor.needsUpdate=true;}
  updateMarks(marks,glowMesh);updateMarks(scorches,scorchMesh);
 }
 function snapshot(){return {props:props.map(p=>voxelMask(p.grid)),trees:trees.map(t=>[Math.max(0,t.hp),t.burn,t.dead?1:0])};}
 function applyState(state){if(!state||!Array.isArray(state.props)||!Array.isArray(state.trees)||state.props.length!==props.length||state.trees.length!==trees.length)return;
  state.props.forEach((mask,i)=>{const p=props[i],gone=applyVoxelMask(p.grid,mask);if(gone.length){renderProp(p);for(const id of gone.slice(0,18)){const c=p.grid.cells[id];chip(p.x+c.px,c.py,p.z+c.pz,p.colors[id],.7);}}});
  state.trees.forEach((v,i)=>{const t=trees[i];if(!Array.isArray(v)||v.length<3)return;const wasDead=t.dead;t.hp=Number(v[0])||0;t.burn=Number(v[1])||0;t.dead=Boolean(v[2]);if(t.dead&&!wasDead){for(let k=0;k<12;k++)chip(t.x,1+Math.random()*4*t.scale,t.z,k%3?'#314b35':'#665342',1);}renderTree(t);});
 }
 function blocks(x,z){return props.some(p=>p.mesh.count>8&&Math.abs(x-p.x)<p.grid.nx*p.grid.size/2+.55&&Math.abs(z-p.z)<p.grid.nz*p.grid.size/2+.55);}
 function spellHit(x,z){return props.some(p=>p.mesh.count>0&&Math.abs(x-p.x)<p.grid.nx*p.grid.size/2+.2&&Math.abs(z-p.z)<p.grid.nz*p.grid.size/2+.2)||trees.some(t=>!t.dead&&Math.hypot(x-t.x,z-t.z)<t.scale*.9);}
 function firstCollision(from,dir,range){for(let d=2.2;d<range;d+=.45){const x=from.x+dir.x*d,z=from.z+dir.z*d;if(spellHit(x,z))return{x,z};}return null;}
 function stats(){return {trees:trees.length,burning:trees.filter(t=>t.burn>0).length,fallen:trees.filter(t=>t.dead).length,voxels:props.reduce((n,p)=>n+p.mesh.count,0),props:props.length,marks:marks.length,scorches:scorches.length,sparks:sparks.length,debris:debris.length,flames:flameMesh.count};}
 return {impact,trace,update,burst,chip,mark,snapshot,applyState,blocks,spellHit,firstCollision,stats};
}
