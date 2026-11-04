<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
$different = in_array('--different-revisions', $argv, true);
$path = tempnam(sys_get_temp_dir(), 'sonarpad-space-');
$pdo = null;
try {
    $pdo = new PDO('sqlite:'.$path, null, null, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
    init_schema($pdo);
    $users = 100; $devices = 3; $rawTotal = 0;
    mt_srand(20261104);
    write_transaction($pdo, function () use ($pdo,$users,$devices,$different,&$rawTotal) {
        $group=$pdo->prepare('INSERT INTO sync_groups(id,state_json,created_at) VALUES(?,?,0)');
        $device=$pdo->prepare('INSERT INTO sync_devices(id,group_id,token_hash,name,created_at,last_seen,response_json) VALUES(?,?,?,?,0,0,?)');
        for($u=0;$u<$users;$u++) {
            $state=['preferences'=>[['id'=>'weather.city','data'=>['value'=>"Città $u"]]],'radio'=>[],'news_sources'=>[],'podcasts'=>[],'sonartube'=>[]];
            foreach(['radio'=>100,'news_sources'=>100,'podcasts'=>50,'sonartube'=>50] as $kind=>$count) {
                for($i=0;$i<$count;$i++) {
                    $random=sprintf('%08x%08x',mt_rand(),mt_rand());
                    $url="https://example.org/$kind/$random";
                    $data=match($kind) {
                        'radio'=>['name'=>"Radio città $i",'stream_url'=>$url,'language_code'=>'it'],
                        'news_sources'=>['language'=>'it','title'=>"Notizie $i",'url'=>$url,'folder_path'=>['Personali',"Cartella ".($i%10)]],
                        default=>['title'=>"Preferito $i",'url'=>$url],
                    };
                    $state[$kind][]=['id'=>$url,'data'=>$data];
                }
            }
            if ($different) $state['preferences'][0]['data']['value']="Città $u-2";
            $json=json_encode($state,JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE);
            $group->execute(["g$u",$json]); $rawTotal+=strlen($json);
            for($d=0;$d<$devices;$d++) {
                if ($different) $state['preferences'][0]['data']['value']="Città $u-$d";
                $response=json_encode(['schema_version'=>1,'group_id'=>"g$u",'device_id'=>"d$u-$d",'revision'=>1,'sequence'=>1,'state'=>$state]);
                $device->execute(["d$u-$d","g$u",hash('sha256',"$u-$d"),'Device',$response]);
            }
        }
    });
    clearstatcache(true,$path); $before=filesize($path);
    $start=microtime(true);
    // Reproduce the previous whole-state gzip/dedup version for a fair
    // on-disk comparison on exactly the same data and SQLite schema.
    write_transaction($pdo, function () use ($pdo) {
        $put = function (mixed $state) use ($pdo): string {
            $json=state_json($state); $hash=hash('sha256',$json);
            $q=$pdo->prepare('INSERT OR IGNORE INTO sync_blobs(hash,payload,format) VALUES(?,?,0)');
            $q->bindValue(1,$hash); $q->bindValue(2,gzencode($json,9),PDO::PARAM_LOB); $q->execute();
            return $hash;
        };
        foreach ($pdo->query('SELECT id,state_json FROM sync_groups')->fetchAll() as $row) {
            $hash=$put(json_decode($row['state_json'],false,32,JSON_THROW_ON_ERROR));
            $pdo->prepare("UPDATE sync_groups SET state_ref=?,state_json='{}' WHERE id=?")->execute([$hash,$row['id']]);
        }
        foreach ($pdo->query('SELECT id,response_json FROM sync_devices')->fetchAll() as $row) {
            $response=json_decode($row['response_json'],false,32,JSON_THROW_ON_ERROR);
            $hash=$put($response->state); unset($response->state);
            $pdo->prepare('UPDATE sync_devices SET response_state_ref=?,response_json=? WHERE id=?')->execute([$hash,json_encode($response),$row['id']]);
        }
    });
    $pdo->exec('VACUUM'); clearstatcache(true,$path); $whole=filesize($path);
    while(migrate_states($pdo,20)>0) {}
    $gzip=(int)$pdo->query('SELECT COALESCE(SUM(length(payload)),0) FROM sync_blobs')->fetchColumn() + (int)$pdo->query('SELECT COALESCE(SUM(length(payload)),0) FROM sync_parts')->fetchColumn();
    $blobs=(int)$pdo->query('SELECT COUNT(*) FROM sync_blobs')->fetchColumn();
    $free=(int)$pdo->query('PRAGMA freelist_count')->fetchColumn()*(int)$pdo->query('PRAGMA page_size')->fetchColumn();
    $pdo->exec('VACUUM'); clearstatcache(true,$path); $after=filesize($path);
    echo json_encode(['synthetic_users'=>$users,'devices_per_user'=>$devices,'favorites_per_user'=>300,
        'different_device_revisions'=>$different,'whole_state_gzip_database_bytes'=>$whole,
        'saving_vs_whole_state_percent'=>round(100*(1-$after/$whole),2),'mean_state_bytes'=>$rawTotal/$users,'mean_gzip_bytes'=>$gzip/$users,'distinct_blobs'=>$blobs,
        'database_before_bytes'=>$before,'database_after_compaction_bytes'=>$after,
        'reusable_bytes_before_compaction'=>$free,'disk_saving_percent'=>round(100*(1-$after/$before),2),
        'projected_1000_users_bytes'=>$after*10,'migration_seconds'=>round(microtime(true)-$start,2)],JSON_PRETTY_PRINT)."\n";
} finally {
    $pdo=null;
    foreach ([$path,$path.'-wal',$path.'-shm'] as $file) if (is_file($file)) unlink($file);
}
