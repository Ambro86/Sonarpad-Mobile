<?php
declare(strict_types=1);

function init_schema(PDO $pdo): void {
    $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS sync_groups (
    id TEXT PRIMARY KEY,
    state_json TEXT NOT NULL DEFAULT '{}',
    revision INTEGER NOT NULL DEFAULT 0,
    code_hash TEXT UNIQUE,
    code_expires INTEGER,
    created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS sync_devices (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES sync_groups(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    sequence INTEGER NOT NULL DEFAULT 0,
    request_hash TEXT,
    response_json TEXT
);
CREATE INDEX IF NOT EXISTS sync_devices_group ON sync_devices(group_id);
CREATE TABLE IF NOT EXISTS sync_rate_limits (
    bucket TEXT PRIMARY KEY,
    count INTEGER NOT NULL,
    expires INTEGER NOT NULL
);
SQL);
    write_transaction($pdo, function () use ($pdo) {
        foreach (['sync_groups' => 'state_ref', 'sync_devices' => 'response_state_ref'] as $table => $column) {
            $columns = array_column($pdo->query("PRAGMA table_info($table)")->fetchAll(), 'name');
            if (!in_array($column, $columns, true)) $pdo->exec("ALTER TABLE $table ADD COLUMN $column TEXT");
        }
        $pdo->exec('CREATE TABLE IF NOT EXISTS sync_deletions(group_id TEXT NOT NULL REFERENCES sync_groups(id) ON DELETE CASCADE, collection TEXT NOT NULL, item_id TEXT NOT NULL, revision INTEGER NOT NULL, PRIMARY KEY(group_id,collection,item_id)) WITHOUT ROWID');
        $deviceColumns = array_column($pdo->query('PRAGMA table_info(sync_devices)')->fetchAll(), 'name');
        if (!in_array('deletion_approval', $deviceColumns, true)) $pdo->exec('ALTER TABLE sync_devices ADD COLUMN deletion_approval TEXT');
        $pdo->exec('CREATE TABLE IF NOT EXISTS sync_recovery(group_id TEXT NOT NULL REFERENCES sync_groups(id) ON DELETE CASCADE, revision INTEGER NOT NULL, created_at INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(group_id,revision)) WITHOUT ROWID');
        $columns = array_column($pdo->query('PRAGMA table_info(sync_groups)')->fetchAll(), 'name');
        if (!in_array('storage_policy', $columns, true)) $pdo->exec('ALTER TABLE sync_groups ADD COLUMN storage_policy INTEGER NOT NULL DEFAULT 0');
        $pdo->exec('CREATE INDEX IF NOT EXISTS sync_groups_policy ON sync_groups(id) WHERE storage_policy=0');
        $pdo->exec('CREATE TABLE IF NOT EXISTS sync_blobs(hash TEXT PRIMARY KEY, payload BLOB NOT NULL)');
        $columns = array_column($pdo->query('PRAGMA table_info(sync_blobs)')->fetchAll(), 'name');
        if (!in_array('format', $columns, true)) $pdo->exec('ALTER TABLE sync_blobs ADD COLUMN format INTEGER NOT NULL DEFAULT 0');
        $pdo->exec('CREATE TABLE IF NOT EXISTS sync_parts(hash TEXT PRIMARY KEY, payload BLOB NOT NULL)');
        $pdo->exec('CREATE TABLE IF NOT EXISTS sync_blob_parts(snapshot_hash TEXT NOT NULL REFERENCES sync_blobs(hash) ON DELETE CASCADE,
            part_hash TEXT NOT NULL REFERENCES sync_parts(hash), PRIMARY KEY(snapshot_hash,part_hash)) WITHOUT ROWID');
        $pdo->exec('CREATE INDEX IF NOT EXISTS sync_blob_parts_part ON sync_blob_parts(part_hash)');
        $pdo->exec('CREATE INDEX IF NOT EXISTS sync_blobs_legacy ON sync_blobs(hash) WHERE format=0');
        $pdo->exec('CREATE INDEX IF NOT EXISTS sync_groups_state_ref ON sync_groups(state_ref)');
        $pdo->exec('CREATE INDEX IF NOT EXISTS sync_devices_state_ref ON sync_devices(response_state_ref)');
        $pdo->exec('CREATE INDEX IF NOT EXISTS sync_devices_legacy_cache ON sync_devices(id) WHERE response_state_ref IS NULL AND response_json IS NOT NULL');
    });
}
