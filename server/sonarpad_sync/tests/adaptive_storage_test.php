<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
function adaptive_check(bool $ok, string $message): void { if (!$ok) throw new RuntimeException($message); }
$pdo = new PDO('sqlite::memory:',null,null,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
$pdo->exec('PRAGMA foreign_keys=ON');
$service = new SyncService($pdo,['max_devices'=>10,'code_lifetime_seconds'=>600]);
$a=str_repeat('a',64); $b=str_repeat('b',64);
$group=$service->handle('create',$a,[])['group_id'];
$base=['radio'=>[],'preferences'=>[['id'=>'weather.city','data'=>['value'=>'Roma']]]];
for($i=0;$i<300;$i++) $base['radio'][]=['id'=>hash('sha256',"radio$i"),'data'=>['name'=>"Radio $i"]];
$initial=['sequence'=>1,'baseline'=>[],'state'=>$base];
$service->handle('sync',$a,$initial);
$code=$service->handle('code',$a,[])['code']; $service->handle('join',$b,['code'=>$code]);
$oldReply=$service->handle('sync',$b,$initial);
adaptive_check((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs WHERE format=0')->fetchColumn()===1,'aligned devices share one whole snapshot');
adaptive_check((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===0,'no collection metadata for aligned devices');
$changed=$base; $changed['preferences'][0]['data']['value']='Milano';
$newRequest=['sequence'=>2,'baseline'=>$base,'state'=>$changed];
$newReply=$service->handle('sync',$a,$newRequest);
adaptive_check((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs WHERE format=1')->fetchColumn()===2,'different revisions use shared collections');
adaptive_check((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===3,'large unchanged radio collection not duplicated');
adaptive_check($service->handle('sync',$b,$initial)==$oldReply,'old retry is unchanged after split');
$catchUp=['sequence'=>2,'baseline'=>$base,'state'=>$base];
$caughtUp=$service->handle('sync',$b,$catchUp);
adaptive_check((array)$caughtUp['state']==$changed,'second device receives current state');
adaptive_check((int)$pdo->query('SELECT COUNT(*) FROM sync_blobs WHERE format=0')->fetchColumn()===1,'realignment returns to whole gzip');
adaptive_check((int)$pdo->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===0,'unneeded collections removed after realignment');
adaptive_check($service->handle('sync',$a,$newRequest)==$newReply,'first device retry unchanged after compaction');
adaptive_check($service->handle('sync',$b,$catchUp)==$caughtUp,'second device retry unchanged after compaction');

// Migration from collections-v2: references and hashes must remain valid.
$hash=$pdo->query('SELECT state_ref FROM sync_groups')->fetchColumn();
write_transaction($pdo,function() use($pdo,$hash,$changed) {
    split_state($pdo,$hash,json_decode(json_encode($changed),false));
    $pdo->exec('UPDATE sync_groups SET storage_policy=0');
});
adaptive_check(migrate_states($pdo)===1,'old collection-layout group evaluated');
adaptive_check((int)$pdo->query('SELECT format FROM sync_blobs')->fetchColumn()===0,'old aligned collection layout compacted');
adaptive_check($service->handle('sync',$a,$newRequest)==$newReply,'migration preserves replay envelope and state');
adaptive_check(migrate_states($pdo)===0,'migration does not repeat indefinitely');

// Tiny revisions should not pay the index cost even when they differ.
$pdo2 = new PDO('sqlite::memory:',null,null,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
$small = new SyncService($pdo2,['max_devices'=>10,'code_lifetime_seconds'=>600]);
$small->handle('create',$a,[]); $code=$small->handle('code',$a,[])['code']; $small->handle('join',$b,['code'=>$code]);
$state=['preferences'=>[['id'=>'weather.city','data'=>['value'=>'Roma']]]];
$request=['sequence'=>1,'baseline'=>[],'state'=>$state];
$small->handle('sync',$a,$request); $small->handle('sync',$b,$request);
$new=$state; $new['preferences'][0]['data']['value']='Milano';
$small->handle('sync',$a,['sequence'=>2,'baseline'=>$state,'state'=>$new]);
adaptive_check((int)$pdo2->query('SELECT COUNT(*) FROM sync_parts')->fetchColumn()===0,'small unrelated snapshots stay whole');
echo "OK: aligned whole gzip, divergent collection dedup, realignment compaction, exact retries, v2 migration, stable policy, index-aware small-state choice.\n";
