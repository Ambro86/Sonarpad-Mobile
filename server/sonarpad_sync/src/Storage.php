<?php
declare(strict_types=1);

// Content-addressed snapshots. Object key order is immaterial; array order
// (favorites/folders) and scalar types must survive unchanged.
function canonical_state(mixed $value): mixed {
    if (is_object($value)) {
        $fields = get_object_vars($value);
        ksort($fields, SORT_STRING);
        foreach ($fields as &$field) $field = canonical_state($field);
        return (object)$fields;
    }
    if (is_array($value)) return array_map('canonical_state', $value);
    return $value;
}

function state_json(mixed $value): string {
    return json_encode(canonical_state($value), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
}

function compressed_json(string $json): string {
    $gzip = gzencode($json, 9);
    if ($gzip === false) throw new RuntimeException('Compression failed');
    return $gzip;
}

// Must run in the same transaction as the snapshot references. Each collection
// is compressed independently; the small manifest preserves collection names.
function split_state(PDO $pdo, string $hash, object $state): void {
    $manifest = new stdClass();
    $parts = [];
    foreach ($state as $name => $rows) {
        $json = state_json($rows);
        $part = hash('sha256', $json);
        $query = $pdo->prepare('SELECT 1 FROM sync_parts WHERE hash=?');
        $query->execute([$part]);
        if (!$query->fetchColumn()) {
            $query = $pdo->prepare('INSERT INTO sync_parts(hash,payload) VALUES(?,?)');
            $query->bindValue(1, $part);
            $query->bindValue(2, compressed_json($json), PDO::PARAM_LOB);
            $query->execute();
        }
        $manifest->$name = $part;
        $parts[$part] = true;
    }
    $query = $pdo->prepare('INSERT INTO sync_blobs(hash,payload,format) VALUES(?,?,1)
        ON CONFLICT(hash) DO UPDATE SET payload=excluded.payload,format=1');
    $query->bindValue(1, $hash);
    $query->bindValue(2, compressed_json(state_json($manifest)), PDO::PARAM_LOB);
    $query->execute();
    $query = $pdo->prepare('INSERT OR IGNORE INTO sync_blob_parts(snapshot_hash,part_hash) VALUES(?,?)');
    foreach ($parts as $part => $_) $query->execute([$hash, $part]);
}

function store_state(PDO $pdo, array|object $state): string {
    $state = canonical_state(json_decode(json_encode((object)$state,
        JSON_THROW_ON_ERROR), false, 32, JSON_THROW_ON_ERROR));
    $hash = hash('sha256', state_json($state));
    $exists = $pdo->prepare('SELECT 1 FROM sync_blobs WHERE hash=?');
    $exists->execute([$hash]);
    if (!$exists->fetchColumn()) {
        $q = $pdo->prepare('INSERT INTO sync_blobs(hash,payload,format) VALUES(?,?,0)');
        $q->bindValue(1, $hash);
        $q->bindValue(2, compressed_json(state_json($state)), PDO::PARAM_LOB);
        $q->execute();
    }
    return $hash;
}

function decode_snapshot(string $payload): string {
    $json = gzdecode($payload, 4194305);
    if ($json === false || strlen($json) > 4194304) throw new RuntimeException('Invalid snapshot');
    return $json;
}

function load_state_json(PDO $pdo, ?string $hash, string $legacy = '{}'): string {
    if ($hash !== null) {
        $q = $pdo->prepare('SELECT payload,format FROM sync_blobs WHERE hash=?');
        $q->execute([$hash]);
        $blob = $q->fetch();
        if (!$blob) throw new RuntimeException('Missing snapshot');
        $legacy = decode_snapshot($blob['payload']);
        if ((int)$blob['format'] === 1) {
            $manifest = json_decode($legacy, false, 32, JSON_THROW_ON_ERROR);
            if (!is_object($manifest)) throw new RuntimeException('Invalid snapshot');
            $state = new stdClass();
            $bytes = 0;
            $q = $pdo->prepare('SELECT payload FROM sync_parts WHERE hash=?');
            foreach ($manifest as $name => $part) {
                if (!is_string($part) || !preg_match('/^[a-f0-9]{64}$/D', $part)) throw new RuntimeException('Invalid snapshot');
                $q->execute([$part]);
                $payload = $q->fetchColumn();
                if (!is_string($payload)) throw new RuntimeException('Missing collection');
                $json = decode_snapshot($payload);
                $bytes += strlen($json);
                if ($bytes > 4194304 || !hash_equals($part, hash('sha256', $json))) throw new RuntimeException('Invalid snapshot');
                $state->$name = json_decode($json, false, 32, JSON_THROW_ON_ERROR);
            }
            $legacy = state_json($state);
        } elseif ((int)$blob['format'] !== 0) {
            throw new RuntimeException('Invalid snapshot');
        }
        if (!hash_equals($hash, hash('sha256', $legacy))) throw new RuntimeException('Invalid snapshot');
    }
    return $legacy;
}

function load_state(PDO $pdo, ?string $hash, string $legacy = '{}'): array {
    return json_decode(load_state_json($pdo, $hash, $legacy), true, 32, JSON_THROW_ON_ERROR);
}

// Keep exact retry snapshots until the last reference disappears. Deleting a
// snapshot must not delete collections still used by any other snapshot/user.
function collect_states(PDO $pdo, array $hashes): void {
    $read = $pdo->prepare('SELECT part_hash FROM sync_blob_parts WHERE snapshot_hash=?');
    $delete = $pdo->prepare('DELETE FROM sync_blobs WHERE hash=?
        AND NOT EXISTS(SELECT 1 FROM sync_groups WHERE state_ref=sync_blobs.hash)
        AND NOT EXISTS(SELECT 1 FROM sync_devices WHERE response_state_ref=sync_blobs.hash)');
    $edges = $pdo->prepare('DELETE FROM sync_blob_parts WHERE snapshot_hash=?');
    $parts = $pdo->prepare('DELETE FROM sync_parts WHERE hash=?
        AND NOT EXISTS(SELECT 1 FROM sync_blob_parts WHERE part_hash=sync_parts.hash)');
    foreach (array_unique(array_filter($hashes)) as $hash) {
        $read->execute([$hash]);
        $candidates = $read->fetchAll(PDO::FETCH_COLUMN);
        $delete->execute([$hash]);
        if ($delete->rowCount() > 0) {
            $edges->execute([$hash]);
            foreach ($candidates as $part) $parts->execute([$part]);
        }
    }
}

// Called inside the reference-update transaction, never a separate network
// operation. Costs include compressed payloads and estimated row/index costs.
// Keep the current layout unless the saving exceeds a small hysteresis margin.
function optimize_group_storage(PDO $pdo, string $group): void {
    $q = $pdo->prepare('SELECT state_ref AS hash FROM sync_groups WHERE id=? UNION
        SELECT response_state_ref AS hash FROM sync_devices WHERE group_id=? AND response_state_ref IS NOT NULL');
    $q->execute([$group, $group]);
    $hashes = array_values(array_filter($q->fetchAll(PDO::FETCH_COLUMN)));
    $pdo->prepare('UPDATE sync_groups SET storage_policy=1 WHERE id=?')->execute([$group]);
    if (!$hashes) return;
    $placeholders = implode(',', array_fill(0, count($hashes), '?'));
    $q = $pdo->prepare("SELECT DISTINCT part_hash FROM sync_blob_parts WHERE snapshot_hash IN ($placeholders)");
    $q->execute($hashes); $oldParts = $q->fetchAll(PDO::FETCH_COLUMN);
    $external = $pdo->prepare("SELECT 1 FROM sync_blob_parts WHERE part_hash=? AND snapshot_hash NOT IN ($placeholders) LIMIT 1");
    $states = []; $parts = []; $wholeCost = 0; $splitCost = 0; $currentCost = 0; $bytes = 0;
    foreach ($hashes as $hash) {
        $json = load_state_json($pdo, $hash);
        $bytes += strlen($json);
        // Bound work/memory on the PHP request path. Existing storage remains
        // fully valid; large groups can be evaluated again as devices align.
        if ($bytes > 8 * 1024 * 1024) return;
        $state = json_decode($json, false, 32, JSON_THROW_ON_ERROR);
        $gzip = compressed_json($json);
        $states[$hash] = [$state, $gzip];
        $wholeCost += strlen($gzip);
        $manifest = new stdClass(); $unique = [];
        foreach ($state as $name => $rows) {
            $partJson = state_json($rows); $part = hash('sha256', $partJson);
            $manifest->$name = $part; $unique[$part] = true;
            if (!isset($parts[$part])) {
                $external->execute([$part, ...$hashes]);
                $parts[$part] = $external->fetchColumn() ? 0 : strlen(compressed_json($partJson)) + 160;
            }
        }
        $splitCost += strlen(compressed_json(state_json($manifest))) + count($unique) * 256;
        $q = $pdo->prepare('SELECT length(payload) FROM sync_blobs WHERE hash=?');
        $q->execute([$hash]); $currentCost += (int)$q->fetchColumn();
        $q = $pdo->prepare('SELECT COUNT(*) FROM sync_blob_parts WHERE snapshot_hash=?');
        $q->execute([$hash]); $currentCost += (int)$q->fetchColumn() * 256;
    }
    $splitCost += array_sum($parts);
    foreach ($oldParts as $part) {
        $external->execute([$part, ...$hashes]);
        if (!$external->fetchColumn()) {
            $q = $pdo->prepare('SELECT length(payload) FROM sync_parts WHERE hash=?');
            $q->execute([$part]); $currentCost += (int)$q->fetchColumn() + 160;
        }
    }
    if (min($wholeCost, $splitCost) + 256 >= $currentCost) return;
    if ($splitCost < $wholeCost) {
        foreach ($states as $hash => [$state, $_]) split_state($pdo, $hash, $state);
    } else {
        $q = $pdo->prepare('UPDATE sync_blobs SET payload=?,format=0 WHERE hash=?');
        foreach ($states as $hash => [$_, $gzip]) {
            $q->bindValue(1, $gzip, PDO::PARAM_LOB); $q->bindValue(2, $hash); $q->execute();
        }
        $pdo->prepare("DELETE FROM sync_blob_parts WHERE snapshot_hash IN ($placeholders)")->execute($hashes);
        $q = $pdo->prepare('DELETE FROM sync_parts WHERE hash=? AND NOT EXISTS(SELECT 1 FROM sync_blob_parts WHERE part_hash=sync_parts.hash)');
        foreach ($oldParts as $part) $q->execute([$part]);
    }
}

// Bounded, transactional migration; requests can still read unmigrated rows.
// Never change request_hash/sequence/revision when migrating a retry cache.
function migrate_states(PDO $pdo, int $limit = 2): int {
    return write_transaction($pdo, function () use ($pdo, $limit) {
        $count = 0;
        $limit = max(1, min(100, $limit));
        $groups = $pdo->query("SELECT id FROM sync_groups WHERE state_ref IS NULL LIMIT $limit")->fetchAll();
        $update = $pdo->prepare("UPDATE sync_groups SET state_ref=?,state_json='{}' WHERE id=?");
        foreach ($groups as $group) {
            $read = $pdo->prepare('SELECT state_json FROM sync_groups WHERE id=?');
            $read->execute([$group['id']]);
            $group['state_json'] = $read->fetchColumn();
            $hash = store_state($pdo, json_decode($group['state_json'], false, 32, JSON_THROW_ON_ERROR));
            $update->execute([$hash, $group['id']]);
            $count++;
        }
        $devices = $pdo->query("SELECT id FROM sync_devices WHERE response_state_ref IS NULL AND response_json IS NOT NULL LIMIT $limit")->fetchAll();
        $update = $pdo->prepare('UPDATE sync_devices SET response_state_ref=?,response_json=? WHERE id=?');
        foreach ($devices as $device) {
            $read = $pdo->prepare('SELECT response_json FROM sync_devices WHERE id=?');
            $read->execute([$device['id']]);
            $device['response_json'] = $read->fetchColumn();
            $response = json_decode($device['response_json'], false, 32, JSON_THROW_ON_ERROR);
            $hash = store_state($pdo, $response->state);
            unset($response->state);
            $update->execute([$hash, json_encode($response, JSON_THROW_ON_ERROR), $device['id']]);
            $pdo->prepare('UPDATE sync_groups SET storage_policy=0 WHERE id=(SELECT group_id FROM sync_devices WHERE id=?)')->execute([$device['id']]);
            $count++;
        }
        // Evaluate existing groups once, after their legacy response caches
        // have been migrated. Whole-state gzip remains a supported format.
        $pending = $pdo->query("SELECT id FROM sync_groups WHERE storage_policy=0 AND state_ref IS NOT NULL
            AND NOT EXISTS(SELECT 1 FROM sync_devices WHERE group_id=sync_groups.id AND response_json IS NOT NULL AND response_state_ref IS NULL)
            LIMIT $limit")->fetchAll(PDO::FETCH_COLUMN);
        foreach ($pending as $group) { optimize_group_storage($pdo, $group); $count++; }
        return $count;
    });
}
