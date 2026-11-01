'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const readline = require('node:readline');
const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'chatgpt-local-pc-test-'));
const outside = fs.mkdtempSync(path.join(os.tmpdir(), 'chatgpt-local-pc-outside-'));
fs.writeFileSync(path.join(workspace,'hello.txt'),'hello', 'utf8');
fs.writeFileSync(path.join(outside,'secret.txt'),'do-not-read','utf8');
const serverPath=path.join(__dirname,'..','local-mac-mcp.cjs');
const child=spawn(process.execPath,[serverPath], {env:{...process.env,MAC_BRIDGE_TEST_MODE:'1',LOCAL_PC_ROOT:workspace},stdio:['pipe','pipe','pipe']});
let nextId=0;
const waiting=new Map();
const lines=readline.createInterface({input:child.stdout});
lines.on('line', line=>{ try {
  const msg=JSON.parse(line);
  const fn=waiting.get(msg.id);
  if(fn){waiting.delete(msg.id);fn(msg);}
} catch {} });
function request(method,params={}) {
  const id=++nextId;
  return Promise.race([
    new Promise(resolve=>{waiting.set(id,resolve);child.stdin.write(JSON.stringify({jsonrpc:'2.0',id,method,params})+'\n');}),
    new Promise((_,reject)=>setTimeout(()=>reject(new Error('Request timeout: '+method)),3500))
  ]);
}
const call=(name,args={})=>request('tools/call',{name,arguments:args});
(async()=>{
  try {
    const init=await request('initialize',{protocolVersion:'2025-06-18',capabilities:{},clientInfo:{name:'smoke',version:'1'}});
    assert.equal(init.result.serverInfo.name,'chatgpt-local-mac-bridge');
    const list=await request('tools/list');
    assert.deepEqual(list.result.tools.map(t=>t.name).sort(),["create_directory","edit_text_file","file_info","list_directory","list_processes","move_file","pc_info","read_binary_file","read_text_file","search_files","write_text_file"]);
    const info=await call('pc_info');
    assert.ok(info.result.content[0].text.includes('workspace'));
    const listing=await call('list_directory',{path:'.'});
    assert.ok(listing.result.content[0].text.includes('hello.txt'));
    const read=await call('read_text_file',{path:'hello.txt'});
    assert.ok(read.result.content[0].text.includes('hello'));
    const write=await call('write_text_file',{path:'created.txt',content:'made by test'});
    assert.ok(write.result.content[0].text.includes('"written": true'));
    assert.equal(fs.readFileSync(path.join(workspace,'created.txt'),'utf8'),'made by test');
    const denyOverwrite=await call('write_text_file',{path:'created.txt',content:'danger'});
    assert.equal(denyOverwrite.result.isError,true);
    const doOverwrite=await call('write_text_file',{path:'created.txt',content:'updated',overwrite:true});
    assert.equal(doOverwrite.result.isError,undefined);
    assert.equal(fs.readFileSync(path.join(workspace,'created.txt'),'utf8'),'updated');
    const traverse=await call('read_text_file',{path:path.join('..',path.basename(outside),'secret.txt')});
    assert.equal(traverse.result.isError,true);
    const absolute=await call('read_text_file',{path:path.join(outside,'secret.txt')});
    assert.equal(absolute.result.isError,true);
    const writeOutside=await call('write_text_file',{path:path.join(outside,'bad.txt'),content:'no'});
    assert.equal(writeOutside.result.isError,true);
    assert.equal(fs.existsSync(path.join(outside,'bad.txt')),false);
    const mkdir=await call('create_directory',{path:'nested'});
    assert.ok(!mkdir.result.isError);
    const move=await call('move_file',{from:'created.txt',to:'nested/moved.txt'});
    assert.ok(!move.result.isError);
    const stat=await call('file_info',{path:'nested/moved.txt'});
    assert.ok(stat.result.content[0].text.includes('isFile'));
    const edit=await call('edit_text_file',{path:'nested/moved.txt',find:'updated',replace:'edited'});
    assert.ok(!edit.result.isError);
    assert.equal(fs.readFileSync(path.join(workspace,'nested','moved.txt'),'utf8'),'edited');
    const ambig=await call('edit_text_file',{path:'nested/moved.txt',find:'notfound',replace:'bad'});
    assert.equal(ambig.result.isError,true);
    const search=await call('search_files',{path:'.',pattern:'moved.txt'});
    assert.ok(search.result.content[0].text.includes('moved.txt'));
    const proc=await call('list_processes',{});
    assert.equal(proc.result.isError,undefined);
    const noShell=await call('run_command',{command:'whoami'});
    assert.equal(noShell.result.isError,true);
    fs.writeFileSync(path.join(workspace,'binary.bin'),Buffer.from([1,0,2]));
    const binary=await call('read_text_file',{path:'binary.bin'});
    assert.equal(binary.result.isError,true);
    const binaryRead=await call('read_binary_file',{path:'binary.bin'});
    assert.equal(binaryRead.result.isError,undefined);
    assert.ok(binaryRead.result.content[0].text.includes('AQAC'));
    const contentSearch=await call('search_files',{path:'.',pattern:'edited',searchContent:true});
    assert.ok(contentSearch.result.content[0].text.includes('moved.txt'));
    const ping=await request('ping');
    assert.deepEqual(ping.result,{});
    console.log('PASS: init, tools, info, listing, read, write, overwrite denial, traversal denial, outside-path denial, arbitrary command denial, binary denial, ping');
  }finally{
    child.stdin.end();
    child.kill();
    fs.rmSync(workspace,{recursive:true,force:true});
    fs.rmSync(outside,{recursive:true,force:true});
  }
})().catch(e=>{console.error('FAIL:',e.message);process.exitCode=1;});