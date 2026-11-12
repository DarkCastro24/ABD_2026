/* Valida la guía en un contenedor nuevo sin puertos ni volúmenes del usuario.
   Uso: node scripts/verify-guide.cjs DIRECTORIO_RESULTADOS
   Requiere la imagen local SQL Server 2025. No envía correos.
   Sustituye el ingreso interactivo de contraseña por una credencial efímera. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const output=process.argv[2];if(!output)throw Error('Indica un directorio de resultados.');
fs.mkdirSync(output,{recursive:true});
const records=JSON.parse(fs.readFileSync(path.join(__dirname,'expected-results.json'),'utf8'));
const source=fs.readFileSync(path.join(__dirname,'../G05.md'),'utf8').replace(/\r/g,'');
const blocks=[...source.matchAll(/<!-- lab-step: (\d+) -->\n```(sql|powershell)\n([\s\S]*?)```/g)];
if(blocks.length!==records.length||blocks.some((b,i)=>b[1]!==records[i].id||b[3].trim()!==records[i].code))throw Error('Fuente desincronizada');
const name='codex-lab5-check-'+Date.now(),password='Lab5!'+crypto.randomBytes(16).toString('hex');
let ownedId=null,removed=false,log='';const results=[];
function run(args,input){const r=spawnSync('docker',args,{input,encoding:'utf8',timeout:120000,windowsHide:true});return {status:r.status,out:((r.stdout||'')+(r.stderr||'')).split(password).join('[REDACTED]')};}
const sql=code=>run(['exec','-i','-e','SQLCMDPASSWORD='+password,name,'/opt/mssql-tools18/bin/sqlcmd','-S','localhost','-U','sa','-C','-b','-f','65001','-w','65535'],code+'\nGO\n');
function check(code){const r=sql('SET NOCOUNT ON;\n'+code);if(r.status!==0)throw Error(r.out);}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
try{
 const created=run(['run','-d','--pull','never','--name',name,'-e','ACCEPT_EULA=Y','-e','MSSQL_PID=Developer','-e','MSSQL_AGENT_ENABLED=true','-e','MSSQL_SA_PASSWORD='+password,'mcr.microsoft.com/mssql/server:2025-latest']);
 if(created.status!==0)throw Error(created.out);ownedId=created.out.trim();if(!/^[a-f0-9]{64}$/.test(ownedId))throw Error('ID inesperado');
 let ready=false;
 for(let i=0;i<40;i++){const r=sql("IF NOT EXISTS(SELECT 1 FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%' AND status_desc=N'Running') THROW 52000,N'Esperando Agent',1;");if(r.status===0){ready=true;break;}await wait(1500);}
 if(!ready)throw Error('No inició SQL Server/Agent');
 for(const a of [['exec','-u','0',name,'mkdir','-p','/backup'],['exec','-u','0',name,'chown','mssql:root','/backup']]){const r=run(a);if(r.status!==0)throw Error(r.out);}
 for(const rec of records){
  let out='',status=0;
  if(rec.lang==='sql'){
   if(rec.id==='28')for(let i=0;i<30;i++){const r=sql("IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobhistory h JOIN msdb.dbo.sysjobs j ON j.job_id=h.job_id WHERE j.name=N'Respaldo diario NotasLab05' AND h.step_id=0) THROW 52009,N'Esperando job',1;");if(r.status===0)break;await wait(1000);}
   const r=sql(rec.code);out=r.out;status=r.status;
  }else{
   for(const line of rec.code.split('\n')){
    const tokens=line.match(/"[^"]*"|\S+/g).map(t=>t.startsWith('"')?t.slice(1,-1):t);
    if(tokens.shift()!=='docker')throw Error('Comando no admitido');
    const a=tokens.map(t=>t.replaceAll('sqlserver-2025',name)).filter(t=>t!=='-it');
    if(a.some(t=>t.endsWith('/bcp')||t.endsWith('/sqlcmd')))a.push('-P',password);
    const r=run(a);out+=r.out;status=r.status;if(status!==0)break;
   }
  }
  log+='\nPASO '+rec.id+': '+rec.title+'\n'+out+'\n';if(status!==0)throw Error('Paso '+rec.id+': '+out);
  const n={'04':6,'06':8,'08':9,'10':10,'17':9,'19':0,'21':9}[rec.id];
  if(n!==undefined)check(`IF (SELECT COUNT(*) FROM NotasLab05.dbo.Calificacion)<>${n} THROW 52001,N'Conteo incorrecto',1;`);
  if(['08','17','21'].includes(rec.id))check("IF (SELECT nota FROM NotasLab05.dbo.Calificacion WHERE calificacion_id=2)<>7.25 THROW 52002,N'Nota incorrecta',1;");
  if(rec.id==='17')check("IF EXISTS(SELECT 1 FROM NotasLab05.dbo.Calificacion WHERE calificacion_id=10) THROW 52003,N'Fila 10 inesperada',1;");
  if(['14','15','16'].includes(rec.id))check(`IF (SELECT state_desc FROM sys.databases WHERE name=N'NotasLab05')<>N'${rec.id==='16'?'ONLINE':'RESTORING'}' THROW 52004,N'Estado incorrecto',1;`);
  if(['18','20'].includes(rec.id)&&!out.includes('9 rows copied'))throw Error('bcp no copió nueve filas');
  if(rec.id==='23'){const lines=out.trim().split(/\r?\n/).map(s=>s.trim()).filter(Boolean);if(lines.length!==9||!lines.includes('2,7.25'))throw Error('CSV inesperado: '+out);}
  if(rec.id==='26')check("IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysschedules WHERE name=N'NotasLab05_diario_22h_SV' AND active_start_time=40000 AND freq_type=4 AND freq_interval=1) THROW 52005,N'Horario incorrecto',1;");
  if(rec.id==='28')check("IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobhistory h JOIN msdb.dbo.sysjobs j ON j.job_id=h.job_id WHERE j.name=N'Respaldo diario NotasLab05' AND h.step_id=0 AND h.run_status=1) THROW 52006,N'Job fallido',1;");
  if(rec.id==='30')check("IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysoperators o ON o.id=j.notify_email_operator_id WHERE j.name=N'Respaldo diario NotasLab05' AND j.notify_level_email=2 AND o.name=N'operador_NotasLab05') THROW 52007,N'Notificacion incorrecta',1;");
  if(rec.id==='31')check("IF DB_ID(N'NotasLab05') IS NOT NULL THROW 52008,N'Limpieza incompleta',1;");
  results.push({id:rec.id,passed:true});console.log('OK '+rec.id+' '+rec.title);
 }
}catch(e){results.push({passed:false,error:e.message});process.exitCode=1;console.error(e.message);}
finally{
 if(ownedId&&/^[a-f0-9]{64}$/.test(ownedId)){const r=run(['rm','-f',ownedId]);removed=r.status===0;if(!removed){process.exitCode=1;console.error('No se eliminó el contenedor temporal '+ownedId);}}
 fs.writeFileSync(path.join(output,'ejecucion.log'),log,'utf8');
 fs.writeFileSync(path.join(output,'resultado.json'),JSON.stringify({temporaryContainer:name,removed,mailSent:false,steps:results},null,2),'utf8');
 console.log(JSON.stringify({passed:!process.exitCode,steps:results.filter(r=>r.passed).length,removed,mailSent:false}));
}
})();
