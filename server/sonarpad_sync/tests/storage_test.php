<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
function verify_storage(bool $ok, string $message): void { if (!$ok) throw new RuntimeException($message); }
function memory_db(): PDO {
    $pdo = new PDO('sqlite::memory:', null, null, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
    $pdo->exec('PRAGMA foreign_keys=ON');
    return $pdo;
}
$pdo = memory_db();
$config = ['max_devices'=>10,'code_lifetime_seconds'=>600];
$service = new SyncService($pdo, $config);
$a = str_repeat('a',64); $b = str_repeat('b',64); $c = str_repeat('c',64);
$first = $service->handle('create',$a,[]);
$sample = ['radio'=>[['id'=>'https://example.org/one','data'=>['name'=>'Radio città 🌍','stream_url'=>'https://example.org/one','language_code'=>'it']]]];
$request = ['sequence'=>1,'baseline'=>[],'state'=>$sample];
$saved = $service->handle('sync',$a,$request);
$code = $service->handle('code',$a,[])['code'];
$service->handle('join',$b,['code'=>$code]);
$service->handle('sync',$b,$request);
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===1,'two device caches and current state share one blob');
$other = $service->handle('create',$c,[]);
$service->handle('sync',$c,$request);
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===1,'identical data across groups deduplicated without shared authorization');
$changed=$sample; $changed['radio'][0]['data']['name']='Updated';
$service->handle('sync',$a,['sequence'=>2,'baseline'=>$sample,'state'=>$changed]);
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===2,'old snapshot retained for another device');
$retry=$service->handle('sync',$b,$request);
verify_storage($retry['revision']===$saved['revision']+1 && (array)$retry['state']==$sample,'retry returns old data and original revision');
$service->handle('sync',$b,['sequence'=>2,'baseline'=>$sample,'state'=>$sample]);
$service->handle('delete',$c,['confirm_group_id'=>$other['group_id']]);
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===1,'unreferenced old blob removed after last reference');
verify_storage((array)$service->handle('state',$a,[])['state']==$changed,'deleting another group preserves shared data');
$hash=$pdo->query('SELECT hash FROM sync_blobs')->fetchColumn();
$reordered=['radio'=>[['data'=>['language_code'=>'it','stream_url'=>'https://example.org/one','name'=>'Updated'],'id'=>'https://example.org/one']]];
verify_storage(store_state($pdo,$reordered)===$hash,'object key order does not defeat dedup');
$gzip=$pdo->query('SELECT payload FROM sync_blobs')->fetchColumn();
verify_storage(substr($gzip,0,2)==="\x1f\x8b" && ord($gzip[8])===2,'gzip maximum compression');
verify_storage(load_state($pdo,$hash)==$changed,'unicode roundtrip');
write_transaction($pdo, function () use ($pdo) {
    $a=['tv'=>[['id'=>'first','data'=>['name'=>'First']],['id'=>'second','data'=>['name'=>'Second']]]];
    $b=$a; $b['tv']=array_reverse($b['tv']);
    $ha=store_state($pdo,$a); $hb=store_state($pdo,$b);
    verify_storage($ha!==$hb && load_state($pdo,$hb)==$b,'list order preserved');
    collect_states($pdo,[$ha,$hb]);
});
$service->handle('delete',$a,['confirm_group_id'=>$first['group_id']]);
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===0,'delete collects all group blobs');

// Simulate the original schema, including a device awaiting an old response.
$pdo = memory_db();
$pdo->exec("CREATE TABLE sync_groups(id TEXT PRIMARY KEY,state_json TEXT NOT NULL DEFAULT '{}',revision INTEGER NOT NULL DEFAULT 0,code_hash TEXT UNIQUE,code_expires INTEGER,created_at INTEGER NOT NULL);
CREATE TABLE sync_devices(id TEXT PRIMARY KEY,group_id TEXT NOT NULL REFERENCES sync_groups(id) ON DELETE CASCADE,token_hash TEXT NOT NULL UNIQUE,name TEXT NOT NULL,created_at INTEGER NOT NULL,last_seen INTEGER NOT NULL,sequence INTEGER NOT NULL DEFAULT 0,request_hash TEXT,response_json TEXT);");
$insert=$pdo->prepare('INSERT INTO sync_groups(id,state_json,revision,created_at) VALUES(?,?,2,0)');
$device=$pdo->prepare('INSERT INTO sync_devices(id,group_id,token_hash,name,created_at,last_seen,sequence,request_hash,response_json) VALUES(?,?,?,?,0,0,1,?,?)');
for($i=0;$i<7;$i++) {
    $insert->execute(["g$i",json_encode($changed)]);
    $old=['schema_version'=>1,'group_id'=>"g$i",'device_id'=>"d$i",'revision'=>1,'sequence'=>1,'state'=>$sample];
    $device->execute(["d$i","g$i",hash('sha256',str_repeat((string)($i+1),64)),'Old',hash('sha256',json_encode($request,JSON_THROW_ON_ERROR)),json_encode($old)]);
}
$service = new SyncService($pdo,$config);
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_groups WHERE state_ref IS NULL')->fetchColumn()===5,'migration bounded');
$unmigrated = $service->handle('sync',str_repeat('7',64),$request);
verify_storage((array)$unmigrated['state']==$sample && $unmigrated['revision']===1,'legacy retry readable during migration');
while(migrate_states($pdo)>0) {}
$migrated = $service->handle('sync',str_repeat('7',64),$request);
verify_storage($migrated==$unmigrated,'exact logical retry preserved by migration');
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===2,'legacy seven groups and caches deduplicated');
verify_storage((int)$pdo->query("SELECT COUNT(*) FROM sync_groups WHERE state_json<>'{}'")->fetchColumn()===0,'legacy plaintext cleared');
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_groups')->fetchColumn()===7,'inactive users not deleted');
$hash=$pdo->query('SELECT hash FROM sync_blobs LIMIT 1')->fetchColumn();
$pdo->prepare('UPDATE sync_blobs SET payload=? WHERE hash=?')->execute([gzencode('{}',9),$hash]);
try { load_state($pdo,$hash); throw new LogicException('Corruption accepted'); }
catch(RuntimeException $e) { verify_storage($e->getMessage()==='Invalid snapshot','corruption fails closed'); }
$pdo = memory_db(); init_schema($pdo);
$pdo->exec("INSERT INTO sync_groups(id,state_json,created_at) VALUES('valid','{}',0),('invalid','broken',0)");
try { migrate_states($pdo); throw new LogicException('Invalid migration accepted'); }
catch(JsonException) {}
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_groups WHERE state_ref IS NULL')->fetchColumn()===2,'migration block rolls back on invalid data');
verify_storage((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn()===0,'rollback leaves no orphan blobs');
echo "OK: gzip level 9, dedup, reference GC, isolation, Unicode, bounded legacy migration, exact retry, inactive users preserved, integrity.\n";
