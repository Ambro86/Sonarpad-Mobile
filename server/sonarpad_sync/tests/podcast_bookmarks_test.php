<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
function podcast_check(bool $ok, string $message): void {
    if (!$ok) throw new RuntimeException($message);
}
$wire = json_decode(file_get_contents(__DIR__ . '/../../../tests/fixtures/podcast_bookmarks_sync.json'), true, 512, JSON_THROW_ON_ERROR);
validate_state($wire);
$pdo = new PDO('sqlite::memory:', null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
$pdo->exec('PRAGMA foreign_keys=ON');
$service = new SyncService($pdo, ['max_devices'=>3,'code_lifetime_seconds'=>600]);
$a = str_repeat('a',64); $b = str_repeat('b',64); $c = str_repeat('c',64);
$service->handle('create',$a,['device_name'=>'Windows']);
$first = (array)$service->handle('sync',$a,['sequence'=>1,'baseline'=>[], 'state'=>$wire])['state'];
$code = $service->handle('code',$a,[])['code'];
$service->handle('join',$b,['code'=>$code,'device_name'=>'Mobile']);
$mobile = (array)$service->handle('sync',$b,['sequence'=>1,'baseline'=>[], 'state'=>['podcast_bookmarks'=>[]]])['state'];
podcast_check($mobile['podcast_bookmarks'] === $first['podcast_bookmarks'], 'mobile receives PC resume points');
$latest = $mobile;
$latest['podcast_bookmarks'][0]['data']['position_seconds'] = 0;
$latest['podcast_bookmarks'][0]['data']['updated_at'] = 1794564300000;
$reset = (array)$service->handle('sync',$b,['sequence'=>2,'baseline'=>$mobile,'state'=>$latest])['state'];
$offline = $first;
$offline['podcast_bookmarks'][0]['data']['position_seconds'] = 180;
$offline['podcast_bookmarks'][0]['data']['updated_at'] = 1794564200000;
$back = (array)$service->handle('sync',$a,['sequence'=>2,'baseline'=>$first,'state'=>$offline])['state'];
podcast_check($back['podcast_bookmarks'] === $reset['podcast_bookmarks'], 'offline PC cannot resurrect reset bookmark');
$code = $service->handle('code',$a,[])['code'];
$service->handle('join',$c,['code'=>$code,'device_name'=>'Mac']);
$mac = (array)$service->handle('sync',$c,['sequence'=>1,'baseline'=>[], 'state'=>$wire])['state'];
podcast_check($mac['podcast_bookmarks'] === $reset['podcast_bookmarks'], 'first Mac connection cannot overwrite newer positions');
$old = (array)$service->handle('sync',$c,['sequence'=>2,'baseline'=>$mac,'state'=>['radio'=>[]]])['state'];
podcast_check($old['podcast_bookmarks'] === $reset['podcast_bookmarks'], 'omitted collection is preserved');
echo "Podcast bookmarks server round trip passed\n";
