// Prototype rules. These coefficients are NOT extracted Magicka 2 formulas.
// Separate from rendering so parity fixtures can replace these rules later.
export const ELEMENTS = {
 water:{key:'Q',name:'Вода',symbol:'≋',color:'#68bcdf',damage:8},
 life:{key:'W',name:'Жизнь',symbol:'✳',color:'#a2db72',damage:0},
 shield:{key:'E',name:'Щит',symbol:'⬡',color:'#e5ca73',damage:0},
 cold:{key:'R',name:'Холод',symbol:'❄',color:'#b1e3ef',damage:23},
 lightning:{key:'A',name:'Молния',symbol:'ϟ',color:'#c49bfa',damage:65},
 arcane:{key:'S',name:'Аркана',symbol:'✦',color:'#ed79a2',damage:52},
 earth:{key:'D',name:'Земля',symbol:'◆',color:'#d4ad79',damage:85},
 fire:{key:'F',name:'Огонь',symbol:'♨',color:'#ff9c5a',damage:40}
};
export function compile(queue){
 const counts={};for(const e of queue)counts[e]=(counts[e]||0)+1;
 let type='push',name='Толчок',primary='water';
 if(counts.shield){type=counts.earth?'wall':'shield';primary=Object.keys(counts).find(e=>e!=='shield')||'shield';name=counts.earth?'Каменный барьер':primary==='shield'?'Магический щит':'Барьер: '+ELEMENTS[primary].name;}
 else if(counts.earth){type='projectile';primary=counts.fire?'fire':counts.cold?'cold':'earth';name=counts.fire?'Огненный камень':counts.cold?'Ледяной камень':'Каменный снаряд';}
 else if(counts.water&&counts.cold){type='projectile';primary='cold';name='Ледяные осколки';}
 else if(counts.arcane){type='beam';primary='arcane';name=counts.lightning?'Грозовой луч':'Луч арканы';}
 else if(counts.lightning){type='lightning';primary='lightning';name='Цепная молния';}
 else if(counts.water&&counts.fire){type='spray';primary='fire';name='Обжигающий пар';}
 else if(counts.fire){type='spray';primary='fire';name='Огненный поток';}
 else if(counts.cold){type='spray';primary='cold';name='Морозное дыхание';}
 else if(counts.water){type='spray';primary='water';name='Водяной поток';}
 else if(counts.life){type='heal';primary='life';name='Живительный свет';}
 const damage={};for(const [e,n]of Object.entries(counts))if(ELEMENTS[e].damage)damage[e]=ELEMENTS[e].damage*(1+(n-1)*.65);
 return {type,name,primary,counts,damage,color:ELEMENTS[primary].color,power:Math.max(1,queue.length)};
}
export function resolveDamage(target,components,time){
 let total=0; const effects=[];
 const wet=target.wet>time;
 for(const [e,raw]of Object.entries(components)){
  let d=raw;
  if(e==='lightning'&&wet)d*=1.8;
  if(target.ward>time&&(target.wardElement===e||target.wardElement==='shield'))d*=.3;
  if(e==='water'){target.wet=time+5;target.burning=0;effects.push('wet');}
  if(e==='fire'){if(wet){target.wet=0;d*=.7;}else{target.burning=time+3;effects.push('burn');}target.chill=Math.max(0,(target.chill||0)-25);}
  if(e==='cold'){target.chill=Math.min(100,(target.chill||0)+(wet?48:27));if(target.chill>=100){target.frozen=time+1.1;target.chill=0;effects.push('freeze');}}
  total+=d;
 }
 target.hp=Math.max(0,target.hp-total);
 return {total,effects};
}
