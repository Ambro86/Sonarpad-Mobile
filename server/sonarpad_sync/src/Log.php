<?php
declare(strict_types=1);

/** Bounded diagnostic log. Only allowlisted metadata, never raw exceptions/body. */
function sync_log(array $config, string $event, array $metadata = []): void {
    $lock = null;
    try {
        $path = $config['log_path'];
        $dir = dirname($path);
        if (!is_dir($dir) && !@mkdir($dir, 0700, true)) return;
        $lock = @fopen($path . '.lock', 'c');
        if (!$lock || !flock($lock, LOCK_EX)) return;
        $maxBytes = max(1024, min(10485760, (int)$config['log_max_bytes']));
        $archives = max(0, min(10, (int)$config['log_archives']));
        $cutoff = time() - max(1, min(5, (int)$config['log_max_age_days'])) * 86400;
        // Archive timestamps represent their oldest entry, not the rotation
        // time. Even a low-traffic active file cannot retain entries forever.
        for ($i = 0; $i <= 10; $i++) {
            foreach ($i === 0 ? [$path] : [$path . '.' . $i, $path . '.' . $i . '.gz'] as $file) {
                clearstatcache(true, $file);
                if (!is_file($file)) continue;
                $oldest = (int)filemtime($file);
                if (!str_ends_with($file, '.gz')) {
                    $handle = @fopen($file, 'r');
                    if ($handle) {
                        $first = json_decode((string)fgets($handle, 4096), true);
                        fclose($handle);
                        $oldest = strtotime($first['time'] ?? '') ?: $oldest;
                    }
                }
                if ($i > $archives || $oldest < $cutoff) { @unlink($file); continue; }
                if ($i > 0 && !str_ends_with($file, '.gz')) {
                    if (compress_log($file, $file . '.gz', $oldest, $maxBytes)) @unlink($file);
                }
            }
        }
        $row = ['time' => gmdate('c'), 'event' => preg_match('/^[a-z_]{1,40}$/D', $event) ? $event : 'unknown'];
        foreach (['request_id', 'action', 'status', 'duration_ms', 'error', 'revision', 'collection_count', 'item_count', 'stage', 'group_id', 'device_id', 'sequence', 'collection', 'before_count', 'after_count', 'removed_count', 'item_sha256', 'preference_id'] as $key) {
            if (!isset($metadata[$key])) continue;
            $value = $metadata[$key];
            if ($key === 'preference_id' && is_string($value) && preg_match('/^[a-z][a-z0-9_.]{1,79}$/D', $value)) $row[$key] = $value;
            elseif (is_int($value)) $row[$key] = $value;
            elseif (is_string($value) && preg_match('/^[a-zA-Z0-9_-]{1,64}$/D', $value)) $row[$key] = $value;
        }
        $line = json_encode($row, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES) . "\n";
        clearstatcache(true, $path);
        if (is_file($path) && filesize($path) + strlen($line) > $maxBytes) {
            if ($archives === 0) @unlink($path);
            else {
                if (is_file($path . '.' . $archives . '.gz')) @unlink($path . '.' . $archives . '.gz');
                for ($i = $archives - 1; $i >= 1; $i--) {
                    if (is_file($path . '.' . $i . '.gz')) @rename($path . '.' . $i . '.gz', $path . '.' . ($i + 1) . '.gz');
                }
                $handle = @fopen($path, 'r');
                $first = $handle ? json_decode((string)fgets($handle, 4096), true) : null;
                if ($handle) fclose($handle);
                $oldest = strtotime($first['time'] ?? '') ?: (int)filemtime($path);
                if (compress_log($path, $path . '.1.gz', $oldest, $maxBytes)) @unlink($path);
            }
        }
        // If rotation failed, don't let diagnostics grow without a bound.
        clearstatcache(true, $path);
        if (is_file($path) && filesize($path) + strlen($line) > $maxBytes) return;
        @file_put_contents($path, $line, FILE_APPEND);
    } catch (Throwable) {
        // Logging failures must not prevent synchronization.
    } finally {
        if (is_resource($lock)) { flock($lock, LOCK_UN); fclose($lock); }
    }
}

/** Gzip level 9, bounded input and atomic replacement under the log lock. */
function compress_log(string $source, string $target, int $oldest, int $maxBytes): bool {
    $raw = @file_get_contents($source, false, null, 0, $maxBytes + 1);
    if ($raw === false) return false;
    if (strlen($raw) > $maxBytes) { @unlink($source); return true; }
    $gzip = gzencode($raw, 9);
    if ($gzip === false) return false;
    $temp = $target . '.tmp';
    if (@file_put_contents($temp, $gzip) !== strlen($gzip)) { @unlink($temp); return false; }
    @touch($temp, $oldest);
    if (!@rename($temp, $target)) { @unlink($temp); return false; }
    return true;
}
