'use strict';
// ChatGPT Local Mac Bridge (macOS only). Independent copy; does NOT modify Windows files. Built-in Node.js modules only.
// Local stdio MCP. Does not open an HTTP port or persist itself.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const readline = require('node:readline');
const childProcess = require('node:child_process');

let localSettings={};
try { localSettings=JSON.parse(fs.readFileSync(path.join(__dirname,'local-pc-config.json'),'utf8')); } catch {}
const configuredRoot = process.env.LOCAL_PC_ROOT || localSettings.workspace || path.join(os.homedir(), 'ChatGPTLocalFiles');
if (!fs.existsSync(configuredRoot)) {
  process.stderr.write('Workspace missing: ' + configuredRoot + '\n');
  process.exit(2);
}
if (process.platform !== 'darwin' && process.env.MAC_BRIDGE_TEST_MODE !== '1') {
  process.stderr.write('This is the macOS-only MCP. Use Windows local-pc-mcp.cjs on Windows.\n');
  process.exit(2);
}
const root = fs.realpathSync(configuredRoot);
const MAX_READ_BYTES = 256 * 1024;
const MAX_WRITE_BYTES = 128 * 1024;
const MAX_ITEMS = 150;
const MAX_SEARCH_VISITS = 2500;
const MAX_SEARCH_RESULTS = 200;
const MAX_BINARY_BYTES = 2 * 1024 * 1024;

