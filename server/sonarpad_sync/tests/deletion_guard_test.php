<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
function guard_check(bool $ok, string $msg): void { if (!$ok) throw new RuntimeException($msg); }
function blocked(callable $fn): void {
    try { $fn(); } catch (ApiError $e) { guard_check($e->errorName === 'deletion_confirmation_required', $e->errorName); return; }
    throw new RuntimeException('Deletion was not blocked');
}
foreach (SYNC_COLLECTIONS as $collection) {
    $pdo = new PDO('sqlite::memory:', null, null, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
    $pdo->exec('PRAGMA foreign_keys=ON');
    $s = new SyncService($pdo, ['max_devices'=>3,'code_lifetime_seconds'=>600]);
    $token = str_repeat('a',64); $s->handle('create',$token,[]);
    $rows = array_map(fn($i)=>['id'=>(string)$i,'data'=>['title'=>'Item '.$i]],range(1,30));
    if ($collection === 'preferences') $rows = array_map(fn($i)=>['id'=>'test.pref'.$i,'data'=>['value'=>$i]],range(1,30));
    if ($collection === 'podcast_bookmarks') $rows = array_map(fn($i)=>['id'=>'https://example.org/'.$i.'.mp3','data'=>['url'=>'https://example.org/'.$i.'.mp3','title'=>'Episode '.$i,'position_seconds'=>$i,'updated_at'=>1000]],range(1,30));
    $before = [$collection=>$rows];
    $s->handle('sync',$token,['sequence'=>1,'baseline'=>[],'state'=>$before]);
    $after = [$collection=>array_slice($rows,0,25)];
    $request = ['sequence'=>2,'baseline'=>$before,'state'=>$after];
    blocked(fn()=>$s->handle('sync',$token,$request));
    guard_check((array)$s->handle('state',$token,[])['state']==$before, 'Blocked request must leave cloud unchanged');
    guard_check($s->handle('state',$token,[])['sequence']===1, 'No sequence advance on rejection');
    blocked(fn()=>$s->handle('confirm_deletions',$token,$request));
    $request['explicit_deletions'] = [$collection=>array_map(fn($row)=>(string)$row['id'],array_slice($rows,25))];
    $s->handle('confirm_deletions',$token,$request);
    $changed=$request; $changed['state'][$collection]=[];
    blocked(fn()=>$s->handle('sync',$token,$changed));
    $reply=$s->handle('sync',$token,$request);
    guard_check((array)$reply['authorized_deletions']==$request['explicit_deletions'], 'Incoming deletion proof is restricted to accepted removals');
    guard_check((array)$reply['state']==$after, 'Exact confirmation allows deletion');
    guard_check($s->handle('sync',$token,$request)==$reply, 'Identical retry is safe');
    $backup=$pdo->query('SELECT payload FROM sync_recovery')->fetchColumn();
    guard_check(json_decode(gzdecode($backup),true)==$before, 'Recovery retains full pre-deletion state');
    $replacement=$after; $replacement[$collection][0]=['id'=>'replacement','data'=>$collection === 'preferences' ? ['value'=>42] : ['title'=>'New']];
    if ($collection === 'podcast_bookmarks') $replacement[$collection][0]=['id'=>'https://example.org/new.mp3','data'=>['url'=>'https://example.org/new.mp3','title'=>'New','position_seconds'=>1,'updated_at'=>1000]];
    blocked(fn()=>$s->handle('sync',$token,['sequence'=>3,'baseline'=>$after,'state'=>$replacement]));
    blocked(fn()=>$s->handle('sync',$token,['sequence'=>3,'baseline'=>$after,'state'=>[$collection=>[]]]));
    $other=str_repeat('b',64); $group=$s->handle('create',$other,[])['group_id'];
    $s->handle('delete',$other,['confirm_group_id'=>$group]);
    guard_check((int)$pdo->query('SELECT COUNT(*) FROM sync_recovery')->fetchColumn()===1,'Other group cannot remove recovery');
    $added=$after; $added[$collection][]=$rows[29];
    $readded=$s->handle('sync',$token,['sequence'=>3,'baseline'=>$after,'state'=>$added]);
    guard_check(!in_array((string)$rows[29]['id'], (array)((array)$readded['authorized_deletions'])[$collection], true), 'Re-added item invalidates stale proof');
    echo "OK $collection: 30->25 blocked, exact approval, retries, recovery, same-count replacement, empty state blocked\n";
}
