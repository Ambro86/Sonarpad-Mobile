<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
function music_check(bool $ok, string $message): void {
    if (!$ok) throw new RuntimeException($message);
}
$wire = json_decode(file_get_contents(__DIR__ . '/../../../tests/fixtures/sonarmusic_sync.json'), true, 512, JSON_THROW_ON_ERROR);
validate_state($wire);
$pdo = new PDO('sqlite::memory:', null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
$pdo->exec('PRAGMA foreign_keys=ON');
$service = new SyncService($pdo, ['max_devices'=>3,'code_lifetime_seconds'=>600]);
$a = str_repeat('a',64); $b = str_repeat('b',64); $c = str_repeat('c',64);
$service->handle('create',$a,['device_name'=>'Windows']);
$first = (array)$service->handle('sync',$a,['sequence'=>1,'baseline'=>[], 'state'=>['sonarmusic'=>array_slice($wire['sonarmusic'],0,2)]])['state'];
$code = $service->handle('code',$a,[])['code'];
$service->handle('join',$b,['code'=>$code,'device_name'=>'Mobile']);
$second = (array)$service->handle('sync',$b,['sequence'=>1,'baseline'=>[], 'state'=>['sonarmusic'=>array_slice($wire['sonarmusic'],2)]])['state'];
music_check(count($second['sonarmusic']) === 4,'first sync must union both libraries');
$code = $service->handle('code',$a,[])['code'];
$service->handle('join',$c,['code'=>$code,'device_name'=>'Old Mac']);
$old = (array)$service->handle('sync',$c,['sequence'=>1,'baseline'=>[], 'state'=>['radio'=>[]]])['state'];
music_check($old['sonarmusic'] === $second['sonarmusic'],'older clients must preserve music');
$changed = $second; array_pop($changed['sonarmusic']);
$deletions = removed_collection_items($second,$changed);
$service->handle('confirm_deletions',$b,['sequence'=>2,'baseline'=>$second,'state'=>$changed,'explicit_deletions'=>$deletions]);
$deleted = (array)$service->handle('sync',$b,['sequence'=>2,'baseline'=>$second,'state'=>$changed,'explicit_deletions'=>$deletions])['state'];
music_check(count($deleted['sonarmusic']) === 3,'explicit removal propagates');
$back = (array)$service->handle('sync',$a,['sequence'=>2,'baseline'=>$first,'state'=>$first])['state'];
music_check($back['sonarmusic'] === $deleted['sonarmusic'],'Windows receives mobile changes without resurrection');
echo "SonarMusic server round trip passed\n";
