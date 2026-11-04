<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
function check_parts(bool $value, string $message): void { if (!$value) throw new RuntimeException($message); }
$pdo = new PDO('sqlite::memory:',null,null,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
$pdo->exec('PRAGMA foreign_keys=ON');
$service = new SyncService($pdo,['max_devices'=>10,'code_lifetime_seconds'=>600]);
$a=str_repeat('a',64); $b=str_repeat('b',64); $c=str_repeat('c',64);
$group=$service->handle('create',$a,[])['group_id'];
$base=['radio'=>[['id'=>'radio','data'=>['name'=>'Radio']]],'preferences'=>[['id'=>'weather.city','data'=>['value'=>'Roma']]]];
for($i=0;$i<300;$i++) $base['radio'][]=['id'=>hash('sha256',"station$i"),'data'=>['name'=>"Radio $i"]];
$request=['sequence'=>1,'baseline'=>[],'state'=>$base];
$service->handle('sync',$a,$request);
$code=$service->handle('code',$a,[])['code']; $service->handle('join',$b,['code'=>$code]);
$original=$service->handle('sync',$b,$request);
$changed=$base; $changed['preferences'][0]['data']['value']='Milano';
$service->handle('sync',$a,['sequence'=>2,'baseline'=>$base,'state'=>$changed]);
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===2,'two exact snapshots');
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===3,'one radio collection, two preference collections');
check_parts($service->handle('sync',$b,$request)==$original,'retry unaffected by collection split');
$other=$service->handle('create',$c,[])['group_id'];
$service->handle('sync',$c,['sequence'=>1,'baseline'=>[],'state'=>['radio'=>$base['radio']]]);
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===3,'shared collection across distinct users');
$service->handle('sync',$b,['sequence'=>2,'baseline'=>$base,'state'=>$base]);
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===2,'obsolete preference collected without deleting radio');
$service->handle('delete',$a,['confirm_group_id'=>$group]);
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===1,'another user still owns the radio');
check_parts((array)$service->handle('state',$c,[])['state']==['radio'=>$base['radio']],'other user unaffected');
$service->handle('delete',$c,['confirm_group_id'=>$other]);
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===0,'last owner removes collection');
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_blob_parts')->fetchColumn()===0,'no dangling reference edges');

// Upgrade the already shipped gzip-whole-state schema, not only plain JSON.
$pdo = new PDO('sqlite::memory:',null,null,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
$pdo->exec('CREATE TABLE sync_blobs(hash TEXT PRIMARY KEY,payload BLOB NOT NULL)');
init_schema($pdo);
$json=state_json(json_decode(json_encode($base),false)); $hash=hash('sha256',$json);
$q=$pdo->prepare('INSERT INTO sync_blobs(hash,payload) VALUES(?,?)');
$q->bindValue(1,$hash); $q->bindValue(2,gzencode($json,9),PDO::PARAM_LOB); $q->execute();
$pdo->prepare('INSERT INTO sync_groups(id,state_ref,created_at) VALUES(?,?,0)')->execute(['g',$hash]);
check_parts(load_state($pdo,$hash)==$base,'whole-state gzip readable before conversion');
check_parts(migrate_states($pdo)===1,'existing group evaluated');
check_parts(load_state($pdo,$hash)==$base,'snapshot hash and values retained');
check_parts((int)$pdo->query('SELECT format FROM sync_blobs')->fetchColumn()===0,'aligned group keeps whole-state gzip');
check_parts((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===0,'aligned group needs no collection references');
write_transaction($pdo, function () use ($pdo,$hash,$json) { split_state($pdo,$hash,json_decode($json,false)); });
$bad=$pdo->query('SELECT hash FROM sync_parts LIMIT 1')->fetchColumn();
$pdo->prepare('UPDATE sync_parts SET payload=? WHERE hash=?')->execute([gzencode('[]',9),$bad]);
try { load_state($pdo,$hash); throw new LogicException('Corrupt collection accepted'); }
catch (RuntimeException $e) { check_parts($e->getMessage()==='Invalid snapshot','collection integrity verified'); }
echo "OK: per-collection reuse, retained retries, cross-user isolation, collection GC, gzip-v1 migration, collection integrity.\n";
