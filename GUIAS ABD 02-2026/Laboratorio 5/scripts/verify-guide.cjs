/* Ejecuta en orden los bloques SQL y PowerShell de G05.md contra el contenedor y comprueba sus resultados.
   Uso: node scripts/verify-guide.cjs CONTENEDOR DIRECTORIO_RESULTADOS
   Requiere que no existan NotasLab05 ni el job de la guía. Termina con la limpieza de la guía. */
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const [container, output] = process.argv.slice(2);
if (!container || !output) throw Error('Uso: node verify-guide.cjs CONTENEDOR DIRECTORIO_RESULTADOS');
fs.mkdirSync(output, { recursive: true });
const source = fs.readFileSync(path.join(root, 'G05.md'), 'utf8').replace(/\r/g, '');

const records = [];
let section = '', topic = '';
for (const m of source.matchAll(/^## (.+)$|^### (.+)$|^```(sql|powershell)\n([\s\S]*?)```/gm)) {
  if (m[1]) { section = m[1]; topic = ''; }
  else if (m[2]) topic = m[2];
  else records.push({ section, topic, lang: m[3], code: m[4] });
}

function sql(text) {
  const command = 'export SQLCMDPASSWORD="$MSSQL_SA_PASSWORD"; exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -d master -C -b -V 11 -f 65001 -w 65535';
  const r = spawnSync('docker', ['exec', '-i', container, '/bin/bash', '-lc', command], { input: text, encoding: 'utf8', timeout: 120000 });
  return { status: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
function ps(text) {
  const r = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', '[Console]::OutputEncoding=[Text.Encoding]::UTF8;' + text], { encoding: 'utf8', timeout: 120000 });
  return { status: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
const has = (...parts) => out => parts.every(p => out.includes(p));
const count = n => `IF (SELECT COUNT(*) FROM NotasLab05.dbo.Calificacion)<>${n} THROW 52001,N'Conteo distinto de ${n}',1;`;
const backup = (type, name) => `IF NOT EXISTS(SELECT 1 FROM msdb.dbo.backupset WHERE database_name=N'NotasLab05' AND type='${type}' AND name=N'${name}') THROW 52003,N'Falta respaldo ${type}',1;`;

// Comprobaciones posteriores a cada bloque: SQL que lanza THROW si algo no cumple, o una prueba sobre la salida.
function checksFor(r) {
  const s = r.code;
  if (r.lang === 'powershell') {
    if (s.includes('mkdir -p /backup/NotasLab05')) return { out: has('mssql', '/backup/NotasLab05') };
    if (s.includes('ls -l /backup/NotasLab05')) return { out: has('NotasLab05_full.bak', 'NotasLab05_diff.bak', 'NotasLab05_log.trn') };
    if (s.includes(' out /backup/NotasLab05/calificacion.dat')) return { out: has('9 rows copied') };
    if (s.includes(' in /backup/NotasLab05/calificacion.dat')) return { out: has('9 rows copied'), sql: count(9) };
    if (s.includes('rm -rf /backup/NotasLab05')) return { after: () => ps(`docker exec ${container} sh -c "test -e /backup/NotasLab05 && echo EXISTE || echo NOEXISTE"`).out.includes('NOEXISTE') };
    return {};
  }
  if (s.includes('LIMPIEZA OPCIONAL')) return { sql: `IF DB_ID(N'NotasLab05') IS NOT NULL THROW 52018,N'Quedo la base',1;
IF EXISTS(SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'Respaldo diario NotasLab05') OR EXISTS(SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Diario 10 p. m.') THROW 52019,N'Quedo el job',1;
IF EXISTS(SELECT 1 FROM msdb.dbo.sysoperators WHERE name=N'operador1') THROW 52023,N'Quedo el operador',1;
IF EXISTS(SELECT 1 FROM msdb.dbo.backupset WHERE database_name=N'NotasLab05') THROW 52020,N'Quedo historial',1;` };
  if (s.includes('CREATE TABLE dbo.Calificacion')) return { sql: count(6) + `IF (SELECT recovery_model_desc FROM sys.databases WHERE name=N'NotasLab05')<>N'FULL' THROW 52004,N'Modelo no FULL',1;` };
  if (s.includes('BACKUP LOG NotasLab05')) return {
    out: has('BACKUP DATABASE successfully processed', 'BACKUP DATABASE WITH DIFFERENTIAL successfully processed', 'BACKUP LOG successfully processed'),
    sql: backup('D', 'Respaldo completo NotasLab05') + backup('I', 'Respaldo diferencial NotasLab05') + backup('L', 'Respaldo del log NotasLab05') + count(10) +
      `IF (SELECT nota FROM NotasLab05.dbo.Calificacion WHERE calificacion_id=2)<>7.25 THROW 52005,N'Nota 2 no corregida',1;` };
  if (s.includes('RESTORE LOG NotasLab05')) return {
    out: out => /^\s*9 Lucía Morales\s+8\.75\s*$/m.test(out) && !out.includes('Andrés'),
    sql: count(9) + `IF (SELECT state_desc FROM sys.databases WHERE name=N'NotasLab05')<>N'ONLINE' THROW 52002,N'Base no ONLINE',1;
IF EXISTS(SELECT 1 FROM NotasLab05.dbo.Calificacion WHERE calificacion_id=10) THROW 52007,N'La nota 10 no debia recuperarse',1;
IF (SELECT nota FROM NotasLab05.dbo.Calificacion WHERE calificacion_id=2)<>7.25 THROW 52008,N'La correccion de la nota 2 no se recupero',1;
IF (SELECT estudiante FROM NotasLab05.dbo.Calificacion WHERE calificacion_id=1)<>N'Ana Martínez' THROW 52010,N'Acentos alterados',1;
IF (SELECT COUNT(*) FROM msdb.dbo.restorehistory WHERE destination_database_name=N'NotasLab05')<>3 THROW 52021,N'No se aplicaron tres restauraciones',1;` };
  if (s.includes('DELETE FROM NotasLab05.dbo.Calificacion')) return { sql: count(0) };
  if (s.includes('dbo.sp_add_job\n')) return { sql: `IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobschedules js ON js.job_id=j.job_id JOIN msdb.dbo.sysjobservers sv ON sv.job_id=j.job_id WHERE j.name=N'Respaldo diario NotasLab05') THROW 52013,N'Job incompleto',1;
IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'Diario 10 p. m.' AND freq_type=4 AND freq_interval=1 AND active_start_time=220000) THROW 52014,N'Programacion incorrecta',1;
IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysoperators o ON o.id=j.notify_email_operator_id WHERE j.name=N'Respaldo diario NotasLab05' AND j.notify_level_email=2 AND o.name=N'operador1' AND o.email_address=N'operador1@notaslab05.local') THROW 52022,N'Notificacion al operador incorrecta',1;` };
  if (s.includes('sp_start_job')) return { out: has('started successfully'), sql: `DECLARE @i INT=0;
WHILE @i<60 AND NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobhistory h JOIN msdb.dbo.sysjobs j ON j.job_id=h.job_id WHERE j.name=N'Respaldo diario NotasLab05' AND h.step_id=0)
BEGIN WAITFOR DELAY '00:00:01'; SET @i+=1; END;
IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobhistory h JOIN msdb.dbo.sysjobs j ON j.job_id=h.job_id WHERE j.name=N'Respaldo diario NotasLab05' AND h.step_id=0 AND h.run_status=1) THROW 52015,N'El job no termino con exito',1;
IF NOT EXISTS(SELECT 1 FROM msdb.dbo.backupset bs JOIN msdb.dbo.backupmediafamily f ON f.media_set_id=bs.media_set_id WHERE f.physical_device_name LIKE N'%NotasLab05_job.bak' AND bs.compressed_backup_size<bs.backup_size) THROW 52016,N'El respaldo del job no esta comprimido',1;` };
  if (s.includes('msdb.dbo.sysjobhistory AS h')) return { out: has('Respaldo completo', '(Job outcome)') };
  return {};
}

const pre = sql(`SET NOCOUNT ON;
IF DB_ID(N'NotasLab05') IS NOT NULL OR EXISTS(SELECT 1 FROM msdb.dbo.sysjobs WHERE name=N'Respaldo diario NotasLab05') OR EXISTS(SELECT 1 FROM msdb.dbo.sysoperators WHERE name=N'operador1')
  THROW 52000,N'Ya existen objetos de la guia; no se modifica una instalacion previa',1;
GO`);
if (pre.status !== 0) { console.error(pre.out); process.exit(1); }

let context = 'master';
let log = '';
let failed = false;
records.forEach((r, i) => {
  r.id = String(i + 1).padStart(2, '0');
  const check = checksFor(r);
  let res;
  if (r.lang === 'sql') {
    // Cada bloque se envía en una sesión nueva con la base activa del bloque anterior, como en una pestaña de SSMS.
    res = sql(`USE ${context};\nGO\n${r.code}`);
    const uses = [...r.code.matchAll(/^USE (\w+);/gm)];
    if (uses.length) context = uses[uses.length - 1][1];
  } else res = ps(r.code.trim().split('\n').join('; '));
  let ok = res.status === 0;
  if (ok && check.out) ok = check.out(res.out);
  if (ok && check.sql) {
    const c = sql(`SET NOCOUNT ON;\n${check.sql}\nGO`);
    ok = c.status === 0;
    if (!ok) res.out += '\n[COMPROBACION]\n' + c.out;
  }
  if (ok && check.after) ok = check.after();
  log += `\n===== ${r.id} ${r.lang.toUpperCase()} | ${r.section} | ${r.topic} | ${ok ? 'OK' : 'FALLO'}\n${r.code}\n----- salida -----\n${res.out}\n`;
  r.ok = ok;
  console.log(`${r.id} ${ok ? 'OK   ' : 'FALLO'} ${r.lang.padEnd(10)} ${r.section} | ${r.topic}`);
  if (!ok) failed = true;
});
fs.writeFileSync(path.join(output, 'ejecucion.log'), log, 'utf8');
const summary = { container, passed: !failed, blocks: records.length, successful: records.filter(r => r.ok).length, records: records.map(({ code, ...r }) => r) };
fs.writeFileSync(path.join(output, 'resultado.json'), JSON.stringify(summary, null, 2), 'utf8');
console.log(JSON.stringify({ passed: summary.passed, successful: summary.successful, total: summary.blocks, output }));
if (failed) process.exitCode = 1;
