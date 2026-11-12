/* Capturas DIDACTICAS. Renderiza salidas esperadas, nunca ejecuta SQL ni Docker.
   node scripts/render-captures.cjs --modules RUTA --browser RUTA_EXE */
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const option = key => args.includes(key) ? args[args.indexOf(key)+1] : undefined;
const resolve = option('--modules') ? createRequire(path.join(option('--modules'), '_resolver.cjs')) : require;
const { chromium } = resolve('playwright');
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const records = JSON.parse(fs.readFileSync(path.join(__dirname,'expected-results.json'),'utf8'));
const source = fs.readFileSync(path.join(root,'G05.md'),'utf8').replace(/\r/g,'');
const blocks = [...source.matchAll(/<!-- lab-step: (\d+) -->\n```(sql|powershell)\n([\s\S]*?)```/g)];
if (blocks.length !== records.length) throw Error('Cada bloque necesita una captura.');
for (let i=0;i<blocks.length;i++) {
  if (blocks[i][1]!==records[i].id || blocks[i][2]!==records[i].lang || blocks[i][3].trim()!==records[i].code)
    throw Error('Captura desincronizada: '+records[i].id);
}
const css = `*{box-sizing:border-box}body{margin:0;background:#fff;font-family:'Segoe UI',Arial,sans-serif;color:#233348}.frame{width:1100px;background:#fff}.editor{padding:14px 14px 20px;background:#fff;min-height:75px}.line{display:flex;font:17px/1.55 Consolas,'Cascadia Mono',monospace;white-space:pre-wrap;overflow-wrap:anywhere}.ln{min-width:30px;color:#98a6b4;text-align:right;padding-right:12px;user-select:none}.sqlcode{color:#20496d;flex:1;min-width:0}.results{border-top:3px solid #d0d7e0;padding:0 10px 14px;min-height:95px}.tabs{display:flex;gap:24px;font-size:15px;padding:12px 0;color:#354d66}.tabs strong{font-weight:600}.grid{border-collapse:collapse;width:100%;font:17px/1.5 'Segoe UI',Arial,sans-serif;table-layout:auto}.grid td,.grid th{padding:7px 12px;border:1px solid #cdd6e0;text-align:left;overflow-wrap:anywhere}.grid th{background:#edf1f6;font-size:15px;font-weight:400}.grid td:first-child{width:37px;background:#f2f5f9;color:#6e7e8f;font-size:14px}.empty{height:40px;border:1px solid #d8e0e9;border-top:0}.messages{font:17px/1.6 Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;padding:5px 5px 14px;color:#33495d;margin:0}.terminal{background:#102332;color:#e5f1ff;padding:20px;min-height:185px}.terminal pre{white-space:pre-wrap;overflow-wrap:anywhere;font:18px/1.6 Consolas,'Cascadia Mono',monospace;margin:0}.prompt{color:#7fd6d0}.output{color:#f1f6fb}.commands{margin-bottom:18px!important}`;
function render(r) {
  let body;
  if(r.lang==='powershell') {
    const prompt='<span class="prompt">PS C:\\Users\\Diego&gt; </span>';
    body=`<div class="terminal"><pre class="commands">${r.code.split('\n').map(x=>prompt+esc(x)).join('\n')}</pre><pre class="output">${r.output.map(esc).join('\n')}${r.output.length?'\n\n':''}${prompt}▌</pre></div>`;
  } else {
    const table = r.columns ? `<table class="grid"><thead><tr><th></th>${r.columns.map(c=>'<th>'+esc(c)+'</th>').join('')}</tr></thead><tbody>${r.rows.map((row,i)=>'<tr><td>'+(i+1)+'</td>'+row.map(v=>'<td>'+esc(v)+'</td>').join('')+'</tr>').join('')}</tbody></table>${r.rows.length?'':'<div class="empty"></div>'}` : '';
    body=`<div class="editor">${r.code.split('\n').map((l,i)=>`<div class="line"><span class="ln">${i+1}</span><span class="sqlcode">${esc(l)||' '}</span></div>`).join('')}</div><div class="results"><div class="tabs"><strong>${r.columns?'Resultados':'Mensajes'}</strong><span>${r.columns?'Mensajes':'Resultados'}</span></div>${table}${!r.columns&&r.output.length?'<pre class="messages">'+r.output.map(esc).join('\n')+'</pre>':''}</div>`;
  }
  return `<!doctype html><html lang="es"><meta charset="utf-8"><style>${css}</style><body><main class="frame">${body}</main></body></html>`;
}
(async()=>{
  const out=path.join(root,'g05','img','capturas');fs.mkdirSync(out,{recursive:true});
  const browser=await chromium.launch({headless:true,executablePath:option('--browser')});
  try {
    const page=await browser.newPage({viewport:{width:1100,height:900},deviceScaleFactor:1.5});
    for (const r of records) {
      await page.setContent(render(r));await page.evaluate(()=>document.fonts.ready);
      await page.locator('.frame').screenshot({path:path.join(out,`paso-${r.id}.png`)});
    }
    console.log(JSON.stringify({captures:records.length,output:out,simulated:true}));
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
