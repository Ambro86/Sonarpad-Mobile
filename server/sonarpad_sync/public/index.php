<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Sync.php';
require_once __DIR__ . '/../src/Log.php';

$started = hrtime(true);
$requestId = bin2hex(random_bytes(8));
header('X-Request-ID: ' . $requestId);
$action = 'unknown';
$config = null;

try {
    $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    $script = $_SERVER['SCRIPT_NAME'] ?? '/index.php';
    $directory = rtrim(str_replace('\\', '/', dirname($script)), '/') . '/';
    if ($path !== $script && $path !== $directory) api_fail(404, 'not_found');
    $config = sync_config();
    $https = !empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off';
    if ($config['require_https'] && !$https) api_fail(400, 'https_required');
    $service = new SyncService(db(), $config);
    $action = $_GET['action'] ?? 'health';
    if (!is_string($action)) api_fail(400, 'invalid_action');
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET' && $action === 'health') {
        json_response(200, ['ok' => true, 'service' => 'Sonarpad Sync', 'schema_version' => 1,
            'collections' => SYNC_COLLECTIONS, 'preferences_max_bytes' => 32768,
            'storage_encoding' => 'gzip-9', 'storage_deduplication' => true,
            'storage_layout' => 'adaptive-v3', 'log_retention_days' => 5]);
    }
    if ($method !== 'POST') { header('Allow: POST'); api_fail(405, 'method_not_allowed'); }
    $service->rateLimit((string)($_SERVER['REMOTE_ADDR'] ?? 'unknown'), $action);
    $token = bearer_token();
    $body = read_json_body();
    $result = $service->handle($action, $token, $body);
    $meta = ['request_id' => $requestId, 'action' => $action, 'status' => 200,
        'duration_ms' => (int)((hrtime(true) - $started) / 1000000)];
    if (isset($result['revision'])) $meta['revision'] = $result['revision'];
    if (isset($result['state'])) {
        $collections = (array)$result['state'];
        $meta['collection_count'] = count($collections);
        $meta['item_count'] = array_sum(array_map('count', $collections));
    }
    sync_log($config, 'request_completed', $meta);
    json_response(200, $result);
} catch (ApiError $e) {
    if (is_array($config)) sync_log($config, 'request_failed', [
        'request_id' => $requestId, 'action' => is_string($action) ? $action : 'unknown',
        'status' => $e->httpStatus, 'error' => $e->errorName,
        'duration_ms' => (int)((hrtime(true) - $started) / 1000000)]);
    if ($e->httpStatus === 429) header('Retry-After: 3600');
    json_response($e->httpStatus, ['error' => $e->errorName]);
} catch (Throwable) {
    if (is_array($config)) sync_log($config, 'request_failed', [
        'request_id' => $requestId, 'action' => is_string($action) ? $action : 'unknown',
        'status' => 503, 'error' => 'service_unavailable',
        'duration_ms' => (int)((hrtime(true) - $started) / 1000000)]);
    // Never log request bodies, pairing codes, tokens or database contents.
    json_response(503, ['error' => 'service_unavailable']);
}
