<?php
declare(strict_types=1);
// Optional maintenance, never exposed as a public web action.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/src/Sync.php';
$pdo = db();
init_schema($pdo);
while (migrate_states($pdo, 20) > 0) {}
// SQLite otherwise reuses freed pages but does not shrink the existing file.
// Run at low traffic: VACUUM needs a write lock and temporary disk space.
$pdo->exec('VACUUM');
$pdo->exec('PRAGMA wal_checkpoint(TRUNCATE)');
echo "Migration and database compaction completed. No users deleted.\n";
