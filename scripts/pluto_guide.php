<?php
declare(strict_types=1);

// Install next to tv_channels_resolver.php. No playback URLs or credentials
// are returned. Read the existing resolver's configuration without executing it.
function pluto_resolver_config(string $path): array
{
    $source = @file_get_contents($path);
    if ($source === false ||
        !preg_match('/const\s+CLIENT_TOKEN\s*=\s*([\'"])([^\'"\r\n]+)\1\s*;/', $source, $token) ||
        !preg_match_all('/\$json\s*\.?=\s*<<<\'JSON\'[^\S\r\n]*\R(.*?)\RJSON;/s', $source, $list)) {
        throw new RuntimeException('Resolver configuration unavailable', 503);
    }
    // The resolver appends multiple nowdoc blocks around K2/Frisbee comments.
    $channels = json_decode(implode("\n", $list[1]), true, 512, JSON_THROW_ON_ERROR);
    $ids = [];
    foreach ($channels as $channel) {
        $url = parse_url((string)($channel['url'] ?? ''));
        if (!is_array($url) || strtolower($url['path'] ?? '') !== '/api/pluto.php') continue;
        parse_str($url['query'] ?? '', $query);
        $id = strtolower((string)($query['id'] ?? ''));
        if (preg_match('/^[a-f0-9]{20,}$/D', $id)) $ids[$id] = true;
    }
    if (!$ids) throw new RuntimeException('Pluto channel list unavailable', 503);
    return [$token[2], $ids];
}

function pluto_fetch(string $url): array
{
    $headers = ['Accept: application/json', 'Origin: https://pluto.tv', 'User-Agent: Mozilla/5.0'];
    if (function_exists('curl_init')) {
        $handle = curl_init($url);
        curl_setopt_array($handle, [CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers, CURLOPT_CONNECTTIMEOUT => 3,
            CURLOPT_TIMEOUT => 8, CURLOPT_ENCODING => '']);
        $body = curl_exec($handle);
        $status = curl_getinfo($handle, CURLINFO_HTTP_CODE);
        curl_close($handle);
        if ($body === false || $status !== 200) throw new RuntimeException('Pluto unavailable', 502);
    } else {
        $context = stream_context_create(['http' => ['timeout' => 8,
            'header' => implode("\r\n", $headers), 'ignore_errors' => true]]);
        $body = @file_get_contents($url, false, $context);
        if ($body === false || !preg_match('/\s200\s/', $http_response_header[0] ?? '')) {
            throw new RuntimeException('Pluto unavailable', 502);
        }
    }
    $root = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
    if (!isset($root['channels']) || !is_array($root['channels']) || !$root['channels']) {
        throw new RuntimeException('Invalid Pluto response', 502);
    }
    return $root['channels'];
}

function pluto_first_text(array $values): string
{
    foreach ($values as $value) {
        if (is_string($value) && trim($value) !== '') return trim($value);
    }
    return '';
}

function pluto_normalize(array $channels, array $ids): array
{
    $zone = new DateTimeZone('Europe/Rome');
    $result = [];
    foreach ($channels as $channel) {
        $id = strtolower((string)($channel['id'] ?? ''));
        if (!isset($ids[$id])) continue;
        $programs = [];
        foreach ($channel['timelines'] ?? [] as $timeline) {
            $start = strtotime((string)($timeline['start'] ?? ''));
            $stop = strtotime((string)($timeline['stop'] ?? ''));
            if (!$start || !$stop || $stop <= $start) continue;
            $episode = $timeline['episode'] ?? [];
            $series = $episode['series'] ?? [];
            $title = pluto_first_text([$timeline['title'] ?? '', $episode['name'] ?? '',
                $series['name'] ?? '', $channel['name'] ?? '']);
            if ($title === '') continue;
            $programs[$start . ':' . $stop] = ['title' => $title,
                'hour' => (new DateTimeImmutable('@' . $start))->setTimezone($zone)->format('H:i'),
                'startTime' => $start, 'endTime' => $stop,
                'description' => pluto_first_text([$episode['description'] ?? '', $series['description'] ?? ''])];
        }
        $programs = array_values($programs);
        usort($programs, static fn(array $a, array $b): int => $a['startTime'] <=> $b['startTime']);
        $result[$id] = $programs;
    }
    if (!$result) throw new RuntimeException('No matching Pluto channels', 502);
    return $result;
}

function pluto_current(array $programs, int $now): ?array
{
    $active = null;
    $latest = null;
    foreach ($programs as $program) {
        if ($program['startTime'] > $now) continue;
        if ($latest === null || $program['startTime'] > $latest['startTime']) $latest = $program;
        if ($program['endTime'] <= $now) continue;
        $filler = strcasecmp(trim($program['title']), 'no info available') === 0;
        $activeFiller = $active !== null && strcasecmp(trim($active['title']), 'no info available') === 0;
        if ($active === null || ($activeFiller && !$filler) ||
            ($activeFiller === $filler && $program['startTime'] > $active['startTime'])) $active = $program;
    }
    return $active ?? ($latest !== null && $now - $latest['startTime'] <= 21600 ? $latest : null);
}

