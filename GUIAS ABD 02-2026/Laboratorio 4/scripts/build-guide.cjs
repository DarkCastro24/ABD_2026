/* Regenera HTML, SQL y metadatos a partir de G04.md. Requiere el paquete marked. */
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

async function main() {
  const args = process.argv.slice(2);
  const modules = args.includes('--modules') ? args[args.indexOf('--modules') + 1] : null;
  const resolve = modules ? createRequire(path.join(modules, '_resolver.cjs')) : require;
  const { marked } = await import(require('node:url').pathToFileURL(resolve.resolve('marked')).href);
  const root = path.resolve(__dirname, '..');
  const source = fs.readFileSync(path.join(root, 'G04.md'), 'utf8').replace(/^\uFEFF/, '').replace(/\r/g, '');
  const title = source.match(/^# (.+)$/m)[1];
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const sections = [];
  const sql = [
    '-- Laboratorio 4 | Ciclo 02-2026 | Versión 2',
    '-- Autor: Diego Eduardo Castro Quintanilla',
    '-- Fuente: G04.md. Regenerado por scripts/build-guide.cjs.',
    '-- Ejemplos informativos: ejecuta por bloques en el orden de la guía sobre una base nueva.',
    '-- La carga adjunta genera 50 000 filas en total, de las cuales 45 000 son préstamos.',
    '-- Ejecuta esa carga cuando se indique más adelante, antes de continuar con los índices.',
    '-- Activa Ctrl+M para medir. Desactívalo en las pruebas de permisos.',
    '-- Las tablas de referencia de comandos no se ejecutan de nuevo.',
    ''
  ];
  for (const match of source.matchAll(/^## (.+)\nDuration: (\d+)\n([\s\S]*?)(?=^## |$(?![\s\S]))/gm)) {
    const [, label, duration, body] = match;
    let html = marked.parse(body, { gfm: true, breaks: false });
    html = html.replace(/<blockquote>/g, '<aside class="learning-tip" role="note">')
      .replace(/<\/blockquote>/g, '</aside>');
    html = html.replace(/<pre><code(?: class="language-([^"\s]+)")?>([\s\S]*?)<\/code><\/pre>/g,
      (_, lang = 'texto', code) => `<div class="code-container"><div class="code-toolbar"><span>${esc(lang.toUpperCase())}</span><button type="button" class="copy-btn" onclick="copyCode(this)">Copiar código</button></div><pre><code class="language-${esc(lang)}">${code}</code></pre></div>`);
    html = html.replace(/<p><img src="([^"]+)" alt="([^"]*)"\s*\/?><\/p>/g, (_, src, alt) => {
      const absolute = path.resolve(root, src);
      if (!absolute.startsWith(root + path.sep) || !fs.existsSync(absolute)) throw Error(`Imagen inexistente: ${src}`);
      const mime = src.endsWith('.svg') ? 'image/svg+xml' : 'image/jpeg';
      const data = `data:${mime};base64,${fs.readFileSync(absolute).toString('base64')}`;
      if (path.basename(absolute).toLowerCase() === 'license.jpg') {
        return `<figure class="license-badge"><img src="${data}" alt="${alt}" width="88" height="31" loading="lazy"/></figure>`;
      }
      if (path.basename(absolute) === 'modelo-relacional-ssms.svg') {
        return `<figure><button type="button" class="diagram-image-button" onclick="openDiagram(this)" aria-label="Ampliar diagrama relacional"><img src="${data}" alt="${alt}" loading="lazy"/></button></figure>`;
      }
      const zoom = src.endsWith('.svg') ? '<button type="button" class="zoom-btn" onclick="openDiagram(this)">Ampliar diagrama</button>' : '';
      return `<figure><img src="${data}" alt="${alt}" loading="lazy"/><figcaption>${alt}</figcaption>${zoom}</figure>`;
    });
    html = html.replace(/href="g04\//g, 'href="');
    html = html.replace(/<table>/g, '<div class="table-scroll"><table>').replace(/<\/table>/g, '</table></div>');
    sections.push({ label, duration: Number(duration), html });
    sql.push(`-- ${'='.repeat(72)}`, `-- ${label}`, `-- ${'='.repeat(72)}`, '');
    for (const code of body.matchAll(/```sql\n([\s\S]*?)```|<!-- sql-(include|external): ([^>\n]+) -->/g)) {
      let text;
      if (code[2]) {
        const included = path.resolve(root, code[3].trim());
        if (!included.startsWith(root + path.sep)) throw Error('Archivo SQL fuera del laboratorio');
        if (!fs.existsSync(included)) throw Error(`Archivo SQL inexistente: ${code[3]}`);
        if (code[2] === 'external') {
          sql.push(`-- Ejecuta ahora el archivo adjunto: ${code[3].trim()}`,
            '-- Espera a que termine la carga y luego continúa con el siguiente bloque.', '');
          continue;
        }
        text = fs.readFileSync(included,'utf8').replace(/\r/g,'').trimEnd();
      } else text = code[1].trimEnd();
      sql.push(text.includes('LIMPIEZA OPCIONAL') ? text.split('\n').map(l => `-- ${l}`).join('\n') : text, '');
    }
  }
  if (!sections.length) throw Error('La guía no contiene secciones con duración.');
  const asset = name => fs.readFileSync(path.join(root, 'g04', 'assets', name), 'utf8');
  const fonts = asset('fonts.css').replace(/url\('([^']+)'\)/g, (_, file) =>
    `url('data:font/woff2;base64,${fs.readFileSync(path.join(root, 'g04', 'assets', file)).toString('base64')}')`);
  const styles = fs.readFileSync(path.join(root, 'g04', 'styles.css'), 'utf8');
  const inlineScript = name => asset(name).replace(/<\/script/gi, '<\\/script');
  const html = `<!doctype html>
<html lang="es"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<meta name="theme-color" content="#214b80"/>
<meta name="author" content="Diego Eduardo Castro Quintanilla"/>
<meta name="description" content="Laboratorio 4, versión 2. Índices, planes de ejecución y esquemas con BibliotecaLab04, basados en el material de clase."/>
<title>${esc(title)}</title>
<!-- Archivo generado desde G04.md. Recursos incrustados para lectura sin conexión. -->
<style>${fonts}\n${asset('codelab-elements.css')}\n${styles}</style>
<script>
try { localStorage.getItem('g04'); } catch (e) {
  const data = {};
  Object.defineProperty(window, 'localStorage', {value:{getItem:k=>data[k]||null,setItem:(k,v)=>data[k]=String(v),removeItem:k=>delete data[k]}});
}
</script></head><body>
<google-codelab id="g04" title="${esc(title)}" environment="web" category="databases">
${sections.map(s => `<google-codelab-step label="${esc(s.label.replace(/^\d+\.\s*/,''))}" duration="${s.duration}">\n${s.html}</google-codelab-step>`).join('\n')}
</google-codelab>
<dialog id="diagram-viewer" aria-label="Diagrama ampliado"><form method="dialog"><button class="copy-btn">Cerrar diagrama</button></form><div class="image-zoom"><img alt=""/></div></dialog>
<script>
document.querySelector('google-codelab').addEventListener('google-codelab-ready',()=>{
  for(const [id,label] of [['previous-step','Anterior'],['next-step','Siguiente'],['done','Finalizar']]){
    const button=document.getElementById(id);
    if(button){button.textContent=label;button.title=label;}
  }
});
function openDiagram(button) {
  const original=button.closest('figure').querySelector('img');
  const dialog=document.getElementById('diagram-viewer');
  dialog.querySelector('img').src=original.src;
  dialog.querySelector('img').alt=original.alt;
  dialog.showModal();
}
async function copyCode(button) {
  const code = button.closest('.code-container').querySelector('code').textContent;
  try {
    if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(code);
    else {
      const field = document.createElement('textarea'); field.value = code;
      field.style.position='fixed'; field.style.opacity='0'; document.body.appendChild(field);
      field.select(); const success=document.execCommand('copy'); field.remove();
      if (!success) throw Error('clipboard');
    }
    button.textContent='Copiado';
  } catch(e) { button.textContent='Selecciona y copia el código'; }
  setTimeout(()=>button.textContent='Copiar código',2500);
}
</script>
<script>${inlineScript('native-shim.js')}</script>
<script>${inlineScript('custom-elements.min.js')}</script>
<script>${inlineScript('codelab-elements.js')}</script>
<noscript>Activa JavaScript para utilizar la navegación. La fuente G04.md contiene toda la guía.</noscript>
</body></html>\n`;
  const meta = {
    environment: 'web', format: 'html', prefix: 'https://storage.googleapis.com',
    updated: '2026-10-23T12:00:00-06:00', id: 'g04',
    duration: sections.reduce((a,s)=>a+s.duration,0), title,
    summary: source.match(/^summary: (.+)$/m)[1], source: './G04.md', theme: '',
    status: ['published'], category: ['databases'], tags: ['databases'], url: 'g04'
  };
  const outputs = [
    ['g04/index.html', html],
    ['g04/codelab.json', JSON.stringify(meta,null,2)+'\n'],
    ['Script Laboratorio 4 ABD 02-26.sql', sql.join('\n').trimEnd()+'\n']
  ];
  for (const [file, content] of outputs) {
    const target = path.join(root, file);
    if (args.includes('--check')) {
      if (fs.readFileSync(target,'utf8').replace(/\r/g,'') !== content.replace(/\r/g,'')) throw Error(`Desincronizado: ${file}`);
    } else fs.writeFileSync(target,content,'utf8');
  }
  console.log(JSON.stringify({steps:sections.length,diagrams:(source.match(/\.svg\)/g)||[]).length,minutes:meta.duration,outputs:outputs.map(o=>o[0]),mode:args.includes('--check')?'checked':'built'}));
}
main().catch(e=>{ console.error(e); process.exitCode=1; });
