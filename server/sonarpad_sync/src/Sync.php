<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/schema.php';
require_once __DIR__ . '/Merge.php';
require_once __DIR__ . '/Storage.php';
require_once __DIR__ . '/Log.php';

final class SyncService {
    public function __construct(private PDO $pdo, private array $config) { init_schema($pdo); migrate_states($pdo); }

    private function logReduction(string $stage, array $device, int $sequence, array $before, array $after): void {
        if (!isset($this->config['log_path'])) return;
        $previous = array_column($before['preferences'] ?? [], null, 'id');
        foreach ($after['preferences'] ?? [] as $row) {
            if (isset($previous[$row['id']]) && $previous[$row['id']]['data'] !== $row['data']) {
                // Values may contain credentials; record only the preference key.
                sync_log($this->config, 'preference_changed', [
                    'request_id' => $this->config['request_id'] ?? '-', 'action' => 'sync',
                    'stage' => $stage, 'group_id' => $device['group_id'], 'device_id' => $device['id'],
                    'sequence' => $sequence, 'preference_id' => $row['id']]);
            }
        }
        foreach (removed_collection_items($before, $after) as $collection => $ids) {
            $metadata = ['request_id' => $this->config['request_id'] ?? '-', 'action' => 'sync',
                'stage' => $stage, 'group_id' => $device['group_id'], 'device_id' => $device['id'],
                'sequence' => $sequence, 'collection' => $collection,
                'before_count' => count($before[$collection] ?? []), 'after_count' => count($after[$collection] ?? []), 'removed_count' => count($ids)];
            sync_log($this->config, 'collection_reduction', $metadata);
            foreach ($ids as $id) sync_log($this->config, 'removed_item', $metadata + ['item_sha256' => hash('sha256', (string)$id)]);
        }
    }
    private function validateExplicitDeletions(array $body, array $removed): void {
        $explicit = $body['explicit_deletions'] ?? [];
        if (!is_array($explicit)) api_fail(400, 'invalid_deletions');
        foreach ($removed as $collection => $ids) {
            $allowed = $explicit[$collection] ?? [];
            if (!is_array($allowed)) api_fail(400, 'invalid_deletions');
            foreach ($ids as $id) if (!in_array((string)$id, $allowed, true)) api_fail(409, 'deletion_confirmation_required');
        }
    }
    private function row(string $sql, array $params): array|false {
        $q = $this->pdo->prepare($sql); $q->execute($params); return $q->fetch();
    }
    private function execute(string $sql, array $params): void {
        $this->pdo->prepare($sql)->execute($params);
    }
    public function rateLimit(string $ip, string $action): void {
        $limit = in_array($action, ['create', 'join'], true) ? 20 : 600;
        write_transaction($this->pdo, function () use ($ip, $action, $limit) {
            $now = time();
            $this->execute('DELETE FROM sync_rate_limits WHERE expires < ?', [$now]);
            $key = hash('sha256', $ip . '|' . (in_array($action, ['create', 'join'], true) ? 'pair' : 'api'));
            $r = $this->row('SELECT count FROM sync_rate_limits WHERE bucket=?', [$key]);
            if ($r && (int)$r['count'] >= $limit) api_fail(429, 'rate_limited');
            $this->execute('INSERT INTO sync_rate_limits(bucket,count,expires) VALUES(?,1,?) ON CONFLICT(bucket) DO UPDATE SET count=count+1', [$key, $now + 3600]);
        });
    }
    private function device(string $token): array|false {
        return $this->row('SELECT * FROM sync_devices WHERE token_hash=?', [hash('sha256', $token)]);
    }
    private function snapshot(array $device): array {
        $group = $this->row('SELECT * FROM sync_groups WHERE id=?', [$device['group_id']]);
        if (!$group) api_fail(401, 'unauthorized');
        $q = $this->pdo->prepare('SELECT collection,item_id FROM sync_deletions WHERE group_id=?');
        $q->execute([$group['id']]);
        $deletions = [];
        foreach ($q as $row) $deletions[$row['collection']][] = $row['item_id'];
        return ['authorized_deletions' => (object)$deletions, 'schema_version' => 1, 'group_id' => $group['id'], 'device_id' => $device['id'],
            'revision' => (int)$group['revision'], 'sequence' => (int)$device['sequence'],
            'state' => (object)load_state($this->pdo, $group['state_ref'], $group['state_json'])];
    }
    private function newDevice(string $group, string $token, array $body): array {
        $name = $body['device_name'] ?? 'Sonarpad';
        if (!is_string($name) || strlen($name) > 160 || trim($name) === '') api_fail(400, 'invalid_device_name');
        $id = bin2hex(random_bytes(16));
        $this->execute('INSERT INTO sync_devices(id,group_id,token_hash,name,created_at,last_seen) VALUES(?,?,?,?,?,?)',
            [$id, $group, hash('sha256', $token), $name, time(), time()]);
        return $this->device($token);
    }
    private function invitation(string $group): array {
        // Numeric and easy to dictate. Unique among unexpired invitations.
        do {
            $code = (string)random_int(10000000, 99999999);
            $hash = hash('sha256', $code);
        } while ($this->row('SELECT id FROM sync_groups WHERE code_hash=?', [$hash]));
        $expiry = time() + (int)$this->config['code_lifetime_seconds'];
        $this->execute('UPDATE sync_groups SET code_hash=?,code_expires=? WHERE id=?', [$hash, $expiry, $group]);
        return ['code' => $code, 'expires_at' => $expiry];
    }
    public function handle(string $action, string $token, array $body): array {
        if (!preg_match('/^[a-f0-9]{64}$/D', $token)) api_fail(401, 'unauthorized');
        if (($body['schema_version'] ?? 1) !== 1) api_fail(400, 'unsupported_schema');
        return write_transaction($this->pdo, function () use ($action, $token, $body) {
            $device = $this->device($token);
            if ($action === 'create' || $action === 'join') {
                // The app persists a random 32-byte credential before requesting pairing.
                // Repeating a timed-out request cannot create a second device/group.
                if ($device) return $this->snapshot($device);
                if ($action === 'create') {
                    $group = bin2hex(random_bytes(16));
                    $this->execute('INSERT INTO sync_groups(id,created_at) VALUES(?,?)', [$group, time()]);
                } else {
                    $code = $body['code'] ?? '';
                    if (!is_string($code) || !preg_match('/^[0-9]{8}$/D', $code)) api_fail(400, 'invalid_code');
                    $r = $this->row('SELECT id FROM sync_groups WHERE code_hash=? AND code_expires>=?', [hash('sha256', $code), time()]);
                    if (!$r) api_fail(400, 'invalid_or_expired_code');
                    $group = $r['id'];
                    $count = $this->row('SELECT COUNT(*) AS n FROM sync_devices WHERE group_id=?', [$group]);
                    if ((int)$count['n'] >= (int)$this->config['max_devices']) api_fail(409, 'device_limit');
                    $this->execute('UPDATE sync_groups SET code_hash=NULL,code_expires=NULL WHERE id=?', [$group]);
                }
                return $this->snapshot($this->newDevice($group, $token, $body));
            }
            if (!$device) api_fail(401, 'unauthorized');
            $group = $device['group_id'];
            $this->execute('UPDATE sync_devices SET last_seen=? WHERE id=?', [time(), $device['id']]);
            if ($action === 'state') return $this->snapshot($device);
            if ($action === 'code') return $this->invitation($group);
            if ($action === 'devices') {
                $q = $this->pdo->prepare('SELECT id,name,created_at,last_seen FROM sync_devices WHERE group_id=? ORDER BY created_at,id');
                $q->execute([$group]); return ['devices' => $q->fetchAll(), 'device_id' => $device['id']];
            }
            if ($action === 'disconnect' || $action === 'revoke') {
                $target = $action === 'disconnect' ? $device['id'] : ($body['device_id'] ?? '');
                if (!is_string($target)) api_fail(400, 'invalid_device');
                $oldGroup = $this->row('SELECT state_ref FROM sync_groups WHERE id=?', [$group]);
                $oldDevice = $this->row('SELECT response_state_ref FROM sync_devices WHERE id=? AND group_id=?', [$target, $group]);
                $this->execute('DELETE FROM sync_devices WHERE id=? AND group_id=?', [$target, $group]);
                $this->execute('DELETE FROM sync_groups WHERE id=? AND NOT EXISTS(SELECT 1 FROM sync_devices WHERE group_id=?)', [$group, $group]);
                collect_states($this->pdo, [$oldGroup['state_ref'], $oldDevice['response_state_ref'] ?? null]);
                optimize_group_storage($this->pdo, $group);
                return ['ok' => true];
            }
            if ($action === 'delete') {
                if (($body['confirm_group_id'] ?? '') !== $group) api_fail(400, 'confirmation_required');
                $refs = $this->pdo->prepare('SELECT state_ref AS hash FROM sync_groups WHERE id=? UNION SELECT response_state_ref AS hash FROM sync_devices WHERE group_id=?');
                $refs->execute([$group, $group]);
                $hashes = $refs->fetchAll(PDO::FETCH_COLUMN);
                $this->execute('DELETE FROM sync_groups WHERE id=?', [$group]);
                collect_states($this->pdo, $hashes);
                return ['ok' => true];
            }
            if (!in_array($action, ['sync', 'confirm_deletions'], true)) api_fail(404, 'not_found');
            $sequence = $body['sequence'] ?? null;
            if (!is_int($sequence) || $sequence < 1) api_fail(400, 'invalid_sequence');
            $requestHash = hash('sha256', json_encode($body, JSON_THROW_ON_ERROR));
            if ($action === 'confirm_deletions') {
                // Authorize only this authenticated device's exact, next request.
                // A retry of an already committed request cannot authorize another one.
                if ($sequence === (int)$device['sequence'] && hash_equals($device['request_hash'] ?? '', $requestHash)) return ['confirmed' => true];
                if ($sequence !== (int)$device['sequence'] + 1) api_fail(409, 'sequence_conflict');
                $base = validate_state($body['baseline'] ?? null);
                $local = validate_state($body['state'] ?? null);
                $this->validateExplicitDeletions($body, removed_collection_items($base, $local));
                $this->execute('UPDATE sync_devices SET deletion_approval=? WHERE id=?', [$requestHash, $device['id']]);
                return ['confirmed' => true];
            }
            if ($sequence === (int)$device['sequence']) {
                if (!hash_equals($device['request_hash'] ?? '', $requestHash)) api_fail(409, 'sequence_reused');
                $cached = json_decode($device['response_json'], true, 32, JSON_THROW_ON_ERROR);
                $cached['state'] = $device['response_state_ref'] !== null
                    ? (object)load_state($this->pdo, $device['response_state_ref']) : (object)$cached['state'];
                if (isset($cached['authorized_deletions'])) $cached['authorized_deletions'] = (object)$cached['authorized_deletions'];
                return $cached;
            }
            if ($sequence !== (int)$device['sequence'] + 1) api_fail(409, 'sequence_conflict');
            $base = validate_state($body['baseline'] ?? null);
            $local = validate_state($body['state'] ?? null);
            $r = $this->row('SELECT state_json,state_ref FROM sync_groups WHERE id=?', [$group]);
            $remote = load_state($this->pdo, $r['state_ref'], $r['state_json']);
            $merged = merge_state($remote, $base, $local);
            $this->logReduction('client_proposal', $device, $sequence, $base, $local);
            $this->logReduction('server_proposal', $device, $sequence, $remote, $merged);
            $removed = removed_collection_items($remote, $merged);
            $requested = removed_collection_items($base, $local);
            $this->validateExplicitDeletions($body, $requested);
            if (($removed || $requested) && !hash_equals($device['deletion_approval'] ?? '', $requestHash)) {
                api_fail(409, 'deletion_confirmation_required');
            }
            if ($removed) {
                // Independent recovery copy: normal snapshot GC cannot discard it.
                $q = $this->pdo->prepare('INSERT OR IGNORE INTO sync_recovery(group_id,revision,created_at,payload) VALUES(?,?,?,?)');
                $revision = (int)$this->row('SELECT revision FROM sync_groups WHERE id=?', [$group])['revision'];
                $q->bindValue(1, $group); $q->bindValue(2, $revision, PDO::PARAM_INT);
                $q->bindValue(3, time(), PDO::PARAM_INT);
                $q->bindValue(4, compressed_json(state_json((object)$remote)), PDO::PARAM_LOB);
                $q->execute();
                $this->execute('DELETE FROM sync_recovery WHERE group_id=? AND revision NOT IN (SELECT revision FROM sync_recovery WHERE group_id=? ORDER BY revision DESC LIMIT 20)', [$group, $group]);
            }
            // Proofs are emitted only for removals accepted from an explicit user action.
            foreach ($removed as $collection => $ids) foreach ($ids as $id) {
                $this->execute('INSERT INTO sync_deletions(group_id,collection,item_id,revision) VALUES(?,?,?,?) ON CONFLICT(group_id,collection,item_id) DO UPDATE SET revision=excluded.revision', [$group,$collection,(string)$id,$revision + 1]);
            }
            // Re-adding an item invalidates its old deletion proof.
            foreach ($merged as $collection => $rows) foreach ($rows as $row) {
                $this->execute('DELETE FROM sync_deletions WHERE group_id=? AND collection=? AND item_id=?', [$group,$collection,$row['id']]);
            }
            $hash = store_state($this->pdo, $merged);
            if (load_state($this->pdo, $hash) != $merged) throw new RuntimeException('Snapshot roundtrip mismatch');
            $this->execute("UPDATE sync_groups SET state_json='{}',state_ref=?,revision=revision+1 WHERE id=?", [$hash, $group]);
            $device['sequence'] = $sequence;
            $result = $this->snapshot($device);
            $envelope = $result;
            unset($envelope['state']);
            $this->execute('UPDATE sync_devices SET deletion_approval=NULL,sequence=?,request_hash=?,response_json=?,response_state_ref=? WHERE id=?',
                [$sequence, $requestHash, json_encode($envelope, JSON_THROW_ON_ERROR), $hash, $device['id']]);
            collect_states($this->pdo, [$r['state_ref'], $device['response_state_ref']]);
            if ($r['state_ref'] !== $hash || $device['response_state_ref'] !== $hash) optimize_group_storage($this->pdo, $group);
            $this->logReduction('write_verified', $device, $sequence, $remote, load_state($this->pdo, $hash));
            return $result;
        });
    }
}