function pluto_cached(array $ids, int $now, string $directory): array
{
    if (!is_dir($directory) && !@mkdir($directory, 0700, true) && !is_dir($directory)) {
        throw new RuntimeException('Cache unavailable', 503);
    }
    $file = $directory . '/guide.json';
    $read = static function () use ($file): ?array {
        $data = json_decode((string)@file_get_contents($file), true);
        return is_array($data) && isset($data['updated'], $data['programs']) && is_array($data['programs']) ? $data : null;
    };
    $cache = $read();
    if ($cache !== null && $now - $cache['updated'] < 180) return $cache;
    $lock = @fopen($directory . '/guide.lock', 'c');
    if ($lock === false) throw new RuntimeException('Cache unavailable', 503);
    // Avoid blocking every phone while another request refreshes the cache.
    $locked = flock($lock, LOCK_EX | LOCK_NB);
    if (!$locked) {
        fclose($lock);
        if ($cache !== null) return $cache;
        throw new RuntimeException('Guide refresh in progress', 503);
    }
    try {
        $cache = $read();
        if ($cache !== null && $now - $cache['updated'] < 180) return $cache;
        $url = 'https://service-channels.clusters.pluto.tv/v1/guide?' . http_build_query([
            'start' => gmdate('Y-m-d\TH:i:s.000\Z', $now - 21600),
            'stop' => gmdate('Y-m-d\TH:i:s.000\Z', $now + 43200)]);
        $programs = pluto_normalize(pluto_fetch($url), $ids);
        $fresh = ['updated' => $now, 'programs' => $programs];
        $temporary = $file . '.tmp';
        if (@file_put_contents($temporary, json_encode($fresh, JSON_THROW_ON_ERROR)) !== false) {
            @chmod($temporary, 0600);
            @rename($temporary, $file);
        }
        return $fresh;
    } catch (Throwable $error) {
        if ($cache !== null) return $cache;
        throw new RuntimeException('Pluto unavailable', 502);
    } finally {
        flock($lock, LOCK_UN);
        fclose($lock);
    }
}

function pluto_guide_main(): void
{
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    try {
        [$token, $ids] = pluto_resolver_config(__DIR__ . '/tv_channels_resolver.php');
        $authorized = false;
        foreach (['HTTP_X_SONARPAD_TV_TOKEN', 'HTTP_X_SONARPAD_ROUTE_TOKEN'] as $header) {
            if (isset($_SERVER[$header]) && hash_equals($token, (string)$_SERVER[$header])) $authorized = true;
        }
        if (!$authorized) throw new RuntimeException('Forbidden', 403);
        $id = strtolower(trim((string)($_GET['id'] ?? '')));
        $now = time();
        $zone = new DateTimeZone('Europe/Rome');
        $today = (new DateTimeImmutable('@' . $now))->setTimezone($zone);
        $date = (string)($_GET['date'] ?? $today->format('Y-m-d'));
        $day = DateTimeImmutable::createFromFormat('!Y-m-d', $date, $zone);
        if ($id !== '' && !isset($ids[$id])) throw new RuntimeException('not_found', 404);
        if ($day === false || $day->format('Y-m-d') !== $date) throw new RuntimeException('invalid_date', 400);
        if ($id === '' && (string)($_GET['mode'] ?? 'now') !== 'now') throw new RuntimeException('invalid_mode', 400);
        $start = $day->getTimestamp();
        $stop = $day->modify('+1 day')->getTimestamp();
        if ($id !== '' && ($start > $now + 43200 || $stop <= $now - 21600)) {
            $payload = ['version' => 1, 'source' => 'pluto', 'id' => $id, 'date' => $date, 'programs' => []];
        } else {
            $directory = sys_get_temp_dir() . '/sonarpad-pluto-' . substr(hash('sha256', __DIR__), 0, 16);
            $cache = pluto_cached($ids, $now, $directory);
            $payload = ['version' => 1, 'source' => 'pluto', 'updated_at' => gmdate('c', $cache['updated'])];
            if ($id !== '') {
                $payload += ['id' => $id, 'date' => $date, 'programs' => array_values(array_filter(
                    $cache['programs'][$id] ?? [],
                    static fn(array $p): bool => $p['startTime'] < $stop && $p['endTime'] > $start))];
            } else {
                $programs = [];
                foreach ($ids as $channelId => $_) {
                    $current = pluto_current($cache['programs'][$channelId] ?? [], $now);
                    if ($current !== null) $programs[$channelId] = $current;
                }
                $payload['programs'] = (object)$programs;
            }
        }
        echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    } catch (Throwable $error) {
        $status = (int)$error->getCode();
        if ($status < 400 || $status > 599) $status = 502;
        http_response_code($status);
        echo json_encode(['error' => $status < 500 ? $error->getMessage() : 'guide_unavailable']);
    }
}

if (!defined('SONARPAD_PLUTO_GUIDE_LIBRARY_ONLY')) pluto_guide_main();
