<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';

function check(bool $condition, string $message): void {
    if (!$condition) throw new RuntimeException($message);
}
function fails(callable $fn, string $expected): void {
    try { $fn(); } catch (ApiError $e) { check($e->errorName === $expected, $e->errorName); return; }
    throw new RuntimeException('Expected ' . $expected);
}
function item(string $id, string $name): array { return ['id' => $id, 'data' => ['name' => $name]]; }
function state(array $response): array { return (array)$response['state']; }

$pdo = new PDO('sqlite::memory:', null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
$pdo->exec('PRAGMA foreign_keys=ON');
$service = new SyncService($pdo, ['max_devices' => 3, 'code_lifetime_seconds' => 600]);
$a = bin2hex(random_bytes(32)); $b = bin2hex(random_bytes(32)); $c = bin2hex(random_bytes(32));
$first = $service->handle('create', $a, ['device_name' => 'Windows']);
check($service->handle('create', $a, [])['group_id'] === $first['group_id'], 'create retry');
$request = ['sequence' => 1, 'baseline' => [], 'state' => ['radio' => [item('one', 'One')], 'sonartube' => [item('video:x', 'Video')]]];
$saved = $service->handle('sync', $a, $request);
check(state($service->handle('sync', $a, $request)) === state($saved), 'timeout retry');
fails(fn() => $service->handle('sync', $a, ['sequence' => 1, 'baseline' => [], 'state' => []]), 'sequence_reused');
$code = $service->handle('code', $a, [])['code'];
$joined = $service->handle('join', $b, ['code' => $code, 'device_name' => 'iPhone']);
check($joined['group_id'] === $first['group_id'], 'same group');
check($service->handle('join', $b, ['code' => $code])['device_id'] === $joined['device_id'], 'join retry');
fails(fn() => $service->handle('join', $c, ['code' => $code]), 'invalid_or_expired_code');
$fromB = $service->handle('sync', $b, ['sequence' => 1, 'baseline' => [], 'state' => ['radio' => [item('two', 'Two')]]]);
check(count(state($fromB)['radio']) === 2, 'first merge preserves both');
check(count(state($fromB)['sonartube']) === 1, 'unsupported collection preserved');
$baseA = state($service->handle('sync', $a, ['sequence' => 2, 'baseline' => state($saved), 'state' => state($saved)]));
$delete = $baseA; $delete['radio'] = [item('two', 'Two')];
$service->handle('confirm_deletions', $a, ['sequence' => 3, 'baseline' => $baseA, 'state' => $delete, 'explicit_deletions' => removed_collection_items($baseA, $delete)]);
$service->handle('sync', $a, ['sequence' => 3, 'baseline' => $baseA, 'state' => $delete, 'explicit_deletions' => removed_collection_items($baseA, $delete)]);
$editB = state($fromB); foreach ($editB['radio'] as &$row) if ($row['id'] === 'one') $row['data']['name'] = 'Offline edit'; unset($row);
$result = $service->handle('sync', $b, ['sequence' => 2, 'baseline' => state($fromB), 'state' => $editB]);
check(array_column(state($result)['radio'], 'id') === ['two'], 'offline edit does not resurrect deletion');
$oldCode = $service->handle('code', $a, [])['code'];
$newCode = $service->handle('code', $a, [])['code'];
fails(fn() => $service->handle('join', $c, ['code' => $oldCode]), 'invalid_or_expired_code');
$pdo->exec('UPDATE sync_groups SET code_expires=0');
fails(fn() => $service->handle('join', $c, ['code' => $newCode]), 'invalid_or_expired_code');
$other = $service->handle('create', $c, []);
$service->handle('revoke', $c, ['device_id' => $joined['device_id']]);
check($service->handle('state', $b, [])['group_id'] === $first['group_id'], 'cannot revoke another group');
$service->handle('revoke', $a, ['device_id' => $joined['device_id']]);
fails(fn() => $service->handle('state', $b, []), 'unauthorized');
$invalid = ['sequence' => 4, 'baseline' => [], 'state' => ['radio' => [item('dup', 'x'), item('dup', 'y')]]];
fails(fn() => $service->handle('sync', $a, $invalid), 'invalid_item');
check($service->handle('state', $a, [])['sequence'] === 3, 'failed sync rolled back');
for ($i = 0; $i < 20; $i++) $service->rateLimit('127.0.0.1', 'join');
fails(fn() => $service->rateLimit('127.0.0.1', 'join'), 'rate_limited');
fails(fn() => $service->handle('delete', $a, []), 'confirmation_required');
$service->handle('delete', $a, ['confirm_group_id' => $first['group_id']]);
fails(fn() => $service->handle('state', $a, []), 'unauthorized');
check($service->handle('state', $c, [])['group_id'] === $other['group_id'], 'delete isolated');

$remote = ['radio' => [['id' => 'r', 'data' => ['name' => 'Remote', 'url' => 'old', 'extra' => true]]]];
$base = ['radio' => [['id' => 'r', 'data' => ['name' => 'Old', 'url' => 'old']]]];
$local = ['radio' => [['id' => 'r', 'data' => ['name' => 'Old', 'url' => 'new']]]];
$merged = merge_state($remote, $base, $local);
check($merged['radio'][0]['data'] === ['name' => 'Remote', 'url' => 'new', 'extra' => true], 'independent field edits');
$all = [];
foreach (SYNC_COLLECTIONS as $collection) $all[$collection] = $collection === 'preferences' ? [['id'=>'cutter.mode','data'=>['value'=>'advanced']]] : [item($collection . ':one', 'One')];
check(merge_state([], [], validate_state($all)) === $all, 'all seven collections accepted');
$reverse = ['radio' => [item('b', 'B'), item('a', 'A')]];
$original = ['radio' => [item('a', 'A'), item('b', 'B')]];
check(merge_state($original, $original, $reverse) === $reverse, 'local reorder');
check(merge_state($reverse, $original, $original) === $reverse, 'remote reorder preserved');
fails(fn() => validate_state(['settings' => []]), 'invalid_collection');
$configLimit = new SyncService($pdo, ['max_devices' => 1, 'code_lifetime_seconds' => 600]);
$limitCode = $configLimit->handle('code', $c, [])['code'];
fails(fn() => $configLimit->handle('join', $a, ['code' => $limitCode]), 'device_limit');
check($configLimit->handle('state', $c, [])['group_id'] === $other['group_id'], 'limit transaction rollback');
echo "OK: pairing, retry, merge, offline deletion, unknown collections, expiry, revocation, isolation, validation, rollback, rate limit and deletion.\n";

$pref = fn($v) => ['preferences'=>[['id'=>'cutter.mode','data'=>['value'=>$v]]]];
check(merge_state($pref('advanced'), [], $pref('guided')) === $pref('advanced'), 'new device preserves cloud preferences');
check(merge_state($pref('advanced'), $pref('advanced'), $pref('guided')) === $pref('guided'), 'explicit preference edit');
fails(fn()=>validate_state(['preferences'=>[['id'=>'cutter.mode','data'=>['value'=>str_repeat('x',2049)]]]]), 'invalid_preference');

$many = [];
for ($i=0; $i<129; $i++) $many[]=['id'=>'test.p'.$i,'data'=>['value'=>true]];
fails(fn()=>validate_state(['preferences'=>$many]), 'preferences_limit');
fails(fn()=>merge_state(['preferences'=>array_slice($many,0,100)], [], ['preferences'=>array_slice($many,100)]), 'preferences_limit');
$large=[];
for ($i=0; $i<20; $i++) $large[]=['id'=>'test.p'.$i,'data'=>['value'=>str_repeat('x',1800)]];
fails(fn()=>validate_state(['preferences'=>$large]), 'preferences_limit');
echo "OK: preference initial join, explicit edits, per-value, count and merged size limits.\n";
