<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Log.php';
$dir = sys_get_temp_dir() . '/sonarpad-sync-log-test-' . bin2hex(random_bytes(8));
mkdir($dir, 0700);
$config = ['log_path' => $dir . '/sync.log', 'log_max_bytes' => 1024, 'log_archives' => 3, 'log_max_age_days' => 7];
function verify(bool $ok, string $message): void { if (!$ok) throw new RuntimeException($message); }
try {
    for ($i = 0; $i < 150; $i++) sync_log($config, 'request_completed', [
        'action' => 'sync', 'status' => 200, 'duration_ms' => $i,
        'token' => 'SECRET_TOKEN', 'code' => 'SECRET_CODE', 'state' => 'PRIVATE_FAVORITES']);
    $files = glob($dir . '/sync.log*');
    verify(count($files) === 5, 'current, three archives and lock');
    foreach ($files as $file) {
        verify(filesize($file) <= 1024, 'file size bounded');
        $text = file_get_contents($file);
        if (str_ends_with($file, '.gz')) {
            verify(ord($text[8]) === 2, 'gzip maximum compression');
            $text = gzdecode($text);
        }
        verify(!str_contains($text, 'SECRET') && !str_contains($text, 'PRIVATE'), 'redaction');
        foreach (explode("\n", trim($text)) as $line) {
            if ($line !== '') json_decode($line, true, 32, JSON_THROW_ON_ERROR);
        }
    }
    touch($dir . '/sync.log.1.gz', time() - 6 * 86400);
    sync_log($config, 'request_failed', ['error' => 'unauthorized', 'status' => 401]);
    verify(!file_exists($dir . '/sync.log.1.gz'), 'expired archive removed');
    file_put_contents($dir . '/sync.log.1', json_encode(['time'=>gmdate('c'),'event'=>'legacy']) . "\n");
    sync_log($config, 'request_completed', []);
    verify(!file_exists($dir . '/sync.log.1') && str_contains(gzdecode(file_get_contents($dir . '/sync.log.1.gz')), 'legacy'), 'legacy archive compressed');
    file_put_contents($dir . '/sync.log', json_encode(['time'=>gmdate('c',time()-6*86400),'event'=>'old']) . "\n");
    sync_log($config, 'request_completed', []);
    verify(!str_contains(file_get_contents($dir . '/sync.log'), '"old"'), 'active log expires even with recent mtime');
    $config['log_archives'] = 0;
    sync_log($config, 'request_completed', []);
    verify(count(glob($dir . '/sync.log*')) === 2, 'archive count reduction');
    echo "OK: log rotation, size bound, expiry, JSON integrity and redaction.\n";
} finally {
    foreach (glob($dir . '/*') as $file) unlink($file);
    rmdir($dir);
}
