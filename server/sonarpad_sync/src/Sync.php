<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/schema.php';
require_once __DIR__ . '/Merge.php';
require_once __DIR__ . '/Storage.php';

final class SyncService {
    public function __construct(private PDO $pdo, private array $config) { init_schema($pdo); migrate_states($pdo); }

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
        return ['schema_version' => 1, 'group_id' => $group['id'], 'device_id' => $device['id'],
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
            if ($action !== 'sync') api_fail(404, 'not_found');
            $sequence = $body['sequence'] ?? null;
            if (!is_int($sequence) || $sequence < 1) api_fail(400, 'invalid_sequence');
            $requestHash = hash('sha256', json_encode($body, JSON_THROW_ON_ERROR));
            if ($sequence === (int)$device['sequence']) {
                if (!hash_equals($device['request_hash'] ?? '', $requestHash)) api_fail(409, 'sequence_reused');
                $cached = json_decode($device['response_json'], true, 32, JSON_THROW_ON_ERROR);
                $cached['state'] = $device['response_state_ref'] !== null
                    ? (object)load_state($this->pdo, $device['response_state_ref']) : (object)$cached['state'];
                return $cached;
            }
            if ($sequence !== (int)$device['sequence'] + 1) api_fail(409, 'sequence_conflict');
            $base = validate_state($body['baseline'] ?? null);
            $local = validate_state($body['state'] ?? null);
            $r = $this->row('SELECT state_json,state_ref FROM sync_groups WHERE id=?', [$group]);
            $remote = load_state($this->pdo, $r['state_ref'], $r['state_json']);
            $merged = merge_state($remote, $base, $local);
            $hash = store_state($this->pdo, $merged);
            $this->execute("UPDATE sync_groups SET state_json='{}',state_ref=?,revision=revision+1 WHERE id=?", [$hash, $group]);
            $device['sequence'] = $sequence;
            $result = $this->snapshot($device);
            $envelope = $result;
            unset($envelope['state']);
            $this->execute('UPDATE sync_devices SET sequence=?,request_hash=?,response_json=?,response_state_ref=? WHERE id=?',
                [$sequence, $requestHash, json_encode($envelope, JSON_THROW_ON_ERROR), $hash, $device['id']]);
            collect_states($this->pdo, [$r['state_ref'], $device['response_state_ref']]);
            if ($r['state_ref'] !== $hash || $device['response_state_ref'] !== $hash) optimize_group_storage($this->pdo, $group);
            return $result;
        });
    }
}
