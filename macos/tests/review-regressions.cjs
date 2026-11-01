'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const app=path.join(__dirname,'..','local-mac-mcp.cjs');
const t=fs.mkdtempSync(path.join(os.tmpdir(),'mac-mcp-review-'));
const workspace=path.join(t,'workspace'),outside=path.join(t,'outside');
fs.mkdirSync(workspace);fs.mkdirSync(outside);
const invalid=Buffer.from([0xc7,0xd1,0xb1,0xdb,0xb1,0xdb,0xbc,0xbc,0xbf,0xe4,0x20,0x68,0x65,0x6c,0x6c,0x6f]); // CP949-like invalid UTF8
fs.writeFileSync(path.join(workspace,'invalid.txt'),invalid);
fs.writeFileSync(path.join(workspace,'binary.bin'),Buffer.from([104,101,108,108,111,0,255]));
fs.writeFileSync(path.join(workspace,'expand.txt'),'x'.repeat(1024));
fs.writeFileSync(path.join(workspace,'large.txt'),'z'.repeat(256*1024)+'needle');
fs.writeFileSync(path.join(outside,'private.txt'),'outside-original');
fs.linkSync(path.join(outside,'private.txt'),path.join(workspace,'hardlink.txt'));
const cases=[
  ['hardlink-read','read_text_file',{path:'hardlink.txt'}],
  ['hardlink-write','write_text_file',{path:'hardlink.txt',content:'HACKED',overwrite:true}],
  ['hardlink-edit','edit_text_file',{path:'hardlink.txt',find:'outside',replace:'HACKED'}],
  ['invalid-read','read_text_file',{path:'invalid.txt'}],
  ['invalid-edit','edit_text_file',{path:'invalid.txt',find:'hello',replace:'world'}],
  ['binary-edit','edit_text_file',{path:'binary.bin',find:'hello',replace:'world'}],
  ['expansion-edit','edit_text_file',{path:'expand.txt',find:'x',replace:'y'.repeat(3072),expectedMatches:1024}],
  ['large-search','search_files',{path:'large.txt',pattern:'needle',searchContent:true}],
  ['workspace-search','search_files',{path:'.',pattern:'private',searchContent:true}],
  ['nul-write','write_text_file',{path:'unsafe.txt',content:'a\u0000b'}]
];
const payload=cases.map(([label,name,args],i)=>JSON.stringify({jsonrpc:'2.0',id:i+1,method:'tools/call',params:{name,arguments:args}})).join('\n')+'\n';
try {
  const result=spawnSync(process.execPath,[app],{input:payload,encoding:'utf8',env:{...process.env,MAC_BRIDGE_TEST_MODE:'1',LOCAL_PC_ROOT:workspace},timeout:20000,maxBuffer:1024*1024*8});
  assert.equal(result.status,0,'MCP process should complete');
  const rows=result.stdout.trim().split(/\r?\n/).filter(Boolean).map(x=>JSON.parse(x));
  assert.equal(rows.length,cases.length,'all MCP replies');
  const lookup=Object.fromEntries(rows.map((r,i)=>[cases[i][0],r.result]));
  for(const name of ['hardlink-read','hardlink-write','hardlink-edit','invalid-read','invalid-edit','binary-edit','expansion-edit','nul-write']) {
    assert.equal(lookup[name].isError,true,name+' should be rejected');
  }
  assert.equal(fs.readFileSync(path.join(outside,'private.txt'),'utf8'),'outside-original');
  assert.deepEqual(fs.readFileSync(path.join(workspace,'invalid.txt')),invalid);
  assert.deepEqual(fs.readFileSync(path.join(workspace,'binary.bin')),Buffer.from([104,101,108,108,111,0,255]));
  assert.equal(fs.statSync(path.join(workspace,'expand.txt')).size,1024);
  const large=JSON.parse(lookup['large-search'].content[0].text);
  assert.equal(large.limited,true,'oversized content search must disclose skip');
  assert.equal(large.skippedOversize,1);
  const search=JSON.parse(lookup['workspace-search'].content[0].text);
  assert.ok(search.skippedHardlinks>=1,'hardlink skipped');
  assert.ok(search.limited);
  assert.equal(fs.existsSync(path.join(workspace,'unsafe.txt')),false);
  console.log('PASS: Mac review regressions: hardlinks, invalid UTF-8, binary/NUL, edit output limit, search skip disclosure');
} finally {fs.rmSync(t,{recursive:true,force:true})}