function safePath(input) {
  if (typeof input !== 'string') throw new Error('path must be a string');
  if (input.includes('\0')) throw new Error('Invalid path');
  const absolute = path.resolve(root, input);
  const rel = path.relative(root, absolute);
  if (rel === '..' || rel.startsWith('..' + path.sep) || path.isAbsolute(rel)) {
    throw new Error('Path outside authorized workspace');
  }
  let current = root;
  for (const part of rel.split(path.sep).filter(Boolean)) {
    current = path.join(current, part);
    try {
      const item = fs.lstatSync(current);
      if (item.isSymbolicLink()) throw new Error('Symbolic links are not allowed');
    } catch (e) {
      if (e.code !== 'ENOENT') throw e;
    }
  }
  return absolute;
}
const pathSchema = {type:'string', description:'Absolute path or path relative to the authorized workspace'};
function editTextFile(args) {
  const file = safePath(args.path);
  if (!args.find || typeof args.find !== 'string' || typeof args.replace !== 'string') throw Error('find and replace must be strings');
  const contents = fs.readFileSync(file, 'utf8');
  if (Buffer.byteLength(contents) > MAX_BINARY_BYTES) throw Error('File exceeds edit limit');
  const count = contents.split(args.find).length - 1;
  if (count !== (args.expectedMatches ?? 1)) throw Error('Expected exact match count; found ' + count + '. No changes made.');
  const changed = contents.split(args.find).join(args.replace);
  fs.writeFileSync(file, changed, 'utf8');
  return {path:file,replacements:count,changed:true};
}
function searchFiles(args) {
  const start = safePath(args.path ?? '.');
  const needle = args.pattern;
  if (typeof needle !== 'string' || needle.length === 0 || needle.length > 250) throw Error('Invalid search pattern');
  const found = [], queue = [start]; let visited = 0, directories = 0;
  while (queue.length && visited + directories < MAX_SEARCH_VISITS && found.length < MAX_SEARCH_RESULTS) {
    const p = queue.shift();
    let st; try { st = fs.lstatSync(p); } catch { continue; }
    if (st.isSymbolicLink()) continue;
    if (st.isDirectory()) {
      directories++;
      try { for (const name of fs.readdirSync(p)) queue.push(path.join(p,name)); } catch {}
    } else if (st.isFile()) {
      visited++;
      if (args.searchContent === true) {
        if (st.size <= 256 * 1024) {
          try { if (fs.readFileSync(p,'utf8').toLowerCase().includes(needle.toLowerCase())) found.push(p); } catch {}
        }
      } else if (path.basename(p).toLowerCase().includes(needle.toLowerCase())) found.push(p);
    }
  }
  return {root:start,filesVisited:visited,results:found,limited:queue.length>0};
}
function listMacProcesses() {
  if (process.platform !== 'darwin') return {note:'macOS-only process list',platform:process.platform,pid:process.pid};
  const result = childProcess.execFileSync('/bin/ps',['-axo','pid=,comm='],{
    encoding:'utf8',timeout:10000,maxBuffer:1024*1024
  });
  return {platform:'darwin',processes:result.split(/\r?\n/).filter(Boolean).slice(0,300)};
}
const tools = [
  {name:'pc_info', description:'Show this PC hostname and authorized workspace (read-only).', inputSchema:{type:'object',properties:{},additionalProperties:false}},
  {name:'list_directory',description:'List names and types inside the authorized workspace only.',inputSchema:{type:'object',properties:{path:pathSchema},additionalProperties:false}},
  {name:'read_text_file',description:'Read a UTF-8 text file inside the authorized workspace, maximum 256 KiB.',inputSchema:{type:'object',properties:{path:pathSchema},required:['path'],additionalProperties:false}},
  {name:'write_text_file',description:'Write a UTF-8 text file inside the authorized workspace; overwrite requires explicit true. Maximum 128 KiB.',inputSchema:{type:'object',properties:{path:pathSchema,content:{type:'string'},overwrite:{type:'boolean',default:false}},required:['path','content'],additionalProperties:false}},
  {name:'edit_text_file',description:'Exact find-and-replace text editing inside authorized workspace.',inputSchema:{type:'object',properties:{path:pathSchema,find:{type:'string'},replace:{type:'string'},expectedMatches:{type:'integer',default:1}},required:['path','find','replace']}},
  {name:'file_info',description:'View metadata for a file or folder.',inputSchema:{type:'object',properties:{path:pathSchema},required:['path']}},
  {name:'create_directory',description:'Create folders inside authorized workspace.',inputSchema:{type:'object',properties:{path:pathSchema},required:['path']}},
  {name:'move_file',description:'Rename or move files within authorized workspace, without overwriting.',inputSchema:{type:'object',properties:{from:pathSchema,to:pathSchema},required:['from','to']}},
  {name:'search_files',description:'Search file names or text within the authorized workspace.',inputSchema:{type:'object',properties:{path:pathSchema,pattern:{type:'string'},searchContent:{type:'boolean'}},required:['pattern']}},
  {name:'read_binary_file',description:'Read small binary file as base64 (2 MiB max).',inputSchema:{type:'object',properties:{path:pathSchema},required:['path']}},
  {name:'list_processes',description:'List macOS running processes read-only.',inputSchema:{type:'object',properties:{}}},
];
function response(id, result) { process.stdout.write(JSON.stringify({jsonrpc:'2.0',id,result}) + '\n'); }
function error(id, code, message) { process.stdout.write(JSON.stringify({jsonrpc:'2.0',id,error:{code,message}}) + '\n'); }
function callTool(name, args) {
  args = args && typeof args === 'object' && !Array.isArray(args) ? args : {};
  let output;
  switch (name) {
    case 'pc_info':
      output = {hostname:os.hostname(),platform:process.platform,node:process.version,workspace:root, note:'Only the authorized workspace is exposed. No shell execution.'};
      break;
    case 'list_directory': {
      const dir = safePath(args.path ?? '.');
      if (!fs.statSync(dir).isDirectory()) throw new Error('Not a directory');
      const files = fs.readdirSync(dir,{withFileTypes:true}).slice(0,MAX_ITEMS);
      output = {directory:path.relative(root,dir)||'.', entries:files.map(f=>({name:f.name,type:f.isDirectory()?'directory':f.isFile()?'file':'other'})),limit:MAX_ITEMS};
      break;
    }
    case 'read_text_file': {
      const file = safePath(args.path);
      const stat = fs.statSync(file);
      if (!stat.isFile()) throw new Error('Not a file');
      if (stat.size > MAX_READ_BYTES) throw new Error('File exceeds read limit');
      const buffer = fs.readFileSync(file);
      if (buffer.includes(0)) throw new Error('Binary files not supported');
      output = {path:path.relative(root,file),content:buffer.toString('utf8')};
      break;
    }
    case 'write_text_file': {
      const file = safePath(args.path);
      if (typeof args.content !== 'string') throw new Error('content must be a string');
      const count = Buffer.byteLength(args.content,'utf8');
      if (count > MAX_WRITE_BYTES) throw new Error('Content exceeds write limit');
      if (!fs.statSync(path.dirname(file)).isDirectory()) throw new Error('Parent directory missing');
      if (fs.existsSync(file) && !args.overwrite) throw new Error('File exists: overwrite must be true');
      fs.writeFileSync(file,args.content,{encoding:'utf8',flag:args.overwrite === true ? 'w':'wx'});
      output = {path:path.relative(root,file),bytes:count,written:true};
      break;
    }
    case 'edit_text_file':
      output = editTextFile(args);
      break;
    case 'file_info': {
      const file = safePath(args.path);
      const stat = fs.statSync(file);
      output = {path:file,isFile:stat.isFile(),isDirectory:stat.isDirectory(),size:stat.size,createdAt:stat.birthtime.toISOString(),modifiedAt:stat.mtime.toISOString()};
      break;
    }
    case 'create_directory': {
      const dir=safePath(args.path);
      fs.mkdirSync(dir,{recursive:true});
      output={created:dir};
      break;
    }
    case 'move_file': {
      const source=safePath(args.from),target=safePath(args.to);
      if(fs.existsSync(target)) throw Error('Destination already exists');
      fs.renameSync(source,target);
      output={from:source,to:target,moved:true};
      break;
    }
    case 'search_files':
      output=searchFiles(args);
      break;
    case 'read_binary_file': {
      const file=safePath(args.path);
      if(fs.statSync(file).size>MAX_BINARY_BYTES) throw Error('Binary file exceeds 2 MiB');
      output={path:file,encoding:'base64',contents:fs.readFileSync(file).toString('base64')};
      break;
    }
    case 'list_processes':
      output=listMacProcesses();
      break;
    default: throw new Error('Unknown tool');
  }
  return {content:[{type:'text',text:JSON.stringify(output,null,2)}]};
}
const io = readline.createInterface({input:process.stdin,crlfDelay:Infinity});
io.on('line', line=>{
  let message;
  try { message = JSON.parse(line); } catch { return; }
  if (!message || message.id === undefined || message.id === null) return;
  try {
    switch (message.method) {
      case 'initialize':
        response(message.id,{protocolVersion:'2025-06-18',capabilities:{tools:{listChanged:false}},serverInfo:{name:'chatgpt-local-mac-bridge',version:'1.0.0'}});
        break;
      case 'ping': response(message.id,{}); break;
      case 'tools/list': response(message.id,{tools}); break;
      case 'tools/call':
        try { response(message.id,callTool(message.params?.name,message.params?.arguments)); }
        catch(e) { response(message.id,{isError:true,content:[{type:'text',text:e.message}]}); }
        break;
      case 'resources/list': response(message.id,{resources:[]}); break;
      case 'prompts/list': response(message.id,{prompts:[]}); break;
      default: error(message.id,-32601,'Method not found');
    }
  } catch (e) { error(message.id,-32603,e.message); }
});
process.stderr.write('ChatGPT Local Mac Bridge started; workspace: ' + root + '\n');