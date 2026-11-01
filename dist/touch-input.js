// A circular dead zone avoids drifting from a resting thumb. Output magnitude
// is bounded by one so diagonals cannot increase movement speed.
export function padVector(dx,dy,radius=42,deadZone=.12){
 const length=Math.hypot(dx,dy),magnitude=Math.min(1,length/radius);
 if(magnitude<=deadZone)return{x:0,y:0};
 const strength=(magnitude-deadZone)/(1-deadZone);
 return{x:dx/length*strength,y:dy/length*strength};
}
// Convert screen-space thumb direction into the ground plane of the isometric
// camera. Screen down follows the camera's horizontal offset from the player.
export function screenToWorld(x,y,offsetX=43,offsetZ=51){
 const length=Math.hypot(offsetX,offsetZ);
 return{x:(x*offsetZ+y*offsetX)/length,z:(-x*offsetX+y*offsetZ)/length};
}
