'use strict';
// ChatGPT Local PC Bridge. Built-in Node.js modules only; no Desktop Commander dependency.
// Local stdio MCP. Does not open an HTTP port or persist itself.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const readline = require('node:readline');

const configuredRoot = process.env.LOCAL_PC_ROOT || path.join(os.homedir(), 'ChatGPTLocalFiles');
if (!fs.existsSync(configuredRoot)) {
  process.stderr.write('Workspace missing: ' + configuredRoot + '\n');
  process.exit(2);
}
const root = fs.realpathSync(configuredRoot);
const MAX_READ_BYTES = 256 * 1024;
const MAX_WRITE_BYTES = 128 * 1024;
const MAX_ITEMS = 150;

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
const pathSchema = {type:'string', description:'Path relative to the authorized workspace'};
const tools = [
  {name:'pc_info', description:'Show this PC hostname and authorized workspace (read-only).', inputSchema:{type:'object',properties:{},additionalProperties:false}},
  {name:'list_directory',description:'List names and types inside the authorized workspace only.',inputSchema:{type:'object',properties:{path:pathSchema},additionalProperties:false}},
  {name:'read_text_file',description:'Read a UTF-8 text file inside the authorized workspace, maximum 256 KiB.',inputSchema:{type:'object',properties:{path:pathSchema},required:['path'],additionalProperties:false}},
  {name:'write_text_file',description:'Write a UTF-8 text file inside the authorized workspace; overwrite requires explicit true. Maximum 128 KiB.',inputSchema:{type:'object',properties:{path:pathSchema,content:{type:'string'},overwrite:{type:'boolean',default:false}},required:['path','content'],additionalProperties:false}}
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
        response(message.id,{protocolVersion:'2025-06-18',capabilities:{tools:{listChanged:false}},serverInfo:{name:'chatgpt-local-pc-bridge',version:'1.0.0'}});
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
process.stderr.write('ChatGPT Local PC Bridge started; workspace: ' + root + '\n');