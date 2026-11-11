const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
function setup({playing=true,focused=false,url='https://www.youtube.com/watch?v=test'}={}) {
 const listeners={}; const state={}; let tabs=[{id:10,windowId:1,active:true,audible:true,url}];
 const windows=[{id:1,type:'normal',focused}];
 const event=n=>({addListener:f=>listeners[n]=f});
 const chrome={runtime:{lastError:null,connectNative:()=>({onMessage:event('desktop'),onDisconnect:event('disconnect')})},storage:{local:{set:async()=>{}},session:{get:async()=>({...state}),set:async v=>Object.assign(state,v)}},
  windows:{WINDOW_ID_NONE:-1,onFocusChanged:event('focus'),getAll:async()=>windows},
  tabs:{onRemoved:event('removed'),onActivated:event('activated'),query:async q=>tabs.filter(t=>t.windowId===q.windowId&&t.active),get:async id=>{const t=tabs.find(t=>t.id===id);if(!t)throw Error('closed');return t;},create:async v=>{tabs.forEach(t=>t.active=false);const t={...v,id:20};tabs.push(t);return t;},update:async(id,v)=>{tabs.forEach(t=>t.active=t.id===id);return tabs.find(t=>t.id===id);},remove:async id=>{tabs=tabs.filter(t=>t.id!==id);}},
  scripting:{executeScript:async()=>[{result:playing}]}};
 chrome.runtime.getURL=p=>'chrome-extension://test/'+p;
 const context={chrome,console,setTimeout,clearTimeout};vm.createContext(context);
 vm.runInContext(fs.readFileSync(__dirname+'/background.js','utf8'),context);
 return {context,state,windows,get tabs(){return tabs;},run:()=>vm.runInContext('reconcile()',context)};
}
test('leaving playing YouTube creates temporary tab; returning restores original and removes temporary',async()=>{
 const x=setup();await x.run();assert.equal(x.tabs.length,2);assert.equal(x.tabs.find(t=>t.active).id,20);
 x.windows[0].focused=true;await x.run();assert.equal(x.tabs.length,1);assert.equal(x.tabs[0].id,10);assert.equal(x.tabs[0].active,true);
});
test('paused videos, internal pages, insecure sites and focused windows are untouched',async()=>{
 for(const options of [{playing:false},{url:'brave://settings/'},{url:'http://example.com/'},{focused:true}]) {const x=setup(options);await x.run();assert.equal(x.tabs.length,1);}
});
test('repeated loss of focus creates only one temporary tab',async()=>{const x=setup();await x.run();await x.run();assert.equal(x.tabs.length,2);});

test('bspwm desktop state overrides stale browser focus in both directions',async()=>{
 const x=setup({focused:true});
 vm.runInContext('desktopAway=true',x.context);
 await x.run();assert.equal(x.tabs.length,2);
 x.windows[0].focused=false;
 vm.runInContext('desktopAway=false',x.context);
 await x.run();assert.equal(x.tabs.length,1);assert.equal(x.tabs[0].active,true);
});

test('other HTTPS video sites use the same desktop PiP lifecycle',async()=>{
 for(const url of ['https://vimeo.com/123','https://www.twitch.tv/example','https://example.com/video']) {
  const x=setup({url});await x.run();assert.equal(x.tabs.length,2);
  x.windows[0].focused=true;await x.run();assert.equal(x.tabs.length,1);assert.equal(x.tabs[0].active,true);
 }
});
